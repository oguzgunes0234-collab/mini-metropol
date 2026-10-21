class_name Hud
extends CanvasLayer
## Oyun ekranı arayüzü: puan, sıradaki bina, hamle sayısı, yeniden başlat,
## oyun sonu ve duraklatma panelleri, geliştirici göstergesi.
## GEÇİCİ TASARIM: Aşama 6'da tasarım sistemiyle yeniden ele alınacak.

signal restart_pressed
signal resume_pressed

const INK := Color("#2F4858")
const PAPER := Color("#FFFDF8")
const ACCENT := Color("#F26419")

var data: GameData

var _root: Control
var _top: Control
var _score_caption: Label
var _score_label: Label
var _moves_label: Label
var _next_caption: Label
var _next_preview: NextPreview
var _restart_button: Button
var _debug_label: Label
var _game_over: Control
var _game_over_score: Label
var _game_over_best: Label
var _pause: Control


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

	_score_caption = _make_label(tr("HUD_SCORE"), 30, INK.lightened(0.25))
	_score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_score_caption)
	_score_label = _make_label("0", 84, INK)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_score_label)
	_moves_label = _make_label("", 30, INK.lightened(0.25))
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_moves_label)

	_next_caption = _make_label(tr("HUD_NEXT"), 28, INK.lightened(0.25))
	_next_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_next_caption)
	_next_preview = NextPreview.new()
	_next_preview.data = data
	_next_preview.shape_mode = data.section("physics").shape_mode
	_next_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_next_preview)

	_restart_button = _make_button(tr("HUD_RESTART"), 34)
	_restart_button.pressed.connect(func(): restart_pressed.emit())
	_top.add_child(_restart_button)

	_debug_label = _make_label("", 26, INK)
	_debug_label.visible = false
	_root.add_child(_debug_label)

	_game_over = _make_overlay()
	var go_box := _game_over.get_node("Panel/Box") as VBoxContainer
	go_box.add_child(_make_label(tr("GAMEOVER_TITLE"), 60, INK, true))
	_game_over_score = _make_label("", 44, INK, true)
	go_box.add_child(_game_over_score)
	_game_over_best = _make_label("", 32, INK.lightened(0.3), true)
	go_box.add_child(_game_over_best)
	var retry := _make_button(tr("GAMEOVER_RETRY"), 44)
	retry.pressed.connect(func(): restart_pressed.emit())
	go_box.add_child(retry)

	_pause = _make_overlay()
	var pause_box := _pause.get_node("Panel/Box") as VBoxContainer
	pause_box.add_child(_make_label(tr("PAUSE_TITLE"), 60, INK, true))
	var resume := _make_button(tr("PAUSE_RESUME"), 44)
	resume.pressed.connect(func(): resume_pressed.emit())
	pause_box.add_child(resume)


## vp: görünür alan boyutu (tasarım birimi), top: güvenli alanın üst sınırı.
func layout(vp: Vector2, top: float) -> void:
	var w := minf(vp.x, 1080.0)
	var left := (vp.x - w) * 0.5
	_top.position = Vector2(left, top)
	_top.size = Vector2(w, 300)
	_score_caption.position = Vector2(w * 0.5 - 200, 28)
	_score_caption.size = Vector2(400, 40)
	_score_label.position = Vector2(w * 0.5 - 250, 62)
	_score_label.size = Vector2(500, 100)
	_moves_label.position = Vector2(w * 0.5 - 200, 162)
	_moves_label.size = Vector2(400, 40)
	_next_caption.position = Vector2(w - 230, 28)
	_next_caption.size = Vector2(180, 40)
	_next_preview.position = Vector2(w - 200, 70)
	_next_preview.size = Vector2(120, 120)
	_restart_button.position = Vector2(50, 60)
	_restart_button.size = Vector2(200, 96)
	_debug_label.position = Vector2(left + 24, vp.y - 140)
	_debug_label.size = Vector2(w - 48, 120)


func set_score(value: int) -> void:
	_score_label.text = str(value)


func set_moves(value: int) -> void:
	_moves_label.text = "%s: %d" % [tr("HUD_MOVES"), value]


func set_next(level: int) -> void:
	_next_preview.level = level
	_next_preview.queue_redraw()


func show_game_over(final_score: int, best: int) -> void:
	_game_over_score.text = tr("GAMEOVER_SCORE") % final_score
	_game_over_best.text = tr("GAMEOVER_BEST") % best
	_game_over.visible = true


func hide_game_over() -> void:
	_game_over.visible = false


func show_pause(value: bool) -> void:
	_pause.visible = value


func is_debug_visible() -> bool:
	return _debug_label.visible


func toggle_debug() -> void:
	_debug_label.visible = not _debug_label.visible


func set_debug_text(text: String) -> void:
	_debug_label.text = text


func _make_label(text: String, font_size: int, color: Color, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(200, 96)
	var normal := StyleBoxFlat.new()
	normal.bg_color = INK
	normal.set_corner_radius_all(28)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = INK.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	return b


func _make_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0.15, 0.2, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	_root.add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(40)
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 48
	style.content_margin_bottom = 48
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(720, 0)
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 28)
	panel.add_child(box)
	return overlay
