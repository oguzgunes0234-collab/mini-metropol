extends Node2D
## Oyun ekranı denetleyicisi: dokunma/fare girdisi, yerleşim, arayüz ve
## efektleri GameSession'a bağlar. Oyun kuralları burada değil,
## GameSession ve Board içindedir.

## Tasarım yüksekliği: içerik bu yüksekliğe göre yerleştirilir, daha uzun
## ekranlarda dikey olarak ortalanır.
const CONTENT_HEIGHT := 1920.0
## Alanın altında bırakılan boşluk (ileride güçlendirici çubuğu için).
const BOTTOM_SPACE := 170.0

var data: GameData
var board: Board
var dropper: Dropper
var effects: Effects
var session: GameSession
var hud: Hud

var haptics_enabled := true

var _aiming := false
var _drop_pending := false
var _best_score := 0


func _ready() -> void:
	data = GameData.load_default()
	if not data.is_valid():
		for e in data.errors:
			push_error(e)
		_show_data_error()
		return

	board = Board.new()
	board.name = "Board"
	add_child(board)
	board.setup(data)

	dropper = Dropper.new()
	dropper.name = "Dropper"
	board.add_child(dropper)
	dropper.setup(data, board)

	effects = Effects.new()
	effects.name = "Effects"
	board.add_child(effects)

	session = GameSession.new()
	session.name = "Session"
	add_child(session)
	session.setup(data, board)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(data)
	hud.restart_pressed.connect(_restart)
	hud.resume_pressed.connect(_resume)

	session.queue_changed.connect(_on_queue_changed)
	session.scored.connect(_on_scored)
	session.finished.connect(_on_finished)
	session.dropped.connect(func(_level: int, _b: Building): hud.set_moves(session.moves))

	get_viewport().size_changed.connect(_layout)
	_layout()
	_restart()


func _restart() -> void:
	get_tree().paused = false
	hud.show_pause(false)
	hud.hide_game_over()
	_drop_pending = false
	_aiming = false
	session.start(randi())
	hud.set_score(0)
	hud.set_moves(0)


func _resume() -> void:
	hud.show_pause(false)
	get_tree().paused = false


func _process(_delta: float) -> void:
	if session == null:
		return
	if _drop_pending and session.can_drop():
		_drop_pending = not session.try_drop(dropper.aim_x) and session.state == GameSession.State.PLAYING
	dropper.set_ready(session.can_drop())
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
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_restart()
			KEY_F3:
				hud.toggle_debug()
			KEY_SPACE:
				_request_drop()
			KEY_B:
				# Geliştirici: daire / yuvarlatılmış kare (deneysel) şekilleri karşılaştır.
				var physics := data.section("physics")
				physics.shape_mode = "rounded_box" if physics.shape_mode == "circle" else "circle"
				get_tree().reload_current_scene()


func _notification(what: int) -> void:
	# Uygulama arka plana alınınca oyunu duraklat (mobil).
	var backgrounded := what == NOTIFICATION_APPLICATION_PAUSED \
		or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
	if backgrounded and session != null and session.state == GameSession.State.PLAYING:
		get_tree().paused = true
		hud.show_pause(true)


func _aim(screen_pos: Vector2) -> void:
	if session.state != GameSession.State.PLAYING:
		return
	dropper.set_aim(board.to_local(screen_pos).x)


## Bırakma hemen yapılamıyorsa (bekleme süresi ya da bırakma noktasından
## henüz çekilmemiş bir bina), mümkün olur olmaz yapılır.
func _request_drop() -> void:
	if session.state != GameSession.State.PLAYING:
		return
	_drop_pending = not session.try_drop(dropper.aim_x) and session.state == GameSession.State.PLAYING


func _on_queue_changed(current: int, upcoming: Array[int]) -> void:
	dropper.set_level(current)
	hud.set_next(upcoming[0] if not upcoming.is_empty() else 0)


func _on_scored(points: int, total: int, info: Dictionary) -> void:
	hud.set_score(total)
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
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(15)


func _on_finished(result: Dictionary) -> void:
	_best_score = maxi(_best_score, result.score)
	_drop_pending = false
	hud.show_game_over(result.score, _best_score)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var offset_y := maxf(0.0, (vp.y - CONTENT_HEIGHT) * 0.5)
	board.position = Vector2(roundf((vp.x - board.width) * 0.5), roundf(offset_y + CONTENT_HEIGHT - BOTTOM_SPACE - board.height))
	hud.layout(vp, offset_y + _safe_top_inset(vp))


## Çentik/durum çubuğu için üstten bırakılacak boşluk (tasarım biriminde).
func _safe_top_inset(vp: Vector2) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	return float(safe.position.y) * vp.y / float(win.y)


func _show_data_error() -> void:
	var label := Label.new()
	label.text = "%s\n%s" % [tr("DATA_ERROR"), "\n".join(data.errors)]
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#B00020"))
	label.position = Vector2(40, 120)
	label.size = Vector2(1000, 1600)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
