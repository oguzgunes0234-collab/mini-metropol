class_name GameScreen
extends Node2D
## Oyun ekranı: dokunma/fare girdisi, yerleşim, arayüz ve efektleri
## GameSession'a bağlar. Bölüm kipinde giriş paneli, hedefler, güçlendirici
## çubuğu ve sonuç; serbest kipte yalnızca puan. Oyun kuralları burada değil,
## GameSession, Board ve BoosterManager içindedir.

signal exit_to_levels
signal play_level(id: String)
## Oyuncu profili değişti (bölüm sonucu, ödül): kaydedilmeli.
signal profile_changed

## Tasarım yüksekliği: içerik bu yüksekliğe göre yerleştirilir, daha uzun
## ekranlarda dikey olarak ortalanır.
const CONTENT_HEIGHT := 1920.0
## Alanın altında bırakılan boşluk (güçlendirici çubuğu için).
const BOTTOM_SPACE := 148.0
## Vinç seçiminde parmakla dokunma payı (tasarım birimi).
const PICK_SLOP := 30.0

var catalog: LevelCatalog
var profile: PlayerProfile
var level: Dictionary = {}
var data: GameData
var board: Board
var dropper: Dropper
var effects: Effects
var session: GameSession
var hud: Hud
var boosters: BoosterManager

var _aiming := false
var _drop_pending := false
var _input_enabled := false
## Vinç: alınacak bina seçiliyor.
var _picking := false


## Ekranı kurar ve bölümü (boş sözlükse serbest oyunu) başlatır.
func start(p_catalog: LevelCatalog, p_profile: PlayerProfile, p_level: Dictionary) -> void:
	catalog = p_catalog
	profile = p_profile
	level = p_level
	if board == null:
		_build()
	_begin(true)


func _build() -> void:
	board = Board.new()
	board.name = "Board"
	add_child(board)
	board.setup(catalog.base)

	dropper = Dropper.new()
	dropper.name = "Dropper"
	board.add_child(dropper)

	effects = Effects.new()
	effects.name = "Effects"
	effects.reduced_motion = profile.setting("reduced_motion")
	board.add_child(effects)

	session = GameSession.new()
	session.name = "Session"
	add_child(session)
	session.setup(catalog.base, board)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(catalog.base)
	hud.start_pressed.connect(_on_start_pressed)
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(func(): _begin(false))
	hud.levels_pressed.connect(_to_levels)
	hud.next_pressed.connect(_to_next)

	session.queue_changed.connect(_on_queue_changed)
	session.scored.connect(_on_scored)
	session.finished.connect(_on_finished)
	session.goals_changed.connect(func(): hud.set_goals(session.goals.summary()))
	session.state_changed.connect(func(s: GameSession.State):
		hud.set_settling(s == GameSession.State.SETTLING)
		_refresh_boosters())
	session.moves_changed.connect(func(used: int, limit: int):
		hud.set_moves(used, limit)
		_refresh_boosters())
	session.restored.connect(_on_restored)
	session.cleared.connect(_on_cleared)
	session.lifted.connect(_on_lifted)

	boosters = BoosterManager.new()
	boosters.setup(session, profile)
	boosters.changed.connect(func():
		_refresh_boosters()
		profile_changed.emit())
	hud.booster_pressed.connect(_on_booster_pressed)
	hud.buy_confirmed.connect(_on_buy_confirmed)

	get_viewport().size_changed.connect(_layout)


## show_intro: bölüm ilk açıldığında giriş paneli; yeniden denemede atlanır.
func _begin(show_intro: bool) -> void:
	get_tree().paused = false
	hud.hide_panels()
	_drop_pending = false
	_aiming = false
	_set_picking(false)
	data = catalog.base if level.is_empty() else catalog.data_for(level)
	hud.set_data(data)
	# Bırakıcı oturumdan önce kurulur: oturum başlarken sıradaki binayı ona bildirir.
	dropper.setup(data, board)
	if level.is_empty():
		session.start(randi())
	else:
		session.start_level(level, data)
	dropper.set_aim(board.width * 0.5)
	hud.set_score(0)
	hud.set_moves(0, session.moves_limit)
	hud.set_goals(session.goals.summary())
	hud.set_settling(false)
	boosters.reset_attempt()
	_layout()
	_input_enabled = level.is_empty() or not show_intro
	if not _input_enabled:
		hud.show_intro(level, level.goals, _take_new_boosters(), profile.economy.boosters)


## Bu bölümde ilk kez görülecek güçlendiriciler (bir kez tanıtılır).
func _take_new_boosters() -> Array[String]:
	var out: Array[String] = []
	for id in boosters.visible_ids():
		if profile.boosters_new.has(id):
			out.append(id)
			profile.boosters_new.erase(id)
	if not out.is_empty():
		profile_changed.emit()
	return out


func _on_start_pressed() -> void:
	hud.hide_panels()
	_input_enabled = true


func _pause() -> void:
	if session.is_finished() or hud.any_panel_visible():
		return
	get_tree().paused = true
	hud.show_pause(level)


