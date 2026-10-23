class_name Hud
extends CanvasLayer
## Oyun ekranı arayüzü: menü düğmesi, kalan hamle, puan, sıradaki bina,
## bölüm hedefleri, güçlendirici çubuğu; giriş, duraklatma, satın alma ve
## sonuç panelleri; kısa bilgi yazısı; geliştirici göstergesi.
## Yerleşim GameLayout'tan gelir; görünüm UiKit belirteçlerini kullanır.

signal start_pressed
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal levels_pressed
signal next_pressed
signal booster_pressed(id: String)
signal settings_pressed
## Satın alma panelinde "Satın al ve kullan".
signal buy_confirmed(id: String)

const BAR_HEIGHT := GameLayout.BAR_HEIGHT

var data: GameData

var _root: Control
var _top: Control
var _pause_button: UiKit.IconButton
var _moves_card: StatCard
var _score_card: StatCard
var _next_card: StatCard
var _goals_row: HBoxContainer
var _settling_label: Label
var _debug_label: Label
var _intro: Array
var _pause: Array
var _result: Array
var _shop: Array
var _settings: Array
var _chips: Array[UiKit.GoalChip] = []
var _bar: HBoxContainer
var _booster_buttons := {}
var _toast: Label
var _toast_tween: Tween
var _hint_visible := false


## Güçlendirici çubuğundaki düğme: simge, ad, adet (yoksa fiyat).
class BoosterButton:
	extends Control
	signal pressed(id: String)
	var id := ""
	var count := 0
	var price := 0
	var amount := 5
	var active := true
	var highlighted := false

	func _init(p_id: String) -> void:
		id = p_id
		custom_minimum_size = Vector2(184, Hud.BAR_HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	## count: envanterdeki adet; price: tek adet fiyatı (adet 0 ise gösterilir);
	## active: şu an kullanılabilir ya da satın alınabilir; highlighted: vinç seçimi sürüyor.
	func set_state(p_count: int, p_price: int, p_amount: int, p_active: bool, p_highlighted: bool) -> void:
		count = p_count
		price = p_price
		amount = p_amount
		active = p_active
		highlighted = p_highlighted
		modulate.a = 1.0 if active or highlighted else 0.42
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit(id)

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = UiKit.STAR.lightened(0.6) if highlighted else UiKit.PAPER
		bg.set_corner_radius_all(28)
		bg.border_color = UiKit.ACCENT if highlighted else UiKit.INK.lightened(0.6)
		bg.set_border_width_all(5 if highlighted else 3)
		bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		UiKit.draw_booster_icon(self, id, Vector2(size.x * 0.5, 44), 30, amount)
		var font := ThemeDB.fallback_font
		var name := UiKit.booster_name(id)
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION).x
		draw_string(font, Vector2((size.x - nw) * 0.5, size.y - 14), name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION, UiKit.INK)
		if count > 0:
			var c := Vector2(size.x - 28, 26)
			draw_circle(c, 22, UiKit.INK, true, -1.0, true)
			var t := str(count)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION).x
			draw_string(font, c + Vector2(-tw * 0.5, 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION, UiKit.PAPER)
		else:
			# Envanterde yok: fiyat (madeni para) gösterilir.
			var t := str(price)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			var pill := Rect2(size.x - tw - 52, 6, tw + 46, 38)
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color("#FFF1CF")
			ps.set_corner_radius_all(19)
			ps.draw(get_canvas_item(), pill)
			var cc := pill.position + Vector2(19, 19)
			draw_circle(cc, 13, Color("#E39B1F"), true, -1.0, true)
			draw_circle(cc, 9, Color("#F7CD6B"), true, -1.0, true)
			draw_string(font, pill.position + Vector2(38, 28), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.INK)


## Üst sıradaki kart: küçük başlık + büyük değer (ya da sıradaki binanın çizimi).
class StatCard:
	extends Control
	var caption := ""
	var value := ""
	var value_size := 64
	var value_color := UiKit.INK
	## 0'dan büyükse değer yerine bu seviyedeki bina çizilir.
	var preview_level := 0
	var data: GameData
	var shape_mode := "circle"

	func _init(p_caption: String, p_value_size: int = 64) -> void:
		caption = p_caption
		value_size = p_value_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.flat_box(UiKit.PAPER, UiKit.R_MD, UiKit.LINE, 3).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var f := UiKit.font()
		var cw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION).x
		if preview_level > 0 and data != null:
			draw_string(f, Vector2(22, size.y * 0.5 + 10), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION, UiKit.INK_SOFT)
			var r := size.y * 0.36
			draw_set_transform(Vector2(size.x - r - 22, size.y * 0.5))
			BuildingArt.draw_building(self, data.level_def(preview_level), r, shape_mode, 1.0, true)
			draw_set_transform(Vector2.ZERO)
			return
		draw_string(f, Vector2((size.x - cw) * 0.5, 36), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.T_CAPTION, UiKit.INK_SOFT)
		var hf := UiKit.font_heavy()
		var vw := hf.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
		draw_string(hf, Vector2((size.x - vw) * 0.5, size.y - 20), value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size, value_color)


