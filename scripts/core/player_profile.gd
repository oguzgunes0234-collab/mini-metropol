class_name PlayerProfile
extends RefCounted
## Oyuncunun kalıcı durumu: bölüm ilerlemesi, cüzdan, güçlendirici envanteri,
## ayarlar ve alınmış ödüller. SaveStore bu sınıfın durumunu yazar ve okur.
## Bölüm sonu ödülleri ve güçlendirici satın alma burada, tek bir yerden
## yapılır (çift ödül ya da bedavaya satın alma olmaz).

const STATE_VERSION := 1
## language: "" (cihazın dili), "tr" veya "en".
const DEFAULT_SETTINGS := {"sound": true, "music": true, "haptics": true, "reduced_motion": false, "language": ""}
const LANGUAGES: Array[String] = ["", "tr", "en"]

var progress := Progress.new()
var wallet := Wallet.new()
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## Ödülü alınmış toplam yıldız eşikleri.
var milestones_claimed: Array[int] = []
## Güçlendirici envanteri: id -> adet (0..economy.inventory_cap).
var boosters := {}
## Açılış hediyesi verilmiş güçlendiriciler (hediye bir kez verilir).
var boosters_gifted: Array[String] = []
## Oyuncuya henüz tanıtılmamış yeni güçlendiriciler (bölüm girişinde gösterilir).
var boosters_new: Array[String] = []
var economy: EconomyData


## İlk açılış: başlangıç bakiyesi verilir.
static func create_new(p_economy: EconomyData) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.economy = p_economy
	if p_economy.start_coins > 0:
		p.wallet.add("coins", p_economy.start_coins, "start")
	if p_economy.start_diamonds > 0:
		p.wallet.add("diamonds", p_economy.start_diamonds, "start")
	p._grant_unlock_gifts([])
	return p


## Kayıttan yükleme. Bozuk alanlar güvenli varsayılana döner.
static func from_state(state: Dictionary, p_economy: EconomyData) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.economy = p_economy
	p.set_state(state)
	# Eski kayıtlarda (güçlendiriciler eklenmeden önce) açılmış olanların hediyesi.
	p._grant_unlock_gifts([])
	return p


## Bölüm sonucunu işler: ilerlemeyi kaydeder, ödülleri hesaplar ve verir.
## Dönüş: {"coins", "diamonds", "boosters": {id: adet}, "lines": [{"key", "coins",
## "value", "diamonds", "boosters"}]} (sonuç ekranı için).
func apply_result(level: Dictionary, result: Dictionary) -> Dictionary:
	var lines: Array[Dictionary] = []
	var id := String(result.get("level_id", ""))
	if id != "" and result.won:
		var rewards: Dictionary = level.get("rewards", {})
		if progress.is_completed(id):
			_line(lines, "REWARD_REPEAT", int(rewards.get("coins_repeat", 0)))
		else:
			_line(lines, "REWARD_FIRST", int(rewards.get("coins_first", 0)))
			_line(lines, "REWARD_BOOSTERS", 0, 0, 0, rewards.get("boosters", {}))
		var new_stars := maxi(0, int(result.stars) - progress.stars(id))
		if new_stars > 0:
			_line(lines, "REWARD_NEW_STARS", new_stars * economy.coins_per_new_star, new_stars)
	progress.record(result)
	var total := progress.total_stars()
	for m in economy.star_milestones:
		if total >= int(m.stars) and not milestones_claimed.has(int(m.stars)):
			milestones_claimed.append(int(m.stars))
			_line(lines, "REWARD_MILESTONE", int(m.coins), int(m.stars), int(m.diamonds), m.boosters)
	var out := {"coins": 0, "diamonds": 0, "boosters": {}, "lines": lines}
	for l in lines:
		out.coins += int(l.coins)
		out.diamonds += int(l.diamonds)
		for b in l.boosters:
			out.boosters[b] = int(out.boosters.get(b, 0)) + int(l.boosters[b])
	if out.coins > 0:
		wallet.add("coins", out.coins, "level:%s" % id)
	if out.diamonds > 0:
		wallet.add("diamonds", out.diamonds, "level:%s" % id)
	for b in out.boosters:
		add_boosters(b, out.boosters[b])
	# Açılış hediyeleri en son: bu bölümle açılan güçlendirici hemen envantere girer.
	var before := lines.size()
	_grant_unlock_gifts(lines)
	for l in lines.slice(before):
		for b in l.boosters:
			out.boosters[b] = int(out.boosters.get(b, 0)) + int(l.boosters[b])
	return out


func setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


## Arayüz dili: ayar boşsa cihazın dili (Türkçe değilse İngilizce).
func locale() -> String:
	var lang := String(setting("language"))
	if lang != "":
		return lang
	return "tr" if OS.get_locale_language() == "tr" else "en"


# --- Güçlendiriciler ---

func booster_count(id: String) -> int:
	return int(boosters.get(id, 0))