func _resume() -> void:
	hud.hide_panels()
	get_tree().paused = false
	_refresh_boosters()


func _to_levels() -> void:
	get_tree().paused = false
	exit_to_levels.emit()


func _to_next() -> void:
	play_level.emit(catalog.next_id(level.id))


func _process(_delta: float) -> void:
	if session == null:
		return
	if _drop_pending and session.can_drop():
		_drop_pending = not session.try_drop(dropper.aim_x) and session.state == GameSession.State.PLAYING
	dropper.set_ready(session.can_drop() and _input_enabled)
	if hud.is_debug_visible():
		hud.set_debug_text("FPS %d  |  bina %d  |  fizik %.2f ms\nhamle %d  birleşme %d  en yüksek seviye %d  alan dışı %d" % [
			Engine.get_frames_per_second(),
			board.building_count(),
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			session.moves, board.stats.merges, board.highest_level(), board.stats.out_of_bounds,
		])


func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_begin(false)
			KEY_F3:
				hud.toggle_debug()
			KEY_SPACE:
				_request_drop()
			KEY_ESCAPE:
				_pause()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				# Masaüstünde deneme kolaylığı: çubuktaki sıraya göre güçlendirici.
				var ids := boosters.visible_ids()
				var i: int = event.keycode - KEY_1
				if i < ids.size():
					_on_booster_pressed(ids[i])
			KEY_B:
				# Geliştirici: daire / yuvarlatılmış kare (deneysel) şekilleri karşılaştır.
				var physics := catalog.base.section("physics")
				physics.shape_mode = "rounded_box" if physics.shape_mode == "circle" else "circle"
				for lv in catalog.levels:
					catalog.data_for(lv).section("physics").shape_mode = physics.shape_mode
				_begin(false)
		return
	if not _input_enabled or get_tree().paused:
		return
	if _picking:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_pick_at(board.to_local(event.position))
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_aiming = true
			_aim(event.position)
		elif _aiming:
			_aiming = false
			_aim(event.position)
			_request_drop()
	elif event is InputEventMouseMotion:
		_aim(event.position)


func _notification(what: int) -> void:
	if session == null:
		return
	# Uygulama arka plana alınınca (mobil) ya da geri tuşunda oyunu duraklat.
	var backgrounded := what == NOTIFICATION_APPLICATION_PAUSED \
		or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
	if (backgrounded or what == NOTIFICATION_WM_GO_BACK_REQUEST) and _input_enabled:
		_pause()


func _aim(screen_pos: Vector2) -> void:
	if session.state != GameSession.State.PLAYING:
		return
	dropper.set_aim(board.to_local(screen_pos).x)


## Bırakma hemen yapılamıyorsa (bekleme süresi ya da bırakma noktasından
## henüz çekilmemiş bir bina), mümkün olur olmaz yapılır.
func _request_drop() -> void:
	if session.state != GameSession.State.PLAYING or not _input_enabled:
		return
	_drop_pending = not session.try_drop(dropper.aim_x) and session.state == GameSession.State.PLAYING


func _on_queue_changed(current: int, upcoming: Array[int]) -> void:
	dropper.set_level(current)
	hud.set_next(upcoming[0] if not upcoming.is_empty() else 0)
	_refresh_boosters()


# --- Güçlendiriciler ---

func _refresh_boosters() -> void:
	if boosters == null:
		return
	var states: Array[Dictionary] = []
	for id in boosters.visible_ids():
		var reason := boosters.check(id)
		var def := boosters.def(id)
		states.append({
			"id": id,
			"count": profile.booster_count(id),
			"price": int(def.price),
			"amount": int(def.get("amount", 5)),
			"active": reason == "" or reason == "none_owned",
			"highlighted": _picking and id == "crane",
		})
	hud.set_boosters(states)


func _on_booster_pressed(id: String) -> void:
	if not _input_enabled or get_tree().paused or session.is_finished():
		return
	if _picking:
		_set_picking(false)
		if id == "crane":
			return
	_drop_pending = false
	var reason := boosters.check(id)
	match reason:
		"":
			if id == "crane":
				_set_picking(true)
			else:
				_apply_booster(id)
		"none_owned":
			_open_shop(id)
		"limit":
			_toast(tr("BOOST_LIMIT") % int(boosters.def(id).per_level))
		"not_now":
			_toast(_not_now_text(id))


