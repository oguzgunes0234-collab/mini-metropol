class_name Hud
extends CanvasLayer
## Oyun ekranı arayüzü: menü düğmesi, kalan hamle, puan, sıradaki bina,
## bölüm hedefleri; giriş, duraklatma ve sonuç panelleri; geliştirici göstergesi.
## GEÇİCİ TASARIM: Aşama 6'da tasarım sistemiyle yeniden ele alınacak.

signal start_pressed
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal levels_pressed
signal next_pressed

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
var _chips: Array[UiKit.GoalChip] = []


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

	_intro = UiKit.overlay(_root)
	_pause = UiKit.overlay(_root)
	_result = UiKit.overlay(_root)


## Yeni bölüm/oyun için verileri tazeler (bölümler farklı kurallar kullanabilir).
func set_data(p_data: GameData) -> void:
	data = p_data
	_next_preview.data = data
	_next_preview.shape_mode = data.section("physics").shape_mode


## vp: görünür alan boyutu (tasarım birimi), top: güvenli alanın üst sınırı.
func layout(vp: Vector2, top: float) -> void:
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


# --- Paneller ---

func show_intro(level: Dictionary, goals: Array) -> void:
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
func show_result(result: Dictionary, level: Dictionary, has_next: bool, best_score: int, tip: String) -> void:
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


func hide_panels() -> void:
	for p in [_intro, _pause, _result]:
		p[0].visible = false


func any_panel_visible() -> bool:
	return _intro[0].visible or _pause[0].visible or _result[0].visible


func is_debug_visible() -> bool:
	return _debug_label.visible


func toggle_debug() -> void:
	_debug_label.visible = not _debug_label.visible


func set_debug_text(text: String) -> void:
	_debug_label.text = text


func _show(p: Array) -> void:
	hide_panels()
	p[0].visible = true


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
