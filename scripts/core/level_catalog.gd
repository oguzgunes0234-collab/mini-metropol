class_name LevelCatalog
extends RefCounted
## Bölüm listesini (data/levels.json) yükler ve doğrular. Her bölüm genel
## kuralların (rules.json) bir kısmını kendi değerleriyle geçersiz kılabilir;
## bölümün kullanacağı GameData bu birleşimden üretilir.
##
## Bir bölümün alanları (zorunlu olmayanlar köşeli parantezde):
##   id, name_key, hint_key, region, difficulty (1-5), mechanic,
##   [unlock.after], seed, moves, goals[], stars[3], rewards,
##   [spawn_sequence], [rules], [layout], [obstacles]

const LEVELS_PATH := "res://data/levels.json"
## Başlangıç binaları ve engeller tehlike çizgisine bu kadar yaklaşamaz.
const LAYOUT_TOP_MARGIN := 60.0
## Engellerin üstü en az bu derinlikte olmalı (bırakma alanı açık kalsın).
const OBSTACLE_MIN_TOP := 320.0
const OBSTACLE_SHAPES: Array[String] = ["circle", "rect"]

static var _default: LevelCatalog

var base: GameData
var levels: Array[Dictionary] = []
var errors: PackedStringArray = []
var _index := {}
var _data := {}


static func load_default() -> LevelCatalog:
	if _default == null:
		_default = load_from_file(LEVELS_PATH, GameData.load_default())
	return _default


static func load_from_file(path: String, p_base: GameData) -> LevelCatalog:
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var parsed = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		var c := LevelCatalog.new()
		c.base = p_base
		c.errors.append("%s okunamadı veya geçerli bir JSON nesnesi değil" % path)
		return c
	return from_dict(parsed, p_base)


static func from_dict(d: Dictionary, p_base: GameData) -> LevelCatalog:
	var c := LevelCatalog.new()
	c.base = p_base
	if not p_base.is_valid():
		c.errors.append("Temel oyun verisi geçersiz")
		return c
	var list = d.get("levels")
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		c.errors.append("levels: boş olmayan bir liste olmalı")
		return c
	for i in list.size():
		c._add_level(i, list[i])
	return c


func is_valid() -> bool:
	return errors.is_empty()


func count() -> int:
	return levels.size()


func get_level(id: String) -> Dictionary:
	return levels[_index[id]] if _index.has(id) else {}


func index_of(id: String) -> int:
	return _index.get(id, -1)


## Listede bir sonraki bölümün kimliği; son bölümse "".
func next_id(id: String) -> String:
	var i := index_of(id)
	return levels[i + 1].id if i >= 0 and i + 1 < levels.size() else ""


## Bölümün kullanacağı oyun verisi (genel kurallar + bölümün geçersiz kıldıkları).
func data_for(level: Dictionary) -> GameData:
	return _data[level.id]


func _add_level(i: int, raw: Variant) -> void:
	var where := "levels[%d]" % i
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s bir nesne olmalı" % where)
		return
	var e := errors.size()
	var id := _str(raw, "id", where)
	if id != "":
		where = "bölüm %s" % id
		if _index.has(id):
			errors.append("%s: kimlik tekrar kullanılmış" % where)
	var lv := {
		"id": id,
		"name_key": _str(raw, "name_key", where),
		"hint_key": _str(raw, "hint_key", where),
		"region": _str(raw, "region", where),
		"mechanic": _str(raw, "mechanic", where),
		"difficulty": _int(raw, "difficulty", where, 1, 5),
		"seed": _int(raw, "seed", where, 0, 2147483647),
		"moves": _int(raw, "moves", where, 1, 999),
		"unlock_after": "",
		"goals": [],
		"stars": [],
		"rewards": {},
		"spawn_sequence": [],
		"rules": {},
		"layout": [],
		"obstacles": [],
	}
	if errors.size() > e:
		return

	var unlock = raw.get("unlock", {})
	if typeof(unlock) == TYPE_DICTIONARY and unlock.get("after") != null:
		lv.unlock_after = String(unlock.after)
		if not _index.has(lv.unlock_after):
			errors.append("%s: unlock.after '%s' daha önce tanımlanmış bir bölüm olmalı" % [where, lv.unlock_after])

	# Bölüme özel kurallar
	var merged := base.rules.duplicate(true)
	var override = raw.get("rules", {})
	if typeof(override) != TYPE_DICTIONARY:
		errors.append("%s: rules bir nesne olmalı" % where)
		return
	for section in override:
		if not merged.has(section) or typeof(override[section]) != TYPE_DICTIONARY:
			errors.append("%s: rules.%s bilinmeyen bölüm" % [where, section])
			continue
		for key in override[section]:
			if not merged[section].has(key):
				errors.append("%s: rules.%s.%s bilinmeyen alan" % [where, section, key])
				continue
			merged[section][key] = override[section][key]
	if errors.size() > e:
		return
	var data := GameData.from_dicts(base.source_buildings, merged)
	if not data.is_valid():
		for err in data.errors:
			errors.append("%s: %s" % [where, err])
		return
	lv.rules = override

	_parse_goals(raw, lv, data, where)
	_parse_stars(raw, lv, where)
	_parse_rewards(raw, lv, where)
	_parse_sequence(raw, lv, data, where)
	_parse_layout(raw, lv, data, where)
	_parse_obstacles(raw, lv, data, where)
	if errors.size() > e:
		return
	_index[id] = levels.size()
	levels.append(lv)
	_data[id] = data