func _apply_booster(id: String, target: Building = null) -> void:
	var level_before := session.current_level()
	if not boosters.use(id, target):
		return
	match id:
		"undo":
			effects.popup(Vector2(dropper.aim_x, float(data.section("drop").dropper_y) + 140.0), tr("BOOST_UNDONE"), UiKit.BOOSTER_COLORS.undo, 46)
		"extra_moves":
			effects.popup(Vector2(board.width * 0.5, 160.0), tr("BOOST_MOVES_ADDED") % int(boosters.def(id).amount), UiKit.BOOSTER_COLORS.extra_moves, 52)
		"swap":
			effects.merge_burst(Vector2(dropper.aim_x, float(data.section("drop").dropper_y)), data.radius(level_before), UiKit.BOOSTER_COLORS.swap)
	if profile.setting("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(25)


func _not_now_text(id: String) -> String:
	if session.held_level > 0 and (id == "swap" or id == "crane"):
		return tr("BOOST_HOLDING")
	if session.state == GameSession.State.SETTLING and id != "undo" and id != "extra_moves":
		return tr("BOOST_NO_MOVES")
	return tr("BOOST_NOT_NOW_" + id.to_upper())


func _set_picking(value: bool) -> void:
	_picking = value
	if effects == null:
		return
	var targets: Array[Building] = []
	if value:
		for b in board.buildings:
			if boosters.can_lift(b):
				targets.append(b)
	effects.set_pick_targets(targets)
	hud.set_hint(tr("BOOST_PICK_HINT") if value else "")
	_refresh_boosters()


func _pick_at(p: Vector2) -> void:
	var b := board.building_at(p, PICK_SLOP)
	if b == null or not boosters.can_lift(b):
		return
	_set_picking(false)
	_apply_booster("crane", b)


func _open_shop(id: String) -> void:
	get_tree().paused = true
	var def := boosters.def(id)
	hud.show_buy(id, def, profile.wallet.balance(def.price_kind))


## Satın alma panelinde "Satın al ve kullan": bir adet alınır, panel kapanır
## ve güçlendirici hemen kullanılır (vinçte seçim başlar).
func _on_buy_confirmed(id: String) -> void:
	var reason := boosters.buy(id)
	_resume()
	if reason == "":
		_on_booster_pressed(id)
	elif reason == "cap":
		_toast(tr("SHOP_CAP") % profile.economy.inventory_cap)
	else:
		_toast(tr("SHOP_NOT_ENOUGH"))


func _toast(text: String) -> void:
	hud.show_toast(text, profile.setting("reduced_motion"))


func _on_restored() -> void:
	hud.set_score(session.score.score)
	hud.set_goals(session.goals.summary())
	_refresh_boosters()


func _on_cleared(removed: Array[Dictionary]) -> void:
	for r in removed:
		var def := data.level_def(int(r.level))
		effects.merge_burst(r.position, def.radius, UiKit.BOOSTER_COLORS.relieve)
	_refresh_boosters()


func _on_lifted(level: int, pos: Vector2) -> void:
	effects.merge_burst(pos, data.radius(level), UiKit.BOOSTER_COLORS.crane)


func _on_scored(points: int, total: int, info: Dictionary) -> void:
	hud.set_score(total)
	_refresh_boosters()
	var def := data.level_def(info.level)
	if info.kind == MergeResolver.Kind.LANDMARK:
		effects.merge_burst(info.position, def.radius * 1.4, def.color)
		effects.popup(info.position, "%s\n+%d" % [tr("LANDMARK_DONE"), points], def.accent, 56)
	else:
		effects.merge_burst(info.position, def.radius, def.color)
		var text := "+%d" % points
		if info.chain >= 2:
			text = "%s\n%s" % [text, tr("CHAIN_FMT") % info.chain]
		effects.popup(info.position, text, def.accent)
	if profile.setting("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(15)


func _on_finished(result: Dictionary) -> void:
	_drop_pending = false
	_input_enabled = false
	_set_picking(false)
	var rewards := profile.apply_result(level, result)
	profile_changed.emit()
	var has_next := false
	var tip := ""
	if not level.is_empty():
		var next_id := catalog.next_id(level.id)
		has_next = next_id != "" and catalog.is_unlocked(catalog.get_level(next_id), profile.progress)
		tip = _tip_for(profile.progress.fail_count(level.id))
	hud.show_result(result, level, has_next, profile.progress.free_best, tip, rewards)


## Art arda 2. başarısızlıktan itibaren bir ipucu gösterilir (satın alma önerisi yok).
func _tip_for(fails: int) -> String:
	if fails < 2:
		return ""
	var tips := [tr(level.hint_key), tr("TIP_GENERIC_1"), tr("TIP_GENERIC_2"), tr("TIP_GENERIC_3")]
	return tips[(fails - 2) % tips.size()]


func _layout() -> void:
	var vp := get_viewport_rect().size
	var offset_y := maxf(0.0, (vp.y - CONTENT_HEIGHT) * 0.5)
	board.position = Vector2(roundf((vp.x - board.width) * 0.5), roundf(offset_y + CONTENT_HEIGHT - BOTTOM_SPACE - board.height))
	board.queue_redraw()
	# Çubuk alanın altında (alan paneli 18 birim aşağı taşar).
	hud.layout(vp, offset_y + _safe_top_inset(vp), board.position.y + board.height + 26.0, board.position.y + 70.0)


## Çentik/durum çubuğu için üstten bırakılacak boşluk (tasarım biriminde).
func _safe_top_inset(vp: Vector2) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	return float(safe.position.y) * vp.y / float(win.y)
