class_name Board
extends Node2D
## Oyun alanı: duvarlar, binalar, birleşmeler, alan sınırları ve tehlike çizgisi.
##
## Birleşme akışı (çift bina / çift puan / sonsuz döngü olmaması için):
## 1. Her fizik karesinde temas eden aynı seviye çiftleri toplanır (iki yönden).
## 2. MergeResolver her binanın en fazla bir birleşmeye girdiği işlemleri seçer.
## 3. Eski iki gövde hemen sahneden çıkarılır, yeni bina küçük başlayıp büyür.
## Koordinatlar Board'a göredir: (0,0) alanın sol üst köşesi, y aşağı doğru artar.

signal merged(info: Dictionary)
signal danger_changed(ratio: float)
signal game_over_triggered(reason: String)

## Bırakma noktasının durumu (bkz. room_at).
enum Room { FREE, BLOCKED_TEMP, FULL }

## Bırakma noktasını engelleyen bina bu hızdan yavaşsa "yerleşmiş" sayılır.
const SETTLED_SPEED := 160.0
## Duvara/zemine yarıçapın bu oranından fazla gömülen bina geri itilir.
const RESCUE_DEPTH := 0.3

## Yalnızca fizik deneyleri için (tools/simulate.gd --no_rescue).
static var rescue_enabled := true

var data: GameData
var width := 0.0
var height := 0.0
## Canlı binalar, oluşma (uid) sırasıyla.
var buildings: Array[Building] = []
## Board saati: yalnızca fizik adımlarıyla ilerler.
var sim_time := 0.0
var danger_time := 0.0
var danger_ratio := 0.0
var is_game_over := false
## "danger" (tehlike çizgisi süresi doldu) veya "no_room" (bırakma noktası dolu).
var game_over_reason := ""
## Bölümün sabit engelleri (bkz. LevelCatalog).
var obstacles: Array = []
## false iken birleşme ve tehlike kontrolü yapılmaz (oyun sonu).
var active := true
var stats := {}

var _by_uid := {}
var _next_uid := 1
var _material: PhysicsMaterial
var _container: Node2D
var _walls: StaticBody2D
var _final_rule := "landmark"
var _danger_line_y := 0.0
var _danger_limit := 1.0
var _drop_grace := 0.0
var _dropper_y := 0.0
var _grow_start := 1.0
var _inherit_velocity := 0.0
var _wall_thickness := 0.0
var _wall_extra := 0.0
var _panel_style: StyleBoxFlat


## Alanı verilen veriye (ve bölümün engellerine) göre kurar. Tekrar
## çağrılabilir: her bölüm başında alan boyutu, duvarlar ve engeller yeniden kurulur.
func setup(p_data: GameData, p_obstacles: Array = []) -> void:
	if _container == null:
		_container = Node2D.new()
		_container.name = "Buildings"
		add_child(_container)
		_panel_style = StyleBoxFlat.new()
		_panel_style.bg_color = Color("#FFFDF8")
		_panel_style.set_corner_radius_all(36)
		_panel_style.shadow_color = Color(0.18, 0.28, 0.35, 0.12)
		_panel_style.shadow_size = 18
		_panel_style.shadow_offset = Vector2(0, 8)
	reset()
	data = p_data
	obstacles = p_obstacles.duplicate(true)
	var b := data.section("board")
	width = float(b.width)
	height = float(b.height)
	_wall_thickness = float(b.wall_thickness)
	_wall_extra = float(b.wall_extra_height)
	_final_rule = data.section("final_level").rule
	var go := data.section("game_over")
	_danger_line_y = float(go.danger_line_y)
	_danger_limit = float(go.danger_time_sec)
	_drop_grace = float(go.drop_grace_sec)
	_dropper_y = float(data.section("drop").dropper_y)
	var m := data.section("merge")
	_grow_start = float(m.grow_start_scale)
	_inherit_velocity = float(m.inherit_velocity)

	var physics := data.section("physics")
	_material = PhysicsMaterial.new()
	_material.friction = float(physics.friction)
	_material.bounce = float(physics.bounce)

	_build_walls()
	_reset_stats()
	queue_redraw()


## Bölümün başlangıç düzenindeki binayı yerleştirir.
func place(level: int, pos: Vector2) -> Building:
	var b := spawn(level, pos, Vector2.ZERO, "layout")
	stats.placed_value += GameData.value_of(level)
	return b


## Bölüm kazanıldığında: birleşme ve tehlike kontrolü durur, oyun sonu bildirilmez.
func halt() -> void:
	active = false


