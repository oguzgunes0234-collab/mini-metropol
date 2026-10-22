class_name SimBot
extends RefCounted
## Test ve simülasyon için otomatik oyuncu.
## RANDOM:  rastgele bir yere bırakır.
## GREEDY:  aynı seviyedeki en yüksek binanın üstüne bırakmaya çalışır,
##          yoksa rastgele bırakır. Gündelik oyuncunun kaba taklidi.
## PLANNER: her hamlede birkaç bırakma noktasını dener (anlık görüntü +
##          kısa simülasyon + geri yükleme) ve en iyi sonucu seçer. Dikkatli
##          bir oyuncunun kaba taklidi. Yavaştır; bölüm doğrulamasında kullanılır.

enum Kind { RANDOM, GREEDY, PLANNER }

## Planlayıcının her aday için ileriye baktığı fizik karesi sayısı.
const PLAN_FRAMES := 90
const PLAN_GRID := 7

var kind: Kind
var _rng := RandomNumberGenerator.new()


func _init(p_kind: Kind, seed_value: int) -> void:
	kind = p_kind
	_rng.seed = seed_value


static func kind_from_name(n: String) -> Kind:
	match n:
		"greedy":
			return Kind.GREEDY
		"planner":
			return Kind.PLANNER
	return Kind.RANDOM


## Planlayıcı dışındaki botlar için anında seçim.
func choose_x(session: GameSession) -> float:
	var board := session.board
	if kind != Kind.RANDOM:
		var best := _highest_same_level(session)
		if best != null:
			return best.position.x + _rng.randf_range(-6.0, 6.0)
	return _rng.randf_range(0.0, board.width)


## Her bot türü için seçim (planlayıcı fizik karesi beklediği için eşzamansız).
func choose(session: GameSession, tree: SceneTree) -> float:
	if kind != Kind.PLANNER:
		return choose_x(session)
	return await _plan(session, tree)


func _highest_same_level(session: GameSession) -> Building:
	var level := session.current_level()
	var best: Building = null
	for b in session.board.buildings:
		if b.level == level and (best == null or b.position.y < best.position.y):
			best = b
	return best


func _candidates(session: GameSession) -> Array[float]:
	var board := session.board
	var r := session.data.radius(session.current_level())
	var out: Array[float] = []
	for i in PLAN_GRID:
		var t := (i + 0.5) / PLAN_GRID
		out.append(lerpf(r, board.width - r, t) + _rng.randf_range(-12.0, 12.0))
	var same: Array[Building] = []
	for b in board.buildings:
		if b.level == session.current_level():
			same.append(b)
	same.sort_custom(func(a, b): return a.position.y < b.position.y)
	for i in mini(3, same.size()):
		out.append(same[i].position.x + _rng.randf_range(-4.0, 4.0))
	return out


func _plan(session: GameSession, tree: SceneTree) -> float:
	var snap := session.capture_snapshot()
	var best_x := _rng.randf_range(0.0, session.board.width)
	var best_v := -INF
	for x in _candidates(session):
		var v := -1.0e5
		if session.try_drop(x):
			for i in PLAN_FRAMES:
				await tree.physics_frame
				if session.is_finished():
					break
			v = _evaluate(session)
		session.restore_snapshot(snap)
		if v > best_v:
			best_v = v
			best_x = x
	return best_x


func _evaluate(s: GameSession) -> float:
	if s.state == GameSession.State.WON:
		return 1.0e6 - s.moves * 10.0
	if s.state == GameSession.State.LOST:
		return -1.0e6
	var v := 0.0
	for i in s.goals.goals.size():
		v += 1000.0 * minf(1.0, float(s.goals.progress[i]) / s.goals.target(i))
		var g: Dictionary = s.goals.goals[i]
		if g.type == "build" and not s.goals.is_done(i):
			# Kısmi ilerleme: hedef seviyeye en çok yaklaşmış bina.
			var best := 1
			for b in s.board.buildings:
				if b.level < int(g.level):
					best = maxi(best, b.level)
			v += 400.0 * float(best - 1) / float(int(g.level) - 1) / s.goals.target(i)
	v += s.score.score * 0.5
	var top := s.board.height
	for b in s.board.buildings:
		top = minf(top, b.top_y())
	var fill := 1.0 - top / s.board.height
	v -= 900.0 * fill * fill
	v -= 400.0 * s.board.danger_ratio
	var bs := s.board.buildings
	for i in bs.size():
		for j in range(i + 1, bs.size()):
			if bs[i].level == bs[j].level and bs[i].position.distance_to(bs[j].position) < (bs[i].radius + bs[j].radius) * 1.6:
				v += 15.0 * bs[i].level
	return v
