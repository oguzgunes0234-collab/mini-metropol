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


func set_state(s: Dictionary) -> void:
	best = s.get("best", {}).duplicate(true)
	fails = s.get("fails", {}).duplicate()
	free_best = int(s.get("free_best", 0))
