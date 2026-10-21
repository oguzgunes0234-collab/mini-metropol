class_name Dropper
extends Node2D
## Alanın üstünde, oyuncunun nişan aldığı yerde bırakılacak binayı ve düşüş
## kılavuz çizgisini gösterir. Fizik gövdesi değildir; yalnızca çizimdir.

var data: GameData
var board: Board
var level := 1
var aim_x := 0.0
var is_ready_to_drop := true

var _dropper_y := 0.0
var _shape_mode := "circle"


func setup(p_data: GameData, p_board: Board) -> void:
	data = p_data
	board = p_board
	_dropper_y = float(data.section("drop").dropper_y)
	_shape_mode = data.section("physics").shape_mode
	aim_x = board.width * 0.5
	z_index = 1


func set_level(p_level: int) -> void:
	level = p_level
	aim_x = board.clamp_x(aim_x, level)
	queue_redraw()


func set_aim(x: float) -> void:
	var clamped := board.clamp_x(x, level)
	if not is_equal_approx(clamped, aim_x):
		aim_x = clamped
		queue_redraw()


func set_ready(value: bool) -> void:
	if value != is_ready_to_drop:
		is_ready_to_drop = value
		queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var r := data.radius(level)
	var guide := Color("#2F4858", 0.16 if is_ready_to_drop else 0.06)
	draw_dashed_line(Vector2(aim_x, _dropper_y + r + 8.0), Vector2(aim_x, board.height), guide, 3.0, 14.0, true, true)
	draw_set_transform(Vector2(aim_x, _dropper_y))
	BuildingArt.draw_building(self, data.level_def(level), r, _shape_mode, 1.0 if is_ready_to_drop else 0.4)
	draw_set_transform(Vector2.ZERO)