## Tüm binalar neredeyse durdu mu? (Son hamleden sonra zincirlerin bitmesini beklemek için.)
func is_settled(speed: float = 25.0) -> bool:
	for b in buildings:
		if b.grow < 1.0 or b.linear_velocity.length_squared() > speed * speed:
			return false
	return true


## Oyuncunun bıraktığı binayı oluşturur. x alan sınırlarına sıkıştırılır.
func drop(level: int, x: float) -> Building:
	var pos := Vector2(clamp_x(x, level), _dropper_y)
	var b := spawn(level, pos, Vector2.ZERO, "drop")
	stats.dropped += 1
	stats.dropped_value += GameData.value_of(level)
	return b


## Bırakma noktasında yeni bina için yer var mı?
## FREE: yer var. BLOCKED_TEMP: yalnızca hâlâ hareket eden/yeni düşen bir bina
## engelliyor, biraz sonra tekrar denenebilir. FULL: yerleşmiş binalar
## bırakma noktasına kadar yükselmiş; arsa dolmuştur.
## (Yeni bina başka bir binanın içinde doğarsa fizik motoru onu şiddetle
## iter; bu kontrol bunu engeller.)
func room_at(level: int, x: float) -> Room:
	var pos := Vector2(clamp_x(x, level), _dropper_y)
	var r := data.radius(level)
	var result := Room.FREE
	for b in buildings:
		if b.position.distance_to(pos) >= r + b.current_radius():
			continue
		var young := b.origin == "drop" and sim_time - b.born_time < _drop_grace
		if young or b.linear_velocity.length() > SETTLED_SPEED:
			result = Room.BLOCKED_TEMP
		else:
			return Room.FULL
	return result


