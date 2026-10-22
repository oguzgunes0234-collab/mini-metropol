class_name GameSession
extends Node
## Bir oyun oturumunun kuralları: bırakma, sıradaki bina, hamle sayısı, puan,
## bölüm hedefleri, kazanma/kaybetme ve anlık görüntü (geri al için).
## Arayüz içermez; oyun ekranı, testler ve simülasyon aynı mantığı kullanır.
##
## İki kip vardır:
## - Bölüm (start_level): hedefler, hamle sınırı ve yıldızlar.
## - Serbest (start): hedef ve hamle sınırı yok; alan dolunca biter.

signal dropped(level: int, building: Building)
signal queue_changed(current: int, upcoming: Array[int])
signal scored(points: int, total: int, info: Dictionary)
signal goals_changed
signal state_changed(state: State)
## result: won, reason, score, moves_used, moves_limit, best_chain, stars,
## star_flags, goals (özet), level_id
signal finished(result: Dictionary)

enum State { PLAYING, SETTLING, WON, LOST }

## Son hamleden sonra binaların "durmuş" sayılması için gereken süre.
const SETTLE_HOLD_SEC := 0.6
## Son hamleden sonra en fazla bu kadar beklenir (sonsuz yuvarlanmaya karşı).
const SETTLE_TIMEOUT_SEC := 6.0

var base_data: GameData
var data: GameData
var board: Board
var score: ScoreKeeper
var queue: SpawnQueue
var goals: LevelGoals
## Bölüm kipinde bölüm tanımı; serbest kipte boş.
var level: Dictionary = {}
var state := State.PLAYING
var moves := 0
var moves_limit := 0
var cooldown_left := 0.0
var seed_value := 0
var result: Dictionary = {}
## Testler ve simülasyon için: her puan olayını kaydet.
var record_events := false
var event_log: Array[Dictionary] = []

var _cooldown := 0.0
var _settle_hold := 0.0
var _settle_elapsed := 0.0


func setup(p_data: GameData, p_board: Board) -> void:
	base_data = p_data
	data = p_data
	board = p_board
	board.merged.connect(_on_board_merged)
	board.game_over_triggered.connect(_on_board_game_over)


func is_level_mode() -> bool:
	return not level.is_empty()


## Serbest oyun başlatır. Aynı tohum aynı bina sırasını üretir.
func start(p_seed: int) -> void:
	level = {}
	_begin(base_data, p_seed, [], 0, [])


## Bölüm başlatır (veya yeniden dener). Her denemede aynı bina sırası gelir.
func start_level(p_level: Dictionary, p_data: GameData) -> void:
	level = p_level
	_begin(p_data, int(p_level.seed), p_level.goals, int(p_level.moves), p_level.spawn_sequence, p_level.obstacles)
	for item in p_level.layout:
		board.place(int(item.level), Vector2(item.x, item.y))


func _begin(p_data: GameData, p_seed: int, goal_defs: Array, limit: int, sequence: Array, obstacles: Array = []) -> void:
	data = p_data
	seed_value = p_seed
	board.setup(data, obstacles)
	score = ScoreKeeper.new(data)
	queue = SpawnQueue.from_data(data, seed_value, sequence)
	goals = LevelGoals.new(goal_defs)
	_cooldown = float(data.section("drop").cooldown_sec)
	moves = 0
	moves_limit = limit
	cooldown_left = 0.0
	result = {}
	event_log.clear()
	_settle_hold = 0.0
	_settle_elapsed = 0.0
	_set_state(State.PLAYING)
	queue_changed.emit(queue.current(), queue.upcoming())
	goals_changed.emit()


func can_drop() -> bool:
	return state == State.PLAYING and cooldown_left <= 0.0


func current_level() -> int:
	return queue.current()


## Kalan hamle (serbest kipte -1).
func moves_left() -> int:
	return moves_limit - moves if moves_limit > 0 else -1


func is_finished() -> bool:
	return state == State.WON or state == State.LOST


