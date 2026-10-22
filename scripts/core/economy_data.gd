class_name EconomyData
extends RefCounted
## Ekonomi ayarlarını (data/economy.json) yükler ve doğrular. Ödül ve
## maliyetler kodun içine gömülmez; hepsi buradan okunur.

const PATH := "res://data/economy.json"

static var _default: EconomyData

var start_coins := 0
var start_diamonds := 0
var coins_per_new_star := 0
## [{stars, coins}], yıldız sayısına göre artan sırada.
var star_milestones: Array[Dictionary] = []
var errors: PackedStringArray = []


static func load_default() -> EconomyData:
	if _default == null:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_default = from_dict(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	return _default


static func from_dict(d: Dictionary) -> EconomyData:
	var e := EconomyData.new()
	var start = d.get("start")
	if typeof(start) != TYPE_DICTIONARY:
		e.errors.append("economy.start eksik")
	else:
		e.start_coins = e._nonneg(start, "coins")
		e.start_diamonds = e._nonneg(start, "diamonds")
	e.coins_per_new_star = e._nonneg(d, "coins_per_new_star")
	var ms = d.get("star_milestones", [])
	if typeof(ms) != TYPE_ARRAY:
		e.errors.append("economy.star_milestones bir liste olmalı")
		return e
	var prev := 0
	for m in ms:
		if typeof(m) != TYPE_DICTIONARY:
			e.errors.append("economy.star_milestones öğesi nesne olmalı")
			continue
		var stars := e._nonneg(m, "stars")
		if stars <= prev:
			e.errors.append("economy.star_milestones yıldız sayıları artan sırada olmalı")
		prev = stars
		e.star_milestones.append({"stars": stars, "coins": e._nonneg(m, "coins")})
	return e


func is_valid() -> bool:
	return errors.is_empty()


func _nonneg(d: Dictionary, key: String) -> int:
	var v = d.get(key)
	if not GameData._is_number(v) or float(v) < 0.0 or float(v) != floorf(float(v)):
		errors.append("economy.%s negatif olmayan tam sayı olmalı" % key)
		return 0
	return int(v)
