class_name Progress
extends RefCounted
## Oyuncunun bölüm ilerlemesi: en iyi yıldız ve puan, tamamlanma, art arda
## başarısızlık sayısı (ipucu göstermek için) ve bölüm kilitleri.
## Şimdilik bellekte tutulur; kalıcı kayıt Aşama 4'te bu durum üzerine kurulacak.

var best: Dictionary = {}
var fails: Dictionary = {}
## Serbest oyundaki en yüksek puan.
var free_best := 0
## Geliştirici: tüm bölümleri aç (U tuşu).
var unlock_all := false


func record(result: Dictionary) -> void:
	var id: String = result.level_id
	if id == "":
		free_best = maxi(free_best, int(result.score))
		return
	if result.won:
		var prev: Dictionary = best.get(id, {"stars": 0, "score": 0})
		best[id] = {
			"stars": maxi(int(prev.stars), int(result.stars)),
			"score": maxi(int(prev.score), int(result.score)),
			"completed": true,
		}
		fails[id] = 0
	else:
		fails[id] = int(fails.get(id, 0)) + 1


func is_completed(id: String) -> bool:
	return best.has(id) and best[id].completed


func stars(id: String) -> int:
	return int(best[id].stars) if best.has(id) else 0


func best_score(id: String) -> int:
	return int(best[id].score) if best.has(id) else 0


func fail_count(id: String) -> int:
	return int(fails.get(id, 0))


func total_stars() -> int:
	var n := 0
	for id in best:
		n += int(best[id].stars)
	return n


func is_unlocked(level: Dictionary) -> bool:
	return unlock_all or level.unlock_after == "" or is_completed(level.unlock_after)


func get_state() -> Dictionary:
	return {"best": best.duplicate(true), "fails": fails.duplicate(), "free_best": free_best}


## Kayıttan yükler. Bozuk/eksik değerler atlanır ya da güvenli varsayılana döner.
func set_state(s: Dictionary) -> void:
	best.clear()
	fails.clear()
	var b = s.get("best", {})
	if typeof(b) == TYPE_DICTIONARY:
		for id in b:
			var e = b[id]
			if typeof(id) != TYPE_STRING or typeof(e) != TYPE_DICTIONARY:
				continue
			best[id] = {
				"stars": clampi(int(e.get("stars", 0)) if GameData._is_number(e.get("stars")) else 0, 0, 3),
				"score": maxi(0, int(e.get("score", 0)) if GameData._is_number(e.get("score")) else 0),
				"completed": typeof(e.get("completed")) == TYPE_BOOL and e.completed,
			}
	var f = s.get("fails", {})
	if typeof(f) == TYPE_DICTIONARY:
		for id in f:
			if typeof(id) == TYPE_STRING and GameData._is_number(f[id]):
				fails[id] = maxi(0, int(f[id]))
	var fb = s.get("free_best", 0)
	free_best = maxi(0, int(fb)) if GameData._is_number(fb) else 0