## Sıradaki binayı x konumuna bırakmayı dener. Bırakılamazsa false döner:
## bekleme süresi dolmadıysa, oyun bittiyse ya da bırakma noktasından yeni
## düşen bir bina henüz çekilmediyse (biraz sonra tekrar denenebilir).
## Bırakma noktası yerleşmiş binalarla doluysa arsa dolmuştur ve oyun biter.
func try_drop(x: float) -> bool:
	if not can_drop():
		return false
	match board.room_at(queue.current(), x):
		Board.Room.FULL:
			board.end_game("no_room")
			return false
		Board.Room.BLOCKED_TEMP:
			return false
	var lvl := queue.advance()
	score.on_drop()
	var b := board.drop(lvl, x)
	moves += 1
	cooldown_left = _cooldown
	dropped.emit(lvl, b)
	queue_changed.emit(queue.current(), queue.upcoming())
	if moves_limit > 0 and moves >= moves_limit:
		# Son hamle: zincirlerin bitmesi beklenir, sonra sonuç verilir.
		_set_state(State.SETTLING)
	return true


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if state == State.SETTLING:
		_settle_elapsed += delta
		_settle_hold = _settle_hold + delta if board.is_settled() else 0.0
		if _settle_hold >= SETTLE_HOLD_SEC or _settle_elapsed >= SETTLE_TIMEOUT_SEC:
			_finish(false, "out_of_moves")


func _on_board_merged(info: Dictionary) -> void:
	if is_finished():
		return
	var points: int
	if info.kind == MergeResolver.Kind.UPGRADE:
		points = score.on_merge(info.level)
		goals.on_merge(info.level)
	else:
		points = score.on_landmark()
		goals.on_landmark()
	goals.on_score(score.score)
	goals.on_chain(score.best_chain)
	var event := info.duplicate()
	event.points = points
	event.chain = score.chain
	if record_events:
		event_log.append(event)
	scored.emit(points, score.score, event)
	goals_changed.emit()
	if is_level_mode() and goals.all_done():
		_finish(true, "goals")


func _on_board_game_over(reason: String) -> void:
	if is_finished():
		return
	_finish(false, reason)


func _finish(won: bool, reason: String) -> void:
	if won:
		board.halt()
	var flags: Array[bool] = []
	if is_level_mode():
		flags = LevelGoals.star_flags(level.stars, won, moves, score.score, score.best_chain)
	result = {
		"won": won,
		"reason": reason,
		"level_id": level.get("id", ""),
		"score": score.score,
		"moves_used": moves,
		"moves_limit": moves_limit,
		"best_chain": score.best_chain,
		"star_flags": flags,
		"stars": LevelGoals.star_count(flags),
		"goals": goals.summary(),
	}
	_set_state(State.WON if won else State.LOST)
	finished.emit(result)


func _set_state(s: State) -> void:
	if state != s or s == State.PLAYING:
		state = s
		state_changed.emit(state)


## Oturumun tam durumu: alan, puan, hedefler, sıra, hamle ve bekleme süresi.
func capture_snapshot() -> Dictionary:
	return {
		"board": board.capture_state(),
		"score": score.get_state(),
		"goals": goals.get_state(),
		"queue": queue.get_state(),
		"moves": moves,
		"cooldown_left": cooldown_left,
		"state": state,
		"events": event_log.size(),
	}


## Anlık görüntüyü geri yükler. Aynı bölüm (veya serbest kip) içinde kullanılır.
func restore_snapshot(s: Dictionary) -> void:
	board.restore_state(s.board)
	score.set_state(s.score)
	goals.set_state(s.goals)
	queue.set_state(s.queue)
	moves = int(s.moves)
	cooldown_left = float(s.cooldown_left)
	_settle_hold = 0.0
	_settle_elapsed = 0.0
	result = {}
	# Geri alınan hamlenin puan olayları da geri alınır.
	event_log.resize(mini(event_log.size(), int(s.get("events", event_log.size()))))
	_set_state(int(s.state) as State)
	queue_changed.emit(queue.current(), queue.upcoming())
	goals_changed.emit()
