class_name Effects
extends Node2D
## Kısa görsel geri bildirimler: birleşme halkası, puan yazısı ve vinç
## seçiminde alınabilecek binaların çevresindeki halkalar.
## Efektler fiziği etkilemez ve kısa sürede kendini siler.
## reduced_motion açıkken hareketli efektler sadeleşir.

const MAX_ACTIVE := 24

var reduced_motion := false

## Vinç seçimi: vurgulanacak binalar.
var _targets: Array[Building] = []
var _time := 0.0


class Ring:
	extends Node2D
	var radius := 10.0
	var color := Color.WHITE
	var width := 10.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, width, true)


func merge_burst(pos: Vector2, r: float, color: Color) -> void:
	if reduced_motion or get_child_count() >= MAX_ACTIVE:
		return
	var ring := Ring.new()
	ring.position = pos
	ring.radius = r * 0.7
	ring.color = color.lightened(0.2)
	add_child(ring)
	var set_radius := func(v: float) -> void:
		ring.radius = v
		ring.queue_redraw()
	var tw := ring.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(set_radius, r * 0.7, r * 1.35, 0.28)
	tw.tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(ring.queue_free)


func popup(pos: Vector2, text: String, color: Color, font_size: int = 44) -> void:
	if get_child_count() >= MAX_ACTIVE:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#FFFDF8"))
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(420, font_size * 1.4)
	label.position = pos - Vector2(210, font_size * 0.7)
	label.z_index = 5
	add_child(label)
	var tw := label.create_tween().set_parallel(true)
	if not reduced_motion:
		tw.tween_property(label, "position:y", label.position.y - 70.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(label.queue_free)


func _ready() -> void:
	set_process(false)


## Vinç seçimi sırasında alınabilecek binaları vurgular (boş liste: kapat).
func set_pick_targets(list: Array[Building]) -> void:
	_targets = list
	set_process(not list.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 if reduced_motion else 0.6 + 0.4 * sin(_time * 6.0)
	for b in _targets:
		if is_instance_valid(b) and not b.consumed:
			draw_arc(b.position, b.current_radius() + 10.0, 0.0, TAU, 48, Color(1.0, 0.55, 0.1, pulse), 7.0, true)