func _parse_goals(raw: Dictionary, lv: Dictionary, data: GameData, where: String) -> void:
	var list = raw.get("goals")
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		errors.append("%s: goals boş olmayan bir liste olmalı" % where)
		return
	for j in list.size():
		var g = list[j]
		var w := "%s goals[%d]" % [where, j]
		if typeof(g) != TYPE_DICTIONARY or not LevelGoals.GOAL_TYPES.has(g.get("type")):
			errors.append("%s: type şunlardan biri olmalı: %s" % [w, ", ".join(LevelGoals.GOAL_TYPES)])
			continue
		match String(g.type):
			"build":
				lv.goals.append({"type": "build", "level": _int(g, "level", w, 2, data.max_level), "count": _int(g, "count", w, 1, 99)})
			"landmark":
				if data.section("final_level").rule != "landmark":
					errors.append("%s: landmark hedefi için final_level.rule 'landmark' olmalı" % w)
				lv.goals.append({"type": "landmark", "count": _int(g, "count", w, 1, 99)})
			"score":
				lv.goals.append({"type": "score", "value": _int(g, "value", w, 1, 10000000)})
			"chain":
				lv.goals.append({"type": "chain", "value": _int(g, "value", w, 2, 20)})


func _parse_stars(raw: Dictionary, lv: Dictionary, where: String) -> void:
	var list = raw.get("stars")
	if typeof(list) != TYPE_ARRAY or list.size() != 3:
		errors.append("%s: stars tam 3 ölçüt içermeli" % where)
		return
	for j in 3:
		var s = list[j]
		var w := "%s stars[%d]" % [where, j]
		if typeof(s) != TYPE_DICTIONARY or not LevelGoals.STAR_TYPES.has(s.get("type")):
			errors.append("%s: type şunlardan biri olmalı: %s" % [w, ", ".join(LevelGoals.STAR_TYPES)])
			continue
		if (j == 0) != (s.type == "complete"):
			errors.append("%s: ilk yıldız (yalnızca o) 'complete' olmalı" % w)
			continue
		if s.type == "complete":
			lv.stars.append({"type": "complete"})
		else:
			var hi := int(lv.moves) if s.type == "moves_used_max" else 10000000
			lv.stars.append({"type": String(s.type), "value": _int(s, "value", w, 1, hi)})


func _parse_rewards(raw: Dictionary, lv: Dictionary, where: String) -> void:
	var r = raw.get("rewards")
	if typeof(r) != TYPE_DICTIONARY:
		errors.append("%s: rewards nesnesi eksik" % where)
		return
	lv.rewards = {
		"coins_first": _int(r, "coins_first", where + " rewards", 0, 100000),
		"coins_repeat": _int(r, "coins_repeat", where + " rewards", 0, 100000),
	}


func _parse_sequence(raw: Dictionary, lv: Dictionary, data: GameData, where: String) -> void:
	var seq = raw.get("spawn_sequence", [])
	if typeof(seq) != TYPE_ARRAY:
		errors.append("%s: spawn_sequence bir liste olmalı" % where)
		return
	for j in seq.size():
		if not GameData._is_number(seq[j]) or int(seq[j]) < 1 or int(seq[j]) >= data.max_level:
			errors.append("%s: spawn_sequence[%d] 1 ile %d arasında olmalı" % [where, j, data.max_level - 1])
		else:
			lv.spawn_sequence.append(int(seq[j]))


