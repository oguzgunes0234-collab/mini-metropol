class_name Building
extends RigidBody2D
## Oyun alanındaki tek bir bina: seviye, fizik gövdesi ve çizim.
## Birleşme kararlarını bina vermez; Board tek merkezden yönetir.

const LAYER_BUILDINGS := 1
const LAYER_WALLS := 2

## Board içinde benzersiz kimlik. Birleşme sırası bu numaraya göre belirlenir.
var uid := 0
var level := 1
## Tam boyuttaki yarıçap (birleşme büyüme animasyonu sırasında fizik şekli daha küçüktür).
var radius := 0.0
var shape_mode := "circle"
## "drop" (oyuncu bıraktı), "merge" (birleşmeyle oluştu), "restore" (anlık görüntüden).
var origin := "drop"
## Board saatine göre oluşma anı (saniye).
var born_time := 0.0
## Birleşmede kullanıldı ve kaldırılıyor: artık hiçbir işleme katılmaz.
var consumed := false
## Büyüme oranı (0..1). 1 = tam boyut.
var grow := 1.0

var _def: Dictionary
var _shape: Shape2D
var _max_speed := 0.0
var _max_up_speed := 0.0
var _grow_from := 1.0
var _grow_elapsed := 0.0
var _grow_duration := 0.0


func setup(p_uid: int, def: Dictionary, data: GameData, material: PhysicsMaterial, p_origin: String, p_born_time: float, grow_from: float = 1.0) -> void:
	uid = p_uid
	_def = def
	level = def.level
	radius = def.radius
	origin = p_origin
	born_time = p_born_time
	name = "Building_%d" % uid

	var physics := data.section("physics")
	shape_mode = physics.shape_mode
	_max_speed = float(physics.max_speed)
	_max_up_speed = float(physics.max_up_speed)
	mass = def.mass
	gravity_scale = float(physics.gravity_scale)
	linear_damp = float(physics.linear_damp)
	angular_damp = float(physics.angular_damp)
	physics_material_override = material
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	can_sleep = true
	collision_layer = LAYER_BUILDINGS
	collision_mask = LAYER_BUILDINGS | LAYER_WALLS

	var collision := CollisionShape2D.new()
	if shape_mode == "rounded_box":
		_shape = ConvexPolygonShape2D.new()
	else:
		_shape = CircleShape2D.new()
	collision.shape = _shape
	add_child(collision)

	var merge := data.section("merge")
	_grow_duration = float(merge.grow_duration_sec)
	_grow_from = clampf(grow_from, 0.05, 1.0)
	_grow_elapsed = 0.0
	_apply_scale(_grow_from)
	set_physics_process(_grow_from < 1.0)


func definition() -> Dictionary:
	return _def


func current_radius() -> float:
	return radius * grow


## Binanın en üst noktasının (Board yerel koordinatında) y değeri.
func top_y() -> float:
	if shape_mode == "rounded_box":
		var min_y := INF
		var xf := Transform2D(rotation, position)
		for p in (_shape as ConvexPolygonShape2D).points:
			min_y = minf(min_y, (xf * p).y)
		return min_y
	return position.y - current_radius()


func _physics_process(delta: float) -> void:
	if grow >= 1.0:
		set_physics_process(false)
		return
	_grow_elapsed += delta
	var t := 1.0 if _grow_duration <= 0.0 else clampf(_grow_elapsed / _grow_duration, 0.0, 1.0)
	_apply_scale(lerpf(_grow_from, 1.0, ease(t, 0.4)))


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Aşırı hızlanmayı (fırlama, alan dışına kaçma) engelle. Yukarı doğru
	# hız ayrıca sınırlanır: binalar havaya fırlamaz.
	var v := state.linear_velocity
	var changed := false
	if v.length_squared() > _max_speed * _max_speed:
		v = v.normalized() * _max_speed
		changed = true
	if v.y < -_max_up_speed:
		v.y = -_max_up_speed
		changed = true
	if changed:
		state.linear_velocity = v


func _apply_scale(s: float) -> void:
	grow = 1.0 if s >= 0.999 else s
	if _shape is CircleShape2D:
		(_shape as CircleShape2D).radius = radius * grow
	else:
		(_shape as ConvexPolygonShape2D).points = BuildingArt.rounded_box_points(radius * grow)
	queue_redraw()


func _draw() -> void:
	BuildingArt.draw_building(self, _def, current_radius(), shape_mode)