func setup(p_data: GameData) -> void:
	data = p_data
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)

	_pause_button = UiKit.IconButton.new("pause", tr("HUD_PAUSE"), true)
	_pause_button.pressed.connect(func(): pause_pressed.emit())
	_top.add_child(_pause_button)

	_moves_card = StatCard.new(tr("HUD_MOVES_LEFT"), 64)
	_top.add_child(_moves_card)
	_score_card = StatCard.new(tr("HUD_SCORE"), 52)
	_top.add_child(_score_card)
	_next_card = StatCard.new(tr("HUD_NEXT"))
	_next_card.data = data
	_top.add_child(_next_card)

	_goals_row = HBoxContainer.new()
	_goals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_goals_row.add_theme_constant_override("separation", 16)
	_goals_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_goals_row)

	_settling_label = UiKit.label(tr("HUD_SETTLING"), UiKit.T_LABEL, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_settling_label.add_theme_stylebox_override("normal", _pill_style(UiKit.ACCENT_TEXT))
	_settling_label.visible = false
	_root.add_child(_settling_label)

	_debug_label = UiKit.label("", UiKit.T_CAPTION)
	_debug_label.visible = false
	_root.add_child(_debug_label)

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 14)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)

	_toast = UiKit.label("", UiKit.T_LABEL, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", _pill_style(Color(UiKit.INK, 0.94)))
	_toast.visible = false
	_root.add_child(_toast)

	_intro = UiKit.overlay(_root)
	_pause = UiKit.overlay(_root)
	_shop = UiKit.overlay(_root)
	_settings = UiKit.overlay(_root, 860)
	_result = UiKit.overlay(_root)


func _pill_style(bg: Color) -> StyleBoxFlat:
	var sb := UiKit.flat_box(bg, UiKit.R_MD)
	sb.content_margin_left = UiKit.S_MD
	sb.content_margin_right = UiKit.S_MD
	sb.content_margin_top = UiKit.S_SM
	sb.content_margin_bottom = UiKit.S_SM
	return sb


## Yeni bölüm/oyun için verileri tazeler (bölümler farklı kurallar kullanabilir).
func set_data(p_data: GameData) -> void:
	data = p_data
	_next_card.data = data
	_next_card.shape_mode = data.section("physics").shape_mode
	_next_card.queue_redraw()


## l: GameLayout.compute sonucu; vp: görünür alan (tasarım birimi).
func layout(vp: Vector2, l: Dictionary) -> void:
	var w: float = l.width
	var left: float = l.left
	_top.position = Vector2(left, l.hud_top)
	_top.size = Vector2(w, GameLayout.HUD_HEIGHT)
	var row := GameLayout.HUD_ROW
	var gap := 16.0
	_pause_button.position = Vector2(24, GameLayout.HUD_PAD)
	_pause_button.size = Vector2(row, row)
	var x := 24.0 + row + gap
	var card_w := (w - x - 24.0 - gap * 2.0) / 3.0
	for card in [_moves_card, _score_card, _next_card]:
		card.position = Vector2(x, GameLayout.HUD_PAD)
		card.size = Vector2(card_w, row)
		x += card_w + gap
	_goals_row.position = Vector2(20, GameLayout.GOALS_Y)
	_goals_row.size = Vector2(w - 40, GameLayout.GOALS_H)
	_bar.position = Vector2(left, l.bar_y)
	_bar.size = Vector2(w, BAR_HEIGHT)
	_toast.position = Vector2(left + 90, l.toast_y)
	_toast.size = Vector2(w - 180, 0)
	_settling_label.position = Vector2(left + 180, l.toast_y + 110.0)
	_settling_label.size = Vector2(w - 360, 0)
	_debug_label.position = Vector2(left + 24, l.toast_y + 220.0)
	_debug_label.size = Vector2(w - 48, 100)


func set_moves(used: int, limit: int) -> void:
	_moves_card.value = str(limit - used) if limit > 0 else str(used)
	var low := limit > 0 and limit - used <= 3
	_moves_card.value_color = UiKit.ACCENT_TEXT if low else UiKit.INK
	_moves_card.queue_redraw()


func set_score(value: int) -> void:
	_score_card.value = str(value)
	_score_card.queue_redraw()


func set_next(level: int) -> void:
	_next_card.preview_level = level
	_next_card.queue_redraw()


func set_goals(summary: Array) -> void:
	if summary.size() != _chips.size():
		UiKit.clear(_goals_row)
		_chips.clear()
		for g in summary:
			var chip := UiKit.GoalChip.new(data, g)
			_goals_row.add_child(chip)
			_chips.append(chip)
	for i in summary.size():
		_chips[i].data = data
		_chips[i].set_goal(summary[i])


func set_settling(value: bool) -> void:
	_settling_label.visible = value


# --- Güçlendirici çubuğu ---

## states: [{id, count, price, amount, active, highlighted}], çubuk sırasıyla.
## Liste boşsa çubuk gizlenir (serbest oyun, henüz açılmamış güçlendiriciler).
func set_boosters(states: Array[Dictionary]) -> void:
	var ids := states.map(func(st): return st.id)
	if ids != _booster_buttons.keys():
		UiKit.clear(_bar)
		_booster_buttons.clear()
		for id in ids:
			var b := BoosterButton.new(id)
			b.name = "Booster_" + id
			b.pressed.connect(func(bid: String): booster_pressed.emit(bid))
			_bar.add_child(b)
			_booster_buttons[id] = b
	for st in states:
		_booster_buttons[st.id].set_state(st.count, st.price, st.amount, st.active, st.highlighted)
	_bar.visible = not states.is_empty()


func booster_button(id: String) -> Control:
	return _booster_buttons.get(id)


## Kısa bilgi yazısı (birkaç saniye sonra kaybolur).
func show_toast(text: String, reduced_motion: bool = false) -> void:
	_hint_visible = false
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	if reduced_motion:
		_toast_tween.tween_callback(func(): _toast.visible = false)
	else:
		_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
		_toast_tween.tween_callback(func(): _toast.visible = false)


## Kalıcı yönerge (vinç seçimi sırasında). Boş metin gizler.
func set_hint(text: String) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_hint_visible = text != ""
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.visible = _hint_visible


func toast_text() -> String:
	return _toast.text if _toast.visible else ""


# --- Paneller ---

## new_boosters: bu bölümde ilk kez kullanılabilecek güçlendiriciler (tanıtım),
## booster_defs: economy.boosters (açıklamadaki sayılar ve hediye adedi için).
func show_intro(level: Dictionary, goals: Array, new_boosters: Array[String] = [], booster_defs: Dictionary = {}) -> void:
	var box: VBoxContainer = _intro[1]
	UiKit.clear(box)
	box.add_child(UiKit.label(tr("UI_LEVEL_FMT") % level.id, 32, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(tr(level.name_key), 60, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(tr("UI_GOALS"), 28, UiKit.INK_SOFT))
	for g in goals:
		box.add_child(_goal_line(g))
	box.add_child(UiKit.label(tr("UI_STARS"), 28, UiKit.INK_SOFT))
	for s in level.stars:
		box.add_child(_star_line(UiKit.star_text(s), true))
	var hint := UiKit.label(tr(level.hint_key), 32, UiKit.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(640, 0)
	box.add_child(hint)
	for id in new_boosters:
		box.add_child(UiKit.label(tr("UI_NEW_BOOSTER"), UiKit.T_CAPTION, UiKit.ACCENT_TEXT))
		box.add_child(_booster_row(id, booster_defs.get(id, {}), true))
	var start := UiKit.button(tr("UI_START"), 44)
	start.pressed.connect(func(): start_pressed.emit())
	box.add_child(start)
	_show(_intro)


func show_pause(level: Dictionary) -> void:
	var box: VBoxContainer = _pause[1]
	UiKit.clear(box)
	box.add_child(UiKit.label(tr("PAUSE_TITLE"), 60, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if not level.is_empty():
		box.add_child(UiKit.label("%s — %s" % [tr("UI_LEVEL_FMT") % level.id, tr(level.name_key)], 32, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UiKit.button(tr("PAUSE_RESUME"), 42)
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	var restart := UiKit.button(tr("PAUSE_RESTART"), 42, false)
	restart.pressed.connect(func(): restart_pressed.emit())
	box.add_child(restart)
	var settings := UiKit.button(tr("UI_SETTINGS"), 42, false)
	settings.name = "Settings"
	settings.pressed.connect(func(): settings_pressed.emit())
	box.add_child(settings)
	var levels := UiKit.button(tr("PAUSE_TO_LEVELS"), 42, false)
	levels.pressed.connect(func(): levels_pressed.emit())
	box.add_child(levels)
	_show(_pause)


## Oyun içi ayarlar (duraklatma panelinden): dil ve sıfırlama yok.
## Kapatınca duraklatma paneline dönülür. Dönüş: ayarlar içeriği.
func show_settings(profile: PlayerProfile, level: Dictionary) -> SettingsView:
	var box: VBoxContainer = _settings[1]
	UiKit.clear(box)
	box.add_child(UiKit.heading(tr("UI_SETTINGS"), UiKit.T_TITLE))
	var view := SettingsView.new()
	view.setup(profile, false, false)
	box.add_child(view)
	var close := UiKit.button(tr("UI_CLOSE"), 42)
	close.name = "Close"
	close.pressed.connect(func(): show_pause(level))
	box.add_child(close)
	_show(_settings)
	return view


func is_settings_visible() -> bool:
	return _settings[0].visible


## Bölüm/oyun sonucu. tip: art arda başarısızlıktan sonra gösterilecek ipucu ("" ise yok).
## rewards: PlayerProfile.apply_result dönüşü (ödül satırları).
func show_result(result: Dictionary, level: Dictionary, has_next: bool, best_score: int, tip: String, rewards: Dictionary = {}) -> void:
	var box: VBoxContainer = _result[1]
	UiKit.clear(box)
	var title: String
	if result.won:
		title = tr("RESULT_WON")
	elif result.reason == "out_of_moves":
		title = tr("RESULT_OUT_OF_MOVES")
	else:
		title = tr("RESULT_LOT_FULL")
	box.add_child(UiKit.heading(title, UiKit.T_TITLE, UiKit.GOOD_TEXT if result.won else UiKit.INK))
	if not level.is_empty():
		box.add_child(UiKit.label("%s — %s" % [tr("UI_LEVEL_FMT") % level.id, tr(level.name_key)], 30, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		if result.won:
			box.add_child(UiKit.StarRow.new(result.star_flags, 46))
			for i in level.stars.size():
				box.add_child(_star_line(UiKit.star_text(level.stars[i]), result.star_flags[i]))
		else:
			for g in result.goals:
				box.add_child(_goal_line(g))
		box.add_child(UiKit.label(tr("RESULT_MOVES_USED") % [result.moves_used, result.moves_limit], 34, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(tr("GAMEOVER_SCORE") % result.score, 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if level.is_empty():
		box.add_child(UiKit.label(tr("GAMEOVER_BEST") % best_score, 32, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	for line in rewards.get("lines", []):
		box.add_child(_reward_line(line))
	if tip != "":
		var tip_label := UiKit.label("%s: %s" % [tr("TIP_TITLE"), tip], 32, UiKit.INK_SOFT)
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_label.custom_minimum_size = Vector2(640, 0)
		box.add_child(tip_label)
	if result.won and has_next:
		var next := UiKit.button(tr("UI_NEXT"), 44)
		next.pressed.connect(func(): next_pressed.emit())
		box.add_child(next)
	var again := UiKit.button(tr("UI_REPLAY") if result.won else tr("UI_RETRY"), 42, not (result.won and has_next))
	again.pressed.connect(func(): restart_pressed.emit())
	box.add_child(again)
	var levels := UiKit.button(tr("PAUSE_TO_LEVELS") if not level.is_empty() else tr("UI_LEVELS"), 42, false)
	levels.pressed.connect(func(): levels_pressed.emit())
	box.add_child(levels)
	_show(_result)


## Satın alma paneli. def: economy.boosters[id]; balance: oyuncunun bakiyesi
## (fiyatın para biriminde). Bakiye yetmiyorsa yalnızca bilgi ve "Tamam" vardır:
## gerçek parayla satın alma önerisi yoktur.
func show_buy(id: String, def: Dictionary, balance: int) -> void:
	var box: VBoxContainer = _shop[1]
	UiKit.clear(box)
	box.add_child(_booster_row(id, def, false))
	box.add_child(UiKit.label(tr("BOOST_LIMIT") % int(def.per_level), 28, UiKit.INK_SOFT))
	box.add_child(_amount_row(tr("SHOP_PRICE"), int(def.price), def.price_kind))
	box.add_child(_amount_row(tr("SHOP_BALANCE"), balance, def.price_kind))
	if balance >= int(def.price):
		var buy := UiKit.button(tr("SHOP_BUY_AND_USE"), 42)
		buy.name = "Buy"
		buy.pressed.connect(func(): buy_confirmed.emit(id))
		box.add_child(buy)
		var cancel := UiKit.button(tr("UI_CANCEL"), 42, false)
		cancel.name = "Cancel"
		cancel.pressed.connect(func(): resume_pressed.emit())
		box.add_child(cancel)
	else:
		var msg := UiKit.label(tr("SHOP_NOT_ENOUGH"), 32, UiKit.INK)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(640, 0)
		box.add_child(msg)
		var ok := UiKit.button(tr("UI_OK"), 42)
		ok.name = "Cancel"
		ok.pressed.connect(func(): resume_pressed.emit())
		box.add_child(ok)
	_show(_shop)


func is_shop_visible() -> bool:
	return _shop[0].visible


func shop_button(button_name: String) -> Button:
	return _shop[1].get_node_or_null(button_name)


func hide_panels() -> void:
	for p in [_intro, _pause, _shop, _settings, _result]:
		p[0].visible = false


func any_panel_visible() -> bool:
	for p in [_intro, _pause, _shop, _settings, _result]:
		if p[0].visible:
			return true
	return false


func is_debug_visible() -> bool:
	return _debug_label.visible


func toggle_debug() -> void:
	_debug_label.visible = not _debug_label.visible


func set_debug_text(text: String) -> void:
	_debug_label.text = text


func _show(p: Array) -> void:
	hide_panels()
	p[0].visible = true


func _reward_line(line: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := tr(line.key)
	if line.key == "REWARD_NEW_STARS" or line.key == "REWARD_MILESTONE":
		text = text % int(line.value)
	elif line.key == "REWARD_BOOSTER_UNLOCKED":
		text = text % UiKit.booster_name(String(line.booster))
	var l := UiKit.label(text, 32, UiKit.INK_SOFT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	if int(line.get("coins", 0)) > 0:
		row.add_child(UiKit.CoinIcon.new(22))
		row.add_child(_amount_label("+%d" % int(line.coins)))
	if int(line.get("diamonds", 0)) > 0:
		row.add_child(UiKit.DiamondIcon.new(22))
		row.add_child(_amount_label("+%d" % int(line.diamonds)))
	var boosters: Dictionary = line.get("boosters", {})
	for id in boosters:
		if int(boosters[id]) > 0:
			row.add_child(UiKit.BoosterIcon.new(id, 22))
			row.add_child(_amount_label("×%d" % int(boosters[id])))
	return row


func _amount_label(text: String) -> Label:
	var l := UiKit.label(text, 34, UiKit.GOOD_TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Güçlendirici simgesi, adı ve açıklaması. gift: açılış hediyesi adedini de yaz.
func _booster_row(id: String, def: Dictionary, gift: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.BoosterIcon.new(id, 40, int(def.get("amount", 5))))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UiKit.label(UiKit.booster_name(id), 40, UiKit.INK))
	var desc := UiKit.label(UiKit.booster_desc(id, def), 30, UiKit.INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(540, 0)
	col.add_child(desc)
	if gift and int(def.get("gift", 0)) > 0:
		col.add_child(UiKit.label(tr("UI_GIFT_FMT") % int(def.gift), 30, UiKit.GOOD_TEXT))
	row.add_child(col)
	return row


func _amount_row(caption: String, amount: int, kind: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label("%s:" % caption, 34, UiKit.INK_SOFT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(UiKit.DiamondIcon.new(22) if kind == "diamonds" else UiKit.CoinIcon.new(22))
	var a := UiKit.label(str(amount), 36, UiKit.INK)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	return row


func _star_line(text: String, filled: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.StarRow.new([filled], 18))
	var l := UiKit.label(text, 34, UiKit.INK if filled else UiKit.INK_SOFT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _goal_line(g: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary := g.duplicate()
	if not summary.has("target"):
		summary.target = int(g.get("count", g.get("value", 0)))
	var chip := UiKit.GoalChip.new(data, summary)
	row.add_child(chip)
	var text := UiKit.label(UiKit.goal_text(data, g), 34)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	return row