func _parse_layout(raw: Dictionary, lv: Dictionary, data: GameData, where: String) -> void:
	var list = raw.get("layout", [])
	if typeof(list) != TYPE_ARRAY:
		errors.append("%s: layout bir liste olmalı" % where)
		return
	var b := data.section("board")
	var w := float(b.width)
	var h := float(b.height)
	var line := float(data.section("game_over").danger_line_y)
	for j in list.size():
		var it = list[j]
		var wj := "%s layout[%d]" % [where, j]
		if typeof(it) != TYPE_DICTIONARY:
			errors.append("%s bir nesne olmalı" % wj)
			continue
		var ec := errors.size()
		var level := _int(it, "level", wj, 1, data.max_level)
		var x := _num(it, "x", wj)
		var y := _num(it, "y", wj)
		if errors.size() > ec:
			continue
		var r := data.radius(level)
		if x < r or x > w - r or y > h - r + 0.5 or y - r < line + LAYOUT_TOP_MARGIN:
			errors.append("%s: bina alanın içinde ve tehlike çizgisinin altında olmalı" % wj)
		for other in lv.layout:
			var d := Vector2(x, y).distance_to(Vector2(other.x, other.y))
			var ro := data.radius(other.level)
			if d < r + ro - 1.0:
				errors.append("%s: başka bir başlangıç binasıyla üst üste" % wj)
			elif other.level == level and d < r + ro + 4.0:
				errors.append("%s: aynı seviyedeki komşusuna değiyor (hemen birleşirdi)" % wj)
		lv.layout.append({"level": level, "x": x, "y": y})


func _parse_obstacles(raw: Dictionary, lv: Dictionary, data: GameData, where: String) -> void:
	var list = raw.get("obstacles", [])
	if typeof(list) != TYPE_ARRAY:
		errors.append("%s: obstacles bir liste olmalı" % where)
		return
	var b := data.section("board")
	var w := float(b.width)
	var h := float(b.height)
	for j in list.size():
		var it = list[j]
		var wj := "%s obstacles[%d]" % [where, j]
		if typeof(it) != TYPE_DICTIONARY or not OBSTACLE_SHAPES.has(it.get("shape")):
			errors.append("%s: shape şunlardan biri olmalı: %s" % [wj, ", ".join(OBSTACLE_SHAPES)])
			continue
		var ob := {"shape": String(it.shape), "kind": String(it.get("kind", "rock")), "x": _num(it, "x", wj), "y": _num(it, "y", wj)}
		var extent := 0.0
		if ob.shape == "circle":
			ob.r = _num(it, "r", wj)
			extent = ob.r
		else:
			ob.w = _num(it, "w", wj)
			ob.h = _num(it, "h", wj)
			ob.rot = float(it.get("rot", 0.0))
			extent = Vector2(ob.w, ob.h).length() * 0.5
		if extent <= 0.0:
			errors.append("%s: boyut pozitif olmalı" % wj)
			continue
		if ob.x < 0.0 or ob.x > w or ob.y > h or ob.y - extent < OBSTACLE_MIN_TOP:
			errors.append("%s: engel alanın içinde olmalı ve üstü en az %d derinlikte başlamalı" % [wj, OBSTACLE_MIN_TOP])
		for other in lv.layout:
			if Vector2(ob.x, ob.y).distance_to(Vector2(other.x, other.y)) < extent + data.radius(other.level):
				errors.append("%s: bir başlangıç binasıyla üst üste" % wj)
		lv.obstacles.append(ob)


# --- Okuma yardımcıları: hata listesine yazar, varsayılan değer döndürür ---

func _str(d: Dictionary, key: String, where: String) -> String:
	if typeof(d.get(key)) != TYPE_STRING or String(d.get(key)) == "":
		errors.append("%s: %s boş olmayan bir metin olmalı" % [where, key])
		return ""
	return d[key]


func _int(d: Dictionary, key: String, where: String, lo: int, hi: int) -> int:
	var v = d.get(key)
	if not GameData._is_number(v) or float(v) != floorf(float(v)) or int(v) < lo or int(v) > hi:
		errors.append("%s: %s %d ile %d arasında bir tam sayı olmalı" % [where, key, lo, hi])
		return lo
	return int(v)


func _num(d: Dictionary, key: String, where: String) -> float:
	var v = d.get(key)
	if not GameData._is_number(v):
		errors.append("%s: %s sayı olmalı" % [where, key])
		return 0.0
	return float(v)
