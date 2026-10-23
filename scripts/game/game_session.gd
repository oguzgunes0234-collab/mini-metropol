class_name GameSession
extends Node
## Bir oyun oturumunun kuralları: bırakma, sıradaki bina, hamle sayısı, puan,
## bölüm hedefleri, kazanma/kaybetme, anlık görüntü ve güçlendirici etkileri
## (geri al, değiştir, vinç, temizle, ek hamle). Arayüz içermez; oyun ekranı,
## testler ve simülasyon aynı mantığı kullanır. Güçlendiricilerin envanter ve
## kullanım sınırları BoosterManager'dadır; burada yalnızca etkiler vardır.
##
## İki kip vardır:
## - Bölüm (start_level): hedefler, hamle sınırı ve yıldızlar.
## - Serbest (start): hedef ve hamle sınırı yok; alan dolunca biter.

signal dropped(level: int, building: Building)
signal queue_changed(current: int, upcoming: Array[int])
signal scored(points: int, total: int, info: Dictionary)
signal goals_changed
signal state_changed(state: State)
signal moves_changed(used: int, limit: int)
## Anlık görüntü geri yüklendi (geri al): alan, puan, hedefler ve hamle değişti.
signal restored
## "Temizle": kaldırılan binalar [{level, position}].
signal cleared(removed: Array[Dictionary])
## "Vinç": alınan binanın seviyesi ve eski konumu.
signal lifted(level: int, position: Vector2)
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
## Her geri yüklemede artar (tutarlılık denetimi olay kaydını yeniden okur).
var log_epoch := 0
## "Vinç" ile alınıp henüz bırakılmamış binanın seviyesi (0: yok). Varken
## sıradaki bina odur; bırakılması hamle harcamaz.
var held_level := 0

## Son bırakmadan hemen önceki anlık görüntü (geri al için; tek adım).
var _undo: Dictionary = {}

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
	held_level = 0
	_undo = {}
	_set_state(State.PLAYING)
	_emit_queue()
	goals_changed.emit()
	moves_changed.emit(moves, moves_limit)


func can_drop() -> bool:
	return state == State.PLAYING and cooldown_left <= 0.0


## Şimdi bırakılacak bina (vinçle alınmış bina varsa o).
func current_level() -> int:
	return held_level if held_level > 0 else queue.current()


## Önizlemede gösterilecek sonraki binalar.
func upcoming_levels() -> Array[int]:
	if held_level > 0:
		var list: Array[int] = [queue.current()]
		list.append_array(queue.upcoming())
		return list
	return queue.upcoming()


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
	match board.room_at(current_level(), x):
		Board.Room.FULL:
			board.end_game("no_room")
			return false
		Board.Room.BLOCKED_TEMP:
			return false
	var snapshot := capture_snapshot()
	var from_hand := held_level > 0
	var lvl: int
	if from_hand:
		lvl = held_level
		held_level = 0
	else:
		lvl = queue.advance()
		moves += 1
	_undo = snapshot
	score.on_drop()
	var b := board.drop(lvl, x)
	cooldown_left = _cooldown
	dropped.emit(lvl, b)
	_emit_queue()
	moves_changed.emit(moves, moves_limit)
	if not from_hand and moves_limit > 0 and moves >= moves_limit:
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


# --- Güçlendirici etkileri ---
# Her etkinin can_* kontrolü vardır; etki yalnızca kontrol geçerse uygulanır
# ve true döner. Alanı veya sırayı değiştiren etkiler geri alma adımını siler
# (geri al yalnızca son bırakmayı geri alır; araya giren etkiyi bozmaz).

## Geri al: son bırakmadan hemen önceki duruma döner (alan, puan, hedefler,
## sıra, hamle). Ek hamleler korunur. Oyun bittikten sonra kullanılamaz.
func can_undo() -> bool:
	return not _undo.is_empty() and (state == State.PLAYING or state == State.SETTLING)


func undo() -> bool:
	if not can_undo():
		return false
	restore_snapshot(_undo)
	return true


## Değiştir: şimdiki binayla sıradakinin yerini değiştirir.
func can_swap() -> bool:
	return state == State.PLAYING and held_level == 0 and not queue.upcoming().is_empty() \
		and queue.current() != queue.upcoming()[0]


func swap() -> bool:
	if not can_swap():
		return false
	queue.swap_next()
	_undo = {}
	_emit_queue()
	return true


## Ek hamle: hamle sınırını artırır. Son hamle yapılmış ve sonuç bekleniyorsa
## (SETTLING) oyun devam eder.
func can_add_moves() -> bool:
	return moves_limit > 0 and (state == State.PLAYING or state == State.SETTLING)


func add_moves(amount: int) -> bool:
	if amount <= 0 or not can_add_moves():
		return false
	moves_limit += amount
	if state == State.SETTLING:
		_settle_hold = 0.0
		_settle_elapsed = 0.0
		_set_state(State.PLAYING)
	moves_changed.emit(moves, moves_limit)
	return true


## Temizle: seviyesi max_level veya altındaki tüm binaları kaldırır (puan vermez).
func can_clear(max_level: int) -> bool:
	return state == State.PLAYING and board.count_up_to(max_level) > 0


func clear_small(max_level: int) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if not can_clear(max_level):
		return removed
	removed = board.clear_small(max_level)
	_undo = {}
	cleared.emit(removed)
	return removed


## Vinç: alandaki bir binayı alır; bina sıradaki bina olur ve istenen yere
## yeniden bırakılır. Yeniden bırakmak hamle harcamaz.
func can_lift_any(max_level: int) -> bool:
	return state == State.PLAYING and held_level == 0 and board.count_up_to(max_level) > 0


func can_lift(b: Building, max_level: int) -> bool:
	return state == State.PLAYING and held_level == 0 and b != null and is_instance_valid(b) \
		and board.buildings.has(b) and b.level <= max_level


func lift(b: Building, max_level: int) -> bool:
	if not can_lift(b, max_level):
		return false
	var pos := b.position
	held_level = board.lift(b)
	_undo = {}
	lifted.emit(held_level, pos)
	_emit_queue()
	return true


func _emit_queue() -> void:
	queue_changed.emit(current_level(), upcoming_levels())


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
		"held": held_level,
	}


## Anlık görüntüyü geri yükler. Aynı bölüm (veya serbest kip) içinde kullanılır.
func restore_snapshot(s: Dictionary) -> void:
	board.restore_state(s.board)
	score.set_state(s.score)
	goals.set_state(s.goals)
	queue.set_state(s.queue)
	moves = int(s.moves)
	held_level = int(s.get("held", 0))
	cooldown_left = float(s.cooldown_left)
	_settle_hold = 0.0
	_settle_elapsed = 0.0
	result = {}
	# Geri alınan hamlenin puan olayları da geri alınır.
	event_log.resize(mini(event_log.size(), int(s.get("events", event_log.size()))))
	log_epoch += 1
	# Geri al tek adımdır: geri yüklenen durumdan bir daha geri alınamaz.
	_undo = {}
	_set_state(int(s.state) as State)
	_emit_queue()
	goals_changed.emit()
	moves_changed.emit(moves, moves_limit)
	restored.emit()