## Güçlendirici açıldı mı? (Gerekli bölüm tamamlandı ya da geliştirici kilidi açtı.)
func is_booster_unlocked(id: String) -> bool:
	var def: Dictionary = economy.boosters.get(id, {})
	if def.is_empty():
		return false
	return progress.unlock_all or _unlocked_by_progress(def)


## Envantere ekler; sınırı aşan kısım eklenmez. Dönüş: gerçekten eklenen adet.
func add_boosters(id: String, count: int) -> int:
	if not economy.boosters.has(id) or count <= 0:
		return 0
	var before := booster_count(id)
	boosters[id] = mini(economy.inventory_cap, before + count)
	return booster_count(id) - before


## Envanterden bir adet düşer. Yoksa false.
func use_booster(id: String) -> bool:
	if booster_count(id) <= 0:
		return false
	boosters[id] = booster_count(id) - 1
	return true


## Bir adet satın alır (oyun içi para ile). Dönüş: "" (başarılı) veya neden:
## "unknown", "locked", "cap" (envanter dolu), "funds" (bakiye yetersiz).
## Başarısız satın almada hiçbir şey değişmez.
func buy_booster(id: String) -> String:
	var def: Dictionary = economy.boosters.get(id, {})
	if def.is_empty():
		return "unknown"
	if not is_booster_unlocked(id):
		return "locked"
	if booster_count(id) >= economy.inventory_cap:
		return "cap"
	if not wallet.spend(def.price_kind, int(def.price), "buy:%s" % id):
		return "funds"
	add_boosters(id, 1)
	return ""


func get_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"progress": progress.get_state(),
		"wallet": wallet.get_state(),
		"settings": settings.duplicate(),
		"milestones_claimed": milestones_claimed.duplicate(),
		"boosters": boosters.duplicate(),
		"boosters_gifted": boosters_gifted.duplicate(),
		"boosters_new": boosters_new.duplicate(),
	}


func set_state(s: Dictionary) -> void:
	progress = Progress.new()
	if typeof(s.get("progress")) == TYPE_DICTIONARY:
		progress.set_state(s.progress)
	wallet = Wallet.new()
	if typeof(s.get("wallet")) == TYPE_DICTIONARY:
		wallet.set_state(s.wallet)
	settings = DEFAULT_SETTINGS.duplicate()
	var st = s.get("settings", {})
	if typeof(st) == TYPE_DICTIONARY:
		for key in DEFAULT_SETTINGS:
			var v = st.get(key)
			if typeof(v) != typeof(DEFAULT_SETTINGS[key]):
				continue
			if key == "language" and not LANGUAGES.has(v):
				continue
			settings[key] = v
	milestones_claimed.clear()
	var mc = s.get("milestones_claimed", [])
	if typeof(mc) == TYPE_ARRAY:
		for v in mc:
			if GameData._is_number(v) and not milestones_claimed.has(int(v)):
				milestones_claimed.append(int(v))
	boosters = {}
	var inv = s.get("boosters", {})
	if typeof(inv) == TYPE_DICTIONARY:
		for id in EconomyData.BOOSTER_IDS:
			var v = inv.get(id)
			if GameData._is_number(v):
				boosters[id] = clampi(int(v), 0, maxi(economy.inventory_cap, 0) if economy != null else 0)
	boosters_gifted = _id_list(s.get("boosters_gifted"))
	boosters_new = _id_list(s.get("boosters_new"))


## Açılan ama hediyesi henüz verilmemiş güçlendiricilerin hediyesini verir.
## Geliştirici kilidi (unlock_all) hediye vermez; yalnızca gerçek ilerleme.
func _grant_unlock_gifts(lines: Array[Dictionary]) -> void:
	for id in EconomyData.BOOSTER_IDS:
		var def: Dictionary = economy.boosters.get(id, {})
		if def.is_empty() or boosters_gifted.has(id) or not _unlocked_by_progress(def):
			continue
		boosters_gifted.append(id)
		if not boosters_new.has(id):
			boosters_new.append(id)
		var gift := add_boosters(id, int(def.gift))
		lines.append({"key": "REWARD_BOOSTER_UNLOCKED", "coins": 0, "value": 0, "diamonds": 0, "boosters": {id: gift}, "booster": id})


func _unlocked_by_progress(def: Dictionary) -> bool:
	return def.unlock_after == "" or progress.is_completed(def.unlock_after)


static func _id_list(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for id in v:
			if typeof(id) == TYPE_STRING and EconomyData.BOOSTER_IDS.has(id) and not out.has(id):
				out.append(id)
	return out


func _line(lines: Array[Dictionary], key: String, coins: int, value: int = 0, diamonds: int = 0, p_boosters: Dictionary = {}) -> void:
	if coins > 0 or diamonds > 0 or not p_boosters.is_empty():
		lines.append({"key": key, "coins": coins, "value": value, "diamonds": diamonds, "boosters": p_boosters.duplicate()})
