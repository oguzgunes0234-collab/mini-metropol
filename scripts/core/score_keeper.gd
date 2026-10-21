class_name ScoreKeeper
extends RefCounted
## Puan ve zincir sayacı. Zincir: son bırakmadan bu yana yapılan birleşme
## sayısıdır; her yeni bırakmada sıfırlanır. Zincirdeki her ek adım,
## verideki oranda puan bonusu verir.

var score := 0
var chain := 0
var best_chain := 0
var merges := 0
var landmarks := 0

var _merge_scores: Array[int] = []
var _chain_bonus: float
var _chain_max_steps: int
var _landmark_bonus: int


func _init(data: GameData) -> void:
	for def in data.levels:
		_merge_scores.append(def.merge_score)
	var merge := data.section("merge")
	_chain_bonus = float(merge.chain_bonus_per_step)
	_chain_max_steps = int(merge.chain_bonus_max_steps)
	_landmark_bonus = int(data.section("final_level").bonus_score)


func on_drop() -> void:
	chain = 0


## Yeni seviye bina oluştuğunda çağrılır; kazanılan puanı döndürür.
func on_merge(new_level: int) -> int:
	_advance_chain()
	merges += 1
	var points := points_for(new_level, chain)
	score += points
	return points


## İki son seviye bina Anıt olarak tamamlandığında çağrılır.
func on_landmark() -> int:
	_advance_chain()
	landmarks += 1
	score += _landmark_bonus
	return _landmark_bonus


func points_for(new_level: int, chain_index: int) -> int:
	return roundi(_merge_scores[new_level - 1] * multiplier(chain_index))


func multiplier(chain_index: int) -> float:
	var steps := clampi(chain_index - 1, 0, _chain_max_steps)
	return 1.0 + _chain_bonus * steps


func get_state() -> Dictionary:
	return {"score": score, "chain": chain, "best_chain": best_chain, "merges": merges, "landmarks": landmarks}


func set_state(s: Dictionary) -> void:
	score = int(s.score)
	chain = int(s.chain)
	best_chain = int(s.best_chain)
	merges = int(s.merges)
	landmarks = int(s.landmarks)


func _advance_chain() -> void:
	chain += 1
	best_chain = maxi(best_chain, chain)
