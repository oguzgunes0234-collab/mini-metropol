class_name LevelGoals
extends RefCounted
## Bir bölümün hedeflerini ve ilerlemesini izler; yıldızları hesaplar.
##
## Hedef türleri:
##   build    {"level": L, "count": N}  L seviyesinde N bina üret (birleşmeyle)
##   score    {"value": P}              en az P puana ulaş
##   chain    {"value": K}              tek bırakışta en az K birleşmelik zincir yap
##   landmark {"count": N}              N Anıt tamamla (iki İkonik Kule)
##
## Yıldız ölçütleri (3 adet, ilki her zaman "complete"):
##   complete                 bölümü tamamla
##   moves_used_max {value}   en fazla bu kadar hamle kullan
##   score {value}            en az bu puan
##   chain {value}            en az bu uzunlukta zincir

const GOAL_TYPES: Array[String] = ["build", "score", "chain", "landmark"]
const STAR_TYPES: Array[String] = ["complete", "moves_used_max", "score", "chain"]

var goals: Array[Dictionary] = []
var progress: Array[int] = []


func _init(goal_defs: Array) -> void:
	for g in goal_defs:
		goals.append(g)
		progress.append(0)


func target(i: int) -> int:
	var g := goals[i]
	return int(g.count) if g.type in ["build", "landmark"] else int(g.value)


func is_done(i: int) -> bool:
	return progress[i] >= target(i)


func all_done() -> bool:
	for i in goals.size():
		if not is_done(i):
			return false
	return true


func on_merge(new_level: int) -> void:
	for i in goals.size():
		if goals[i].type == "build" and int(goals[i].level) == new_level:
			progress[i] += 1


func on_landmark() -> void:
	for i in goals.size():
		if goals[i].type == "landmark":
			progress[i] += 1


func on_score(score: int) -> void:
	_set_max("score", score)


func on_chain(best_chain: int) -> void:
	_set_max("chain", best_chain)


## Arayüz ve sonuç ekranı için hedeflerin özeti.
func summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in goals.size():
		var g := goals[i].duplicate()
		g.target = target(i)
		g.progress = mini(progress[i], target(i))
		g.done = is_done(i)
		out.append(g)
	return out


func get_state() -> Dictionary:
	return {"progress": progress.duplicate()}


func set_state(s: Dictionary) -> void:
	for i in progress.size():
		progress[i] = int(s.progress[i])


## Her yıldız ölçütünün sağlanıp sağlanmadığı. Bölüm tamamlanmadıysa hepsi false.
static func star_flags(star_defs: Array, completed: bool, moves_used: int, score: int, best_chain: int) -> Array[bool]:
	var flags: Array[bool] = []
	for s in star_defs:
		var ok := completed
		if ok:
			match String(s.type):
				"moves_used_max":
					ok = moves_used <= int(s.value)
				"score":
					ok = score >= int(s.value)
				"chain":
					ok = best_chain >= int(s.value)
		flags.append(ok)
	return flags


static func star_count(flags: Array[bool]) -> int:
	var n := 0
	for f in flags:
		if f:
			n += 1
	return n


func _set_max(type: String, value: int) -> void:
	for i in goals.size():
		if goals[i].type == type:
			progress[i] = maxi(progress[i], value)
