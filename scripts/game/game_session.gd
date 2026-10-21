class_name GameSession
extends Node
## Bir oyun oturumunun kuralları: bırakma, sıradaki bina, hamle sayısı, puan,
## oyun sonu ve anlık görüntü (geri al için). Arayüz içermez; oyun ekranı,
## testler ve simülasyon aynı oturum mantığını kullanır.

signal dropped(level: int, building: Building)
signal queue_changed(current: int, upcoming: Array[int])
signal scored(points: int, total: int, info: Dictionary)
signal finished(final_score: int, reason: String)

enum State { PLAYING, GAME_OVER }

var data: GameData
var board: Board
var score: ScoreKeeper
var queue: SpawnQueue
var state := State.PLAYING
var moves := 0
var cooldown_left := 0.0
var seed_value := 0
## Testler ve simülasyon için: her puan olayını kaydet.
var record_events := false
var event_log: Array[Dictionary] = []

var _cooldown := 0.0


func setup(p_data: GameData, p_board: Board) -> void:
	data = p_data
	board = p_board
	_cooldown = float(data.section("drop").cooldown_sec)
	board.merged.connect(_on_board_merged)
	board.game_over_triggered.connect(_on_board_game_over)


## Yeni oyun başlatır. Aynı tohum aynı bina sırasını üretir.
func start(p_seed: int) -> void:
	seed_value = p_seed
	board.reset()
	score = ScoreKeeper.new(data)
	queue = SpawnQueue.from_data(data, seed_value)
	moves = 0
	cooldown_left = 0.0
	state = State.PLAYING
	event_log.clear()
	queue_changed.emit(queue.current(), queue.upcoming())


func can_drop() -> bool:
	return state == State.PLAYING and cooldown_left <= 0.0


func current_level() -> int:
	return queue.current()


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
	var level := queue.advance()
	score.on_drop()
	var b := board.drop(level, x)
	moves += 1
	cooldown_left = _cooldown
	dropped.emit(level, b)
	queue_changed.emit(queue.current(), queue.upcoming())
	return true


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)


func _on_board_merged(info: Dictionary) -> void:
	if state != State.PLAYING:
		return
	var points: int
	if info.kind == MergeResolver.Kind.UPGRADE:
		points = score.on_merge(info.level)
	else:
		points = score.on_landmark()
	var event := info.duplicate()
	event.points = points
	event.chain = score.chain
	if record_events:
		event_log.append(event)
	scored.emit(points, score.score, event)


func _on_board_game_over(reason: String) -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	finished.emit(score.score, reason)


## Oturumun tam durumu: alan, puan, sıra, hamle ve bekleme süresi.
func capture_snapshot() -> Dictionary:
	return {
		"board": board.capture_state(),
		"score": score.get_state(),
		"queue": queue.get_state(),
		"moves": moves,
		"cooldown_left": cooldown_left,
		"state": state,
	}


func restore_snapshot(s: Dictionary) -> void:
	board.restore_state(s.board)
	score.set_state(s.score)
	queue.set_state(s.queue)
	moves = int(s.moves)
	cooldown_left = float(s.cooldown_left)
	state = int(s.state) as State
	queue_changed.emit(queue.current(), queue.upcoming())
