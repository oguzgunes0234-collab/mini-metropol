class_name SimBot
extends RefCounted
## Test ve simülasyon için otomatik oyuncu.
## RANDOM: rastgele bir yere bırakır.
## GREEDY: aynı seviyedeki en yüksek binanın üstüne bırakmaya çalışır,
## yoksa rastgele bırakır. Gerçek oyuncu stratejisinin kaba bir taklididir.

enum Kind { RANDOM, GREEDY }

var kind: Kind
var _rng := RandomNumberGenerator.new()


func _init(p_kind: Kind, seed_value: int) -> void:
	kind = p_kind
	_rng.seed = seed_value


static func kind_from_name(n: String) -> Kind:
	return Kind.GREEDY if n == "greedy" else Kind.RANDOM


func choose_x(session: GameSession) -> float:
	var board := session.board
	if kind == Kind.GREEDY:
		var level := session.current_level()
		var best: Building = null
		for b in board.buildings:
			if b.level == level and (best == null or b.position.y < best.position.y):
				best = b
		if best != null:
			return best.position.x + _rng.randf_range(-6.0, 6.0)
	return _rng.randf_range(0.0, board.width)
