class_name GameData
extends RefCounted
## Oyun verilerini (bina tanımları ve genel kurallar) JSON dosyalarından yükler
## ve doğrular. Oyundaki tüm ayarlanabilir sayılar buradan okunur; kodun
## başka yerlerine sabit değer gömülmez.

const BUILDINGS_PATH := "res://data/buildings.json"
const RULES_PATH := "res://data/rules.json"
const FINAL_RULES: Array[String] = ["landmark", "none"]
const SHAPE_MODES: Array[String] = ["circle", "rounded_box"]

## Kurallar dosyasında bulunması zorunlu sayısal alanlar: bölüm -> alan listesi.
const REQUIRED_NUMBERS := {
	"board": ["width", "height", "wall_thickness", "wall_extra_height"],
	"physics": ["gravity_scale", "friction", "bounce", "linear_damp", "angular_damp", "max_speed", "max_up_speed"],
	"drop": ["cooldown_sec", "dropper_y", "preview_count"],
	"merge": ["grow_start_scale", "grow_duration_sec", "inherit_velocity", "chain_bonus_per_step", "chain_bonus_max_steps"],
	"final_level": ["bonus_score"],
	"game_over": ["danger_line_y", "danger_time_sec", "drop_grace_sec"],
}

static var _default: GameData

## Seviye 1'den başlayarak bina tanımları (dizin 0 = seviye 1).
var levels: Array[Dictionary] = []
var rules: Dictionary = {}
var errors: PackedStringArray = []

var max_level: int:
	get:
		return levels.size()


## Oyunun varsayılan veri dosyalarını bir kez yükler ve önbellekte tutar.
static func load_default() -> GameData:
	if _default == null:
		_default = load_from_files(BUILDINGS_PATH, RULES_PATH)
	return _default


static func load_from_files(buildings_path: String, rules_path: String) -> GameData:
	var data := GameData.new()
	var buildings = _read_json(buildings_path, data.errors)
	var rules_dict = _read_json(rules_path, data.errors)
	if data.errors.is_empty():
		data._apply(buildings, rules_dict)
	return data


## Testlerde ve ileride bölüm verilerinde kullanılmak üzere sözlüklerden veri oluşturur.
static func from_dicts(buildings: Dictionary, rules_dict: Dictionary) -> GameData:
	var data := GameData.new()
	data._apply(buildings.duplicate(true), rules_dict.duplicate(true))
	return data


