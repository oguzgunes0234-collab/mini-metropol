class_name EconomyData
extends RefCounted
## Ekonomi ayarlarını (data/economy.json) yükler ve doğrular. Ödül, fiyat ve
## güçlendirici kuralları kodun içine gömülmez; hepsi buradan okunur.

const PATH := "res://data/economy.json"

## Güçlendiriciler, oyun içindeki sıralarıyla.
const BOOSTER_IDS: Array[String] = ["undo", "swap", "crane", "relieve", "extra_moves"]
## Güçlendiriciye özgü etki ayarları ve geçerli aralıkları.
const BOOSTER_PARAMS := {
	"crane": {"max_level": [1, 8]},
	"relieve": {"max_level": [1, 4]},
	"extra_moves": {"amount": [1, 20]},
}

static var _default: EconomyData

var start_coins := 0
var start_diamonds := 0
var coins_per_new_star := 0
## [{stars, coins, diamonds, boosters: {id: adet}}], yıldız sayısına göre artan sırada.
var star_milestones: Array[Dictionary] = []
## Her güçlendiriciden en fazla bu kadar biriktirilebilir.
var inventory_cap := 0
## id -> {price_kind, price, per_level, unlock_after, gift, + BOOSTER_PARAMS}
var boosters := {}
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
	e._parse_milestones(d.get("star_milestones", []))
	e._parse_boosters(d)
	return e


func is_valid() -> bool:
	return errors.is_empty()


## {id: adet} biçimindeki güçlendirici ödülünü doğrular (bölüm ve eşik ödülleri).
## Hatalar errors listesine eklenir; geçerli öğeler döner.
static func parse_booster_map(v: Variant, where: String, errors: PackedStringArray) -> Dictionary:
	var out := {}
	if v == null:
		return out
	if typeof(v) != TYPE_DICTIONARY:
		errors.append("%s: boosters {kimlik: adet} biçiminde olmalı" % where)
		return out
	for id in v:
		var n = v[id]
		if not BOOSTER_IDS.has(String(id)):
			errors.append("%s: bilinmeyen güçlendirici '%s' (geçerli: %s)" % [where, id, ", ".join(BOOSTER_IDS)])
		elif not GameData._is_number(n) or float(n) != floorf(float(n)) or int(n) < 1 or int(n) > 20:
			errors.append("%s: %s adedi 1-20 arası tam sayı olmalı" % [where, id])
		else:
			out[String(id)] = int(n)
	return out


func _parse_milestones(ms: Variant) -> void:
	if typeof(ms) != TYPE_ARRAY:
		errors.append("economy.star_milestones bir liste olmalı")
		return
	var prev := 0
	for m in ms:
		if typeof(m) != TYPE_DICTIONARY:
			errors.append("economy.star_milestones öğesi nesne olmalı")
			continue
		var stars := _nonneg(m, "stars")
		if stars <= prev:
			errors.append("economy.star_milestones yıldız sayıları artan sırada olmalı")
		prev = stars
		star_milestones.append({
			"stars": stars,
			"coins": _nonneg(m, "coins"),
			"diamonds": _nonneg(m, "diamonds") if m.has("diamonds") else 0,
			"boosters": parse_booster_map(m.get("boosters"), "economy.star_milestones[%d★]" % stars, errors),
		})


func _parse_boosters(d: Dictionary) -> void:
	inventory_cap = _nonneg(d, "inventory_cap")
	if inventory_cap < 1:
		errors.append("economy.inventory_cap en az 1 olmalı")
	var list = d.get("boosters")
	if typeof(list) != TYPE_DICTIONARY:
		errors.append("economy.boosters nesnesi eksik")
		return
	for id in list:
		if not BOOSTER_IDS.has(String(id)):
			errors.append("economy.boosters: bilinmeyen güçlendirici '%s'" % id)
	for id in BOOSTER_IDS:
		var b = list.get(id)
		var w := "economy.boosters.%s" % id
		if typeof(b) != TYPE_DICTIONARY:
			errors.append("%s eksik" % w)
			continue
		var def := {"price_kind": "", "price": 0, "unlock_after": String(b.get("unlock_after", ""))}
		var price = b.get("price")
		if typeof(price) != TYPE_DICTIONARY or price.size() != 1 or not Wallet.KINDS.has(String(price.keys()[0])):
			errors.append("%s.price tek bir kaynak içermeli: {\"coins\": n} veya {\"diamonds\": n}" % w)
		else:
			def.price_kind = String(price.keys()[0])
			def.price = _nonneg(price, def.price_kind)
			if def.price < 1:
				errors.append("%s.price en az 1 olmalı" % w)
		def.per_level = _nonneg(b, "per_level")
		if def.per_level < 1:
			errors.append("%s.per_level en az 1 olmalı" % w)
		def.gift = _nonneg(b, "gift")
		var params: Dictionary = BOOSTER_PARAMS.get(id, {})
		for key in params:
			var v := _nonneg(b, key)
			if v < params[key][0] or v > params[key][1]:
				errors.append("%s.%s %d-%d arası olmalı" % [w, key, params[key][0], params[key][1]])
			def[key] = v
		boosters[id] = def


func _nonneg(d: Dictionary, key: String) -> int:
	var v = d.get(key)
	if not GameData._is_number(v) or float(v) < 0.0 or float(v) != floorf(float(v)):
		errors.append("economy.%s negatif olmayan tam sayı olmalı" % key)
		return 0
	return int(v)