## Oyunu bitirir (bir kez). Tehlike süresi dolunca ya da arsa dolunca çağrılır.
func end_game(reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	active = false
	game_over_reason = reason
	game_over_triggered.emit(reason)


## Bırakma noktasını binanın duvarlara girmeyeceği aralığa sıkıştırır.
func clamp_x(x: float, level: int) -> float:
	var r := data.radius(level)
	return clampf(x, r, width - r)


func spawn(level: int, pos: Vector2, velocity: Vector2, origin: String, grow_from: float = 1.0, rot: float = 0.0) -> Building:
	var b := Building.new()
	b.setup(_next_uid, data.level_def(level), data, _material, origin, sim_time, grow_from)
	_next_uid += 1
	b.position = pos
	b.rotation = rot
	b.linear_velocity = velocity
	_container.add_child(b)
	buildings.append(b)
	_by_uid[b.uid] = b
	return b


## Alanı tamamen temizler. Bir önceki oyundan hiçbir gövde kalmaz.
func reset() -> void:
	for b in buildings:
		b.consumed = true
		_container.remove_child(b)
		b.queue_free()
	buildings.clear()
	_by_uid.clear()
	sim_time = 0.0
	danger_time = 0.0
	is_game_over = false
	game_over_reason = ""
	active = true
	_reset_stats()
	_set_danger_ratio(0.0)


func building_count() -> int:
	return buildings.size()


## Alandaki binaların toplam "değeri" (bkz. GameData.value_of).
func total_value() -> int:
	var total := 0
	for b in buildings:
		total += GameData.value_of(b.level)
	return total


func highest_level() -> int:
	var best := 0
	for b in buildings:
		best = maxi(best, b.level)
	return best


func _physics_process(delta: float) -> void:
	sim_time += delta
	for b in buildings:
		b.keep_upright()
	# Sınır güvenliği oyun bittikten sonra da çalışır (sonuç ekranının arkasında
	# binalar alandan düşmesin).
	_rescue_deep_penetrations()
	_enforce_bounds()
	if not active:
		return
	_resolve_merges()
	_update_danger(delta)


func _resolve_merges() -> void:
	var candidates: Array = []
	for b in buildings:
		if b.consumed:
			continue
		for o in b.get_colliding_bodies():
			if not is_instance_valid(o) or not (o is Building):
				continue
			var other := o as Building
			if other.consumed or other == b or other.level != b.level:
				continue
			candidates.append({"a": b.uid, "b": other.uid, "level": b.level})
	if candidates.is_empty():
		return
	for op in MergeResolver.resolve(candidates, data.max_level, _final_rule):
		_execute(op)


func _execute(op: Dictionary) -> void:
	var a: Building = _by_uid.get(op.a)
	var b: Building = _by_uid.get(op.b)
	if a == null or b == null:
		push_error("Birleşme için bina bulunamadı: %s" % op)
		return
	var pos := (a.position + b.position) * 0.5
	var vel := (a.linear_velocity + b.linear_velocity) * 0.5 * _inherit_velocity
	_remove(a)
	_remove(b)
	if op.kind == MergeResolver.Kind.UPGRADE:
		var new_level: int = op.level + 1
		var r := data.radius(new_level)
		pos.x = clampf(pos.x, r, width - r)
		pos.y = minf(pos.y, height - r)
		var n := spawn(new_level, pos, vel, "merge", _grow_start)
		stats.merges += 1
		merged.emit({"kind": op.kind, "level": new_level, "position": pos, "a": op.a, "b": op.b, "uid": n.uid})
	else:
		stats.landmarks += 1
		stats.landmark_value += 2 * GameData.value_of(op.level)
		merged.emit({"kind": op.kind, "level": op.level, "position": pos, "a": op.a, "b": op.b, "uid": 0})


func _remove(b: Building) -> void:
	b.consumed = true
	buildings.erase(b)
	_by_uid.erase(b.uid)
	_container.remove_child(b)
	b.queue_free()


## Kurtarma: ağır bir yığının altında ezilen bina duvara/zemine yarıçapının
## RESCUE_DEPTH katından fazla gömülürse alana geri itilir ve duvara doğru
## hızı sıfırlanır. Godot'nun 2D fizik çözücüsü büyük kütle farkı olan
## yığınlarda bunu nadiren yaşatıyor (bkz. docs/DECISIONS.md, karar 16);
## bu düzeltme binanın kaybolmasını önler.
func _rescue_deep_penetrations() -> void:
	if not rescue_enabled:
		return
	for b in buildings:
		var r := b.current_radius()
		var limit := r * (1.0 - RESCUE_DEPTH)
		var p := b.position
		var v := b.linear_velocity
		var fixed := false
		if p.x < limit:
			p.x = r
			v.x = maxf(v.x, 0.0)
			fixed = true
		elif p.x > width - limit:
			p.x = width - r
			v.x = minf(v.x, 0.0)
			fixed = true
		if p.y > height - limit:
			p.y = height - r
			v.y = minf(v.y, 0.0)
			fixed = true
		if fixed:
			stats.rescues += 1
			b.position = p
			b.linear_velocity = v


## Son güvenlik ağı: alan dışına çıkan bina olursa kaydedilir ve kaldırılır.
## Normal oyunda hiç tetiklenmemeli; testler bu sayacın 0 kaldığını doğrular.
func _enforce_bounds() -> void:
	var escaped: Array[Building] = []
	for b in buildings:
		var p := b.position
		if p.x < 0.0 or p.x > width or p.y > height or p.y < -_wall_extra:
			escaped.append(b)
	for b in escaped:
		stats.out_of_bounds += 1
		push_warning("Bina alan dışına çıktı ve kaldırıldı: seviye %d, konum %s" % [b.level, b.position])
		stats.lost_value += GameData.value_of(b.level)
		_remove(b)


func _update_danger(delta: float) -> void:
	var over := false
	for b in buildings:
		if b.origin == "drop" and sim_time - b.born_time < _drop_grace:
			continue
		if b.top_y() < _danger_line_y:
			over = true
			break
	if over:
		danger_time += delta
	else:
		danger_time = maxf(0.0, danger_time - delta * 2.0)
	_set_danger_ratio(clampf(danger_time / _danger_limit, 0.0, 1.0))
	if danger_time >= _danger_limit:
		end_game("danger")


func _set_danger_ratio(r: float) -> void:
	if absf(r - danger_ratio) < 0.001:
		return
	danger_ratio = r
	danger_changed.emit(r)
	queue_redraw()


## Alanın tam durumunu kaydeder (geri al ve testler için).
func capture_state() -> Dictionary:
	var list: Array = []
	for b in buildings:
		list.append({
			"level": b.level,
			"x": b.position.x, "y": b.position.y, "rot": b.rotation,
			"vx": b.linear_velocity.x, "vy": b.linear_velocity.y, "av": b.angular_velocity,
			"origin": b.origin, "age": sim_time - b.born_time, "grow": b.grow,
		})
	return {
		"buildings": list,
		"danger_time": danger_time,
		"is_game_over": is_game_over,
		"game_over_reason": game_over_reason,
		"stats": stats.duplicate(),
	}


func restore_state(s: Dictionary) -> void:
	reset()
	for e in s.buildings:
		var b := spawn(int(e.level), Vector2(e.x, e.y), Vector2(e.vx, e.vy), String(e.origin), float(e.grow), float(e.rot))
		b.angular_velocity = float(e.av)
		b.born_time = sim_time - float(e.age)
	danger_time = float(s.danger_time)
	is_game_over = bool(s.is_game_over)
	game_over_reason = String(s.get("game_over_reason", ""))
	active = not is_game_over
	_reset_stats()
	for key in s.stats:
		stats[key] = s.stats[key]
	_set_danger_ratio(clampf(danger_time / _danger_limit, 0.0, 1.0))


func _reset_stats() -> void:
	stats = {
		"dropped": 0,
		"dropped_value": 0,
		"placed_value": 0,
		"merges": 0,
		"landmarks": 0,
		"landmark_value": 0,
		"out_of_bounds": 0,
		"lost_value": 0,
		"rescues": 0,
	}


func _build_walls() -> void:
	if _walls != null:
		remove_child(_walls)
		_walls.queue_free()
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = Building.LAYER_WALLS
	_walls.collision_mask = 0
	var wall_material := PhysicsMaterial.new()
	wall_material.friction = 0.6
	wall_material.bounce = 0.0
	_walls.physics_material_override = wall_material
	var t := _wall_thickness
	var top := -_wall_extra
	var wall_h := height + t - top
	_add_wall_rect(Vector2(-t * 0.5, top + wall_h * 0.5), Vector2(t, wall_h))
	_add_wall_rect(Vector2(width + t * 0.5, top + wall_h * 0.5), Vector2(t, wall_h))
	_add_wall_rect(Vector2(width * 0.5, height + t * 0.5), Vector2(width + t * 2.0, t))
	# Görünmez güvenlik tavanı: bırakma noktasının çok üstünde; normal oyunda
	# hiçbir bina buraya ulaşmaz, yalnızca alandan kaçmayı imkânsız kılar.
	_add_wall_rect(Vector2(width * 0.5, top - t * 0.5), Vector2(width + t * 2.0, t))
	# Bölüm engelleri de duvarlarla aynı statik gövdede (aynı katman ve malzeme).
	for ob in obstacles:
		if ob.shape == "circle":
			var circle := CircleShape2D.new()
			circle.radius = ob.r
			var col := CollisionShape2D.new()
			col.shape = circle
			col.position = Vector2(ob.x, ob.y)
			_walls.add_child(col)
		else:
			_add_wall_rect(Vector2(ob.x, ob.y), Vector2(ob.w, ob.h), deg_to_rad(ob.rot))
	add_child(_walls)


func _add_wall_rect(center: Vector2, size: Vector2, rot: float = 0.0) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = center
	col.rotation = rot
	_walls.add_child(col)


func _draw() -> void:
	if data == null:
		return
	# Arsa paneli
	_panel_style.draw(get_canvas_item(), Rect2(-18, -24, width + 36, height + 42))
	# Zemin şeridi
	draw_rect(Rect2(0, height - 6, width, 24), Color("#8FB996"))
	# İç kenarlar
	var edge := Color("#2F4858", 0.18)
	draw_line(Vector2(0, -24), Vector2(0, height), edge, 4.0, true)
	draw_line(Vector2(width, -24), Vector2(width, height), edge, 4.0, true)
	# Engeller (GEÇİCİ ÇİZİM): yuvarlak = kaya, dikdörtgen = şantiye bariyeri.
	for ob in obstacles:
		if ob.shape == "circle":
			draw_circle(Vector2(ob.x, ob.y + 6), ob.r, Color(0.11, 0.16, 0.2, 0.18), true, -1.0, true)
			draw_circle(Vector2(ob.x, ob.y), ob.r, Color("#8E9AA6"), true, -1.0, true)
			draw_circle(Vector2(ob.x - ob.r * 0.25, ob.y - ob.r * 0.25), ob.r * 0.45, Color("#B3BDC6"), true, -1.0, true)
		else:
			draw_set_transform(Vector2(ob.x, ob.y), deg_to_rad(ob.rot))
			var rect := Rect2(-ob.w * 0.5, -ob.h * 0.5, ob.w, ob.h)
			draw_rect(rect, Color("#F6AE2D"))
			var stripe := 28.0
			var n := int(ob.w / stripe)
			for i in range(0, n, 2):
				draw_rect(Rect2(rect.position.x + i * stripe, rect.position.y, stripe, ob.h), Color("#2F4858"))
			draw_set_transform(Vector2.ZERO)
	# Tehlike çizgisi: tehlike arttıkça kırmızılaşır ve kalınlaşır.
	var calm := Color("#2F4858", 0.28)
	var alarm := Color("#E4572E", 1.0)
	var col := calm.lerp(alarm, danger_ratio)
	draw_dashed_line(Vector2(0, _danger_line_y), Vector2(width, _danger_line_y), col, 4.0 + 4.0 * danger_ratio, 22.0, true, true)