static func _read_json(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Dosya bulunamadı: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s satır %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s bir JSON nesnesi olmalı" % path)
		return null
	return json.data


func is_valid() -> bool:
	return errors.is_empty()


func level_def(level: int) -> Dictionary:
	return levels[level - 1]


func radius(level: int) -> float:
	return levels[level - 1].radius


## Bir seviyenin "değeri": iki seviye-n bina bir seviye-(n+1) eder, bu yüzden
## değer 2^(n-1) olarak korunur. Testlerde kayıp/çift bina kontrolünde kullanılır.
static func value_of(level: int) -> int:
	return 1 << (level - 1)


func section(name: String) -> Dictionary:
	return rules[name]


func _apply(buildings: Dictionary, rules_dict: Dictionary) -> void:
	_validate_buildings(buildings)
	if not errors.is_empty():
		return
	_validate_rules(rules_dict)
	if not errors.is_empty():
		levels.clear()
		return
	rules = rules_dict


func _validate_buildings(buildings: Dictionary) -> void:
	var list = buildings.get("levels")
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		errors.append("buildings: 'levels' boş olmayan bir liste olmalı")
		return
	var prev_radius := 0.0
	for i in list.size():
		var entry = list[i]
		var where := "buildings.levels[%d]" % i
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s bir nesne olmalı" % where)
			continue
		for key in ["level", "radius", "mass", "merge_score"]:
			if not _is_number(entry.get(key)):
				errors.append("%s.%s sayı olmalı" % [where, key])
		for key in ["id", "name_key", "color", "accent"]:
			if typeof(entry.get(key)) != TYPE_STRING:
				errors.append("%s.%s metin olmalı" % [where, key])
		if not errors.is_empty():
			continue
		var errors_before := errors.size()
		if int(entry.level) != i + 1:
			errors.append("%s.level %d olmalı (seviyeler 1'den başlayıp sırayla artmalı)" % [where, i + 1])
		if float(entry.radius) <= prev_radius:
			errors.append("%s.radius bir önceki seviyeden büyük olmalı" % where)
		if float(entry.mass) <= 0.0:
			errors.append("%s.mass pozitif olmalı" % where)
		if float(entry.merge_score) < 0.0:
			errors.append("%s.merge_score negatif olamaz" % where)
		for key in ["color", "accent"]:
			if not Color.html_is_valid(entry[key]):
				errors.append("%s.%s geçerli bir renk değil" % [where, key])
		prev_radius = float(entry.radius)
		if errors.size() > errors_before:
			continue
		var def := {
			"level": int(entry.level),
			"id": String(entry.id),
			"name_key": String(entry.name_key),
			"radius": float(entry.radius),
			"mass": float(entry.mass),
			"merge_score": int(entry.merge_score),
			"color": Color.html(entry.color),
			"accent": Color.html(entry.accent),
		}
		levels.append(def)


func _validate_rules(r: Dictionary) -> void:
	for section_name in REQUIRED_NUMBERS:
		var sec = r.get(section_name)
		if typeof(sec) != TYPE_DICTIONARY:
			errors.append("rules.%s bölümü eksik" % section_name)
			continue
		for key in REQUIRED_NUMBERS[section_name]:
			if not _is_number(sec.get(key)):
				errors.append("rules.%s.%s sayı olmalı" % [section_name, key])
	if not errors.is_empty():
		return

	var physics: Dictionary = r.physics
	if not SHAPE_MODES.has(physics.get("shape_mode")):
		errors.append("rules.physics.shape_mode şunlardan biri olmalı: %s" % ", ".join(SHAPE_MODES))
	if float(physics.max_speed) <= 0.0 or float(physics.max_up_speed) <= 0.0:
		errors.append("rules.physics.max_speed ve max_up_speed pozitif olmalı")

	var final_rule = r.final_level.get("rule")
	if not FINAL_RULES.has(final_rule):
		errors.append("rules.final_level.rule şunlardan biri olmalı: %s" % ", ".join(FINAL_RULES))

	var board: Dictionary = r.board
	var largest: float = levels[levels.size() - 1].radius
	if float(board.width) <= largest * 2.0:
		errors.append("rules.board.width en büyük binanın çapından (%d) geniş olmalı" % int(largest * 2.0))
	if float(board.height) <= largest * 2.0:
		errors.append("rules.board.height en büyük binanın çapından yüksek olmalı")

	var drop: Dictionary = r.drop
	var spawn_levels = drop.get("spawn_levels")
	var spawn_weights = drop.get("spawn_weights")
	if typeof(spawn_levels) != TYPE_ARRAY or spawn_levels.is_empty():
		errors.append("rules.drop.spawn_levels boş olmayan bir liste olmalı")
	elif typeof(spawn_weights) != TYPE_ARRAY or spawn_weights.size() != spawn_levels.size():
		errors.append("rules.drop.spawn_weights, spawn_levels ile aynı uzunlukta olmalı")
	else:
		var total := 0.0
		for i in spawn_levels.size():
			var lvl = spawn_levels[i]
			if not _is_number(lvl) or int(lvl) < 1 or int(lvl) >= levels.size():
				errors.append("rules.drop.spawn_levels[%d] 1 ile %d arasında olmalı" % [i, levels.size() - 1])
			if not _is_number(spawn_weights[i]) or float(spawn_weights[i]) < 0.0:
				errors.append("rules.drop.spawn_weights[%d] negatif olmayan bir sayı olmalı" % i)
			else:
				total += float(spawn_weights[i])
		if total <= 0.0:
			errors.append("rules.drop.spawn_weights toplamı sıfırdan büyük olmalı")
	if int(drop.preview_count) < 0:
		errors.append("rules.drop.preview_count negatif olamaz")
	if float(drop.cooldown_sec) < 0.0:
		errors.append("rules.drop.cooldown_sec negatif olamaz")

	var merge: Dictionary = r.merge
	if float(merge.grow_start_scale) <= 0.0 or float(merge.grow_start_scale) > 1.0:
		errors.append("rules.merge.grow_start_scale 0 ile 1 arasında olmalı")
	if float(r.game_over.danger_time_sec) <= 0.0:
		errors.append("rules.game_over.danger_time_sec pozitif olmalı")


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
