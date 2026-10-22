class_name PlayerProfile
extends RefCounted
## Oyuncunun kalıcı durumu: bölüm ilerlemesi, cüzdan, ayarlar ve alınmış
## kilometre taşı ödülleri. SaveStore bu sınıfın durumunu yazar ve okur.
## Bölüm sonu ödülleri burada, tek bir yerden verilir (çift ödül olmaz).

const STATE_VERSION := 1
const DEFAULT_SETTINGS := {"sound": true, "music": true, "haptics": true, "reduced_motion": false}

var progress := Progress.new()
var wallet := Wallet.new()
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## Ödülü alınmış toplam yıldız eşikleri.
var milestones_claimed: Array[int] = []
var economy: EconomyData


## İlk açılış: başlangıç bakiyesi verilir.
static func create_new(p_economy: EconomyData) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.economy = p_economy
	if p_economy.start_coins > 0:
		p.wallet.add("coins", p_economy.start_coins, "start")
	if p_economy.start_diamonds > 0:
		p.wallet.add("diamonds", p_economy.start_diamonds, "start")
	return p


## Kayıttan yükleme. Bozuk alanlar güvenli varsayılana döner.
static func from_state(state: Dictionary, p_economy: EconomyData) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.economy = p_economy
	p.set_state(state)
	return p


## Bölüm sonucunu işler: ilerlemeyi kaydeder, ödülleri hesaplar ve cüzdana ekler.
## Dönüş: {"coins": toplam, "lines": [{"key", "coins", "value"}]} (sonuç ekranı için).
func apply_result(level: Dictionary, result: Dictionary) -> Dictionary:
	var lines: Array[Dictionary] = []
	var id := String(result.get("level_id", ""))
	if id != "" and result.won:
		var rewards: Dictionary = level.get("rewards", {})
		if progress.is_completed(id):
			_line(lines, "REWARD_REPEAT", int(rewards.get("coins_repeat", 0)))
		else:
			_line(lines, "REWARD_FIRST", int(rewards.get("coins_first", 0)))
		var new_stars := maxi(0, int(result.stars) - progress.stars(id))
		if new_stars > 0:
			_line(lines, "REWARD_NEW_STARS", new_stars * economy.coins_per_new_star, new_stars)
	progress.record(result)
	var total := progress.total_stars()
	for m in economy.star_milestones:
		if total >= int(m.stars) and not milestones_claimed.has(int(m.stars)):
			milestones_claimed.append(int(m.stars))
			_line(lines, "REWARD_MILESTONE", int(m.coins), int(m.stars))
	var coins := 0
	for l in lines:
		coins += int(l.coins)
	if coins > 0:
		wallet.add("coins", coins, "level:%s" % id)
	return {"coins": coins, "lines": lines}


func setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func get_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"progress": progress.get_state(),
		"wallet": wallet.get_state(),
		"settings": settings.duplicate(),
		"milestones_claimed": milestones_claimed.duplicate(),
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
			if typeof(st.get(key)) == TYPE_BOOL:
				settings[key] = st[key]
	milestones_claimed.clear()
	var mc = s.get("milestones_claimed", [])
	if typeof(mc) == TYPE_ARRAY:
		for v in mc:
			if GameData._is_number(v) and not milestones_claimed.has(int(v)):
				milestones_claimed.append(int(v))


func _line(lines: Array[Dictionary], key: String, coins: int, value: int = 0) -> void:
	if coins > 0:
		lines.append({"key": key, "coins": coins, "value": value})
