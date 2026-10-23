class_name Hud
extends CanvasLayer
## Oyun ekranı arayüzü: menü düğmesi, kalan hamle, puan, sıradaki bina,
## bölüm hedefleri, güçlendirici çubuğu; giriş, duraklatma, satın alma ve
## sonuç panelleri; kısa bilgi yazısı; geliştirici göstergesi.
## GEÇİCİ TASARIM: Aşama 6'da tasarım sistemiyle yeniden ele alınacak.

signal start_pressed
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal levels_pressed
signal next_pressed
signal booster_pressed(id: String)
## Satın alma panelinde "Satın al ve kullan".
signal buy_confirmed(id: String)

const BAR_HEIGHT := 112.0

var data: GameData

var _root: Control
var _top: Control
var _pause_button: Button
var _moves_caption: Label
var _moves_label: Label
var _score_caption: Label
var _score_label: Label
var _next_caption: Label
var _next_preview: NextPreview
var _goals_row: HBoxContainer
var _settling_label: Label
var _debug_label: Label
var _intro: Array
var _pause: Array
var _result: Array
var _shop: Array
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
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, Vector2((size.x - nw) * 0.5, size.y - 14), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.INK)
		if count > 0:
			var c := Vector2(size.x - 28, 26)
			draw_circle(c, 22, UiKit.INK, true, -1.0, true)
			var t := str(count)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			draw_string(font, c + Vector2(-tw * 0.5, 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiKit.PAPER)
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


class NextPreview:
	extends Control
	var data: GameData
	var level := 0
	var shape_mode := "circle"

	func _draw() -> void:
		if data == null or level <= 0:
			return
		var r := minf(size.x, size.y) * 0.42
		draw_set_transform(size * 0.5)
		BuildingArt.draw_building(self, data.level_def(level), r, shape_mode, 1.0, false)
		draw_set_transform(Vector2.ZERO)


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

	_pause_button = UiKit.button(tr("HUD_PAUSE"), 34, true, Vector2(170, 96))
	_pause_button.pressed.connect(func(): pause_pressed.emit())
	_top.add_child(_pause_button)

	_moves_caption = UiKit.label(tr("HUD_MOVES_LEFT"), 28, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_top.add_child(_moves_caption)
	_moves_label = UiKit.label("0", 72, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_top.add_child(_moves_label)
	_score_caption = UiKit.label(tr("HUD_SCORE"), 28, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_top.add_child(_score_caption)
	_score_label = UiKit.label("0", 52, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_top.add_child(_score_label)

	_next_caption = UiKit.label(tr("HUD_NEXT"), 28, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_top.add_child(_next_caption)
	_next_preview = NextPreview.new()
	_next_preview.data = data
	_next_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_next_preview)

	_goals_row = HBoxContainer.new()
	_goals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_goals_row.add_theme_constant_override("separation", 16)
	_goals_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_goals_row)

	_settling_label = UiKit.label(tr("HUD_SETTLING"), 30, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_settling_label.visible = false
	_top.add_child(_settling_label)

	_debug_label = UiKit.label("", 26)
	_debug_label.visible = false
	_root.add_child(_debug_label)

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 14)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)

	_toast = UiKit.label("", 32, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toast_bg := StyleBoxFlat.new()
	toast_bg.bg_color = Color(UiKit.INK, 0.92)
	toast_bg.set_corner_radius_all(28)
	toast_bg.content_margin_left = 28
	toast_bg.content_margin_right = 28
	toast_bg.content_margin_top = 16
	toast_bg.content_margin_bottom = 16
	_toast.add_theme_stylebox_override("normal", toast_bg)
	_toast.visible = false
	_root.add_child(_toast)

	_intro = UiKit.overlay(_root)
	_pause = UiKit.overlay(_root)
	_shop = UiKit.overlay(_root)
	_result = UiKit.overlay(_root)


## Yeni bölüm/oyun için verileri tazeler (bölümler farklı kurallar kullanabilir).
func set_data(p_data: GameData) -> void:
	data = p_data
	_next_preview.data = data
	_next_preview.shape_mode = data.section("physics").shape_mode


## vp: görünür alan boyutu (tasarım birimi), top: güvenli alanın üst sınırı,
## bar_y: güçlendirici çubuğunun üst kenarı, toast_y: bilgi yazısının üst
## kenarı (alanın üst kısmı: vinç seçiminde alttaki binaları örtmesin).
func layout(vp: Vector2, top: float, bar_y: float = -1.0, toast_y: float = -1.0) -> void:
	var w := minf(vp.x, 1080.0)
	var left := (vp.x - w) * 0.5
	_top.position = Vector2(left, top)
	_top.size = Vector2(w, 320)
	_pause_button.position = Vector2(36, 44)
	_pause_button.size = Vector2(170, 96)
	_moves_caption.position = Vector2(w * 0.5 - 250, 24)
	_moves_caption.size = Vector2(220, 36)
	_moves_label.position = Vector2(w * 0.5 - 250, 56)
	_moves_label.size = Vector2(220, 96)
	_score_caption.position = Vector2(w * 0.5 + 30, 24)
	_score_caption.size = Vector2(220, 36)
	_score_label.position = Vector2(w * 0.5 + 30, 66)
	_score_label.size = Vector2(220, 80)
	_next_caption.position = Vector2(w - 230, 24)
	_next_caption.size = Vector2(190, 36)
	_next_preview.position = Vector2(w - 195, 60)
	_next_preview.size = Vector2(120, 110)
	_goals_row.position = Vector2(20, 176)
	_goals_row.size = Vector2(w - 40, 96)
	_settling_label.position = Vector2(0, 278)
	_settling_label.size = Vector2(w, 40)
	_debug_label.position = Vector2(left + 24, vp.y - 110)
	_debug_label.size = Vector2(w - 48, 100)
	if bar_y < 0.0:
		bar_y = vp.y - BAR_HEIGHT - 10.0
	_bar.position = Vector2(left, bar_y)
	_bar.size = Vector2(w, BAR_HEIGHT)
	_toast.position = Vector2(left + 90, toast_y if toast_y >= 0.0 else bar_y - 150.0)
	_toast.size = Vector2(w - 180, 0)


func set_moves(used: int, limit: int) -> void:
	_moves_caption.text = tr("HUD_MOVES_LEFT")
	_moves_label.text = str(limit - used) if limit > 0 else str(used)
	var low := limit > 0 and limit - used <= 3
	_moves_label.add_theme_color_override("font_color", UiKit.ACCENT if low else UiKit.INK)


func set_score(value: int) -> void:
	_score_label.text = str(value)


func set_next(level: int) -> void:
	_next_preview.level = level
	_next_preview.queue_redraw()


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
		box.add_child(UiKit.label(tr("UI_NEW_BOOSTER"), 28, UiKit.ACCENT))
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
	var levels := UiKit.button(tr("PAUSE_TO_LEVELS"), 42, false)
	levels.pressed.connect(func(): levels_pressed.emit())
	box.add_child(levels)
	_show(_pause)


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
	box.add_child(UiKit.label(title, 60, UiKit.GOOD if result.won else UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
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
	for p in [_intro, _pause, _shop, _result]:
		p[0].visible = false


func any_panel_visible() -> bool:
	return _intro[0].visible or _pause[0].visible or _shop[0].visible or _result[0].visible


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
	var l := UiKit.label(text, 34, UiKit.GOOD)
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
		col.add_child(UiKit.label(tr("UI_GIFT_FMT") % int(def.gift), 30, UiKit.GOOD))
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
