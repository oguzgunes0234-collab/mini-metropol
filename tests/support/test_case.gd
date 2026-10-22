class_name TestCase
extends RefCounted
## Küçük test altyapısı: her test dosyası bu sınıftan türetilir ve "test_"
## ile başlayan metotları çalıştırılır. Dış bağımlılık yoktur.

var tree: SceneTree
var failures: PackedStringArray = []
var _nodes: Array[Node] = []


func reset_case() -> void:
	failures = PackedStringArray()


func before_each() -> void:
	pass


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await tree.process_frame
	await tree.physics_frame


## Sahne ağacına bir düğüm ekler; test bitince otomatik silinir.
func add_node(n: Node) -> Node:
	tree.root.add_child(n)
	_nodes.append(n)
	return n


## Testlerde süreler 60 Hz kare cinsinden yazılır (60 = 1 saniye). Fizik
## adım sıklığı farklıysa (project.godot) gerçek adım sayısına çevrilir.
func steps(frames_at_60: int) -> int:
	return ceili(frames_at_60 * Engine.physics_ticks_per_second / 60.0)


func physics_frames(count: int) -> void:
	for i in steps(count):
		await tree.physics_frame


## Fizik adımlarını ilerletir ve her adımda tutarlılık denetimi yapar.
func run_checked(session: GameSession, inv: Invariants, count: int) -> void:
	for i in steps(count):
		await tree.physics_frame
		inv.check(session)


## Bırakma bekleme süresi dolana kadar bekler.
func wait_cooldown(session: GameSession) -> void:
	while not session.can_drop() and session.state == GameSession.State.PLAYING:
		await tree.physics_frame


## Oyun oturumu ve alanı oluşturur (arayüz olmadan).
func make_session(data: GameData = null, seed_value: int = 1) -> GameSession:
	if data == null:
		data = GameData.load_default()
	var world := Node2D.new()
	world.name = "TestWorld"
	add_node(world)
	var board := Board.new()
	board.name = "Board"
	world.add_child(board)
	board.setup(data)
	var session := GameSession.new()
	session.name = "Session"
	world.add_child(session)
	session.setup(data, board)
	session.record_events = true
	session.start(seed_value)
	return session


## Testler için küçük bir bölüm tanımı; overrides ile alanları değiştirilir.
func level_dict(overrides: Dictionary = {}) -> Dictionary:
	var d := {
		"id": "T-01", "name_key": "LEVEL_1_01", "hint_key": "HINT_1_01",
		"region": "test", "difficulty": 1, "mechanic": "test",
		"seed": 1, "moves": 10,
		"goals": [{"type": "build", "level": 2, "count": 1}],
		"stars": [{"type": "complete"}, {"type": "moves_used_max", "value": 5}, {"type": "score", "value": 10}],
		"rewards": {"coins_first": 0, "coins_repeat": 0},
	}
	d.merge(overrides, true)
	return d


## Bölüm kipinde oturum. level: bölüm kimliği (data/levels.json) veya level_dict() sözlüğü.
func make_level_session(level: Variant) -> GameSession:
	var s := make_session()
	var cat: LevelCatalog
	var lv: Dictionary
	if level is String:
		cat = LevelCatalog.load_default()
		lv = cat.get_level(level)
	else:
		cat = LevelCatalog.from_dict({"levels": [level]}, GameData.load_default())
		if not cat.is_valid():
			fail("test bölümü geçersiz: %s" % "\n".join(cat.errors))
			return s
		lv = cat.levels[0]
	s.start_level(lv, cat.data_for(lv))
	return s


## Varsayılan veri dosyalarının derin kopyası (testte değiştirmek için).
func default_dicts() -> Dictionary:
	return {
		"buildings": JSON.parse_string(FileAccess.get_file_as_string(GameData.BUILDINGS_PATH)),
		"rules": JSON.parse_string(FileAccess.get_file_as_string(GameData.RULES_PATH)),
	}


# --- Doğrulamalar ---

func fail(msg: String) -> void:
	failures.append(msg)


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		fail("beklenen: doğru. %s" % msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		fail("beklenen: yanlış. %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		fail("tür farklı: %s (%s) != %s (%s). %s" % [actual, type_string(typeof(actual)), expected, type_string(typeof(expected)), msg])
	elif actual != expected:
		fail("%s != %s (beklenen). %s" % [actual, expected, msg])


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if actual == unexpected:
		fail("%s olmamalıydı. %s" % [unexpected, msg])


func assert_near(actual: float, expected: float, eps: float, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		fail("%f, %f değerine yeterince yakın değil (±%f). %s" % [actual, expected, eps, msg])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	if actual < lo or actual > hi:
		fail("%f, [%f, %f] aralığında değil. %s" % [actual, lo, hi, msg])


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
