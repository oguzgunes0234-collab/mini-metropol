extends TestCase
## Güçlendiriciler gerçek fizikle: her etkinin kuralı, kullanım sınırları,
## envanter ve kötüye kullanım (çift ödül, bedava kullanım) senaryoları.

const H := 1280.0

var session: GameSession
var manager: BoosterManager
var profile: PlayerProfile


## Bölüm oturumu + tüm güçlendiricileri açık ve envanterinde `count` adet olan oyuncu.
func _setup(level: Variant, count: int = 5) -> void:
	session = make_level_session(level)
	profile = PlayerProfile.create_new(EconomyData.load_default())
	profile.progress.unlock_all = true
	for id in EconomyData.BOOSTER_IDS:
		profile.add_boosters(id, count)
	manager = BoosterManager.new()
	manager.setup(session, profile)


## Kazanılması zor (hedef seviye 8) test bölümü: testler kendiliğinden bitmesin.
func _lv(overrides: Dictionary = {}) -> Dictionary:
	var d := {"moves": 20, "goals": [{"type": "build", "level": 8, "count": 1}]}
	d.merge(overrides, true)
	return level_dict(d)


func _drop(x: float) -> void:
	await wait_cooldown(session)
	assert_true(session.try_drop(x), "bırakma yapılabilmeli")


func _summary(s: GameSession) -> Dictionary:
	var list := []
	for b in s.board.buildings:
		list.append([b.level, snappedf(b.position.x, 0.01), snappedf(b.position.y, 0.01)])
	list.sort()
	return {
		"buildings": list,
		"score": s.score.get_state(),
		"goals": s.goals.summary(),
		"moves": s.moves,
		"current": s.current_level(),
		"upcoming": s.upcoming_levels(),
	}


# --- Geri al ---

func test_undo_returns_to_state_before_last_drop() -> void:
	_setup(_lv())
	var inv := Invariants.new()
	for i in 4:
		await _drop(200 + i * 150)
		await run_checked(session, inv, 20)
	await run_checked(session, inv, 120)
	var before := _summary(session)
	var dropped_level := session.current_level()
	await _drop(450)
	await run_checked(session, inv, 90)
	assert_true(manager.use("undo"))
	assert_eq(_summary(session), before, "son bırakmadan önceki duruma dönülmeli")
	assert_eq(session.current_level(), dropped_level, "geri alınan bina yeniden sıraya gelir")
	assert_eq(profile.booster_count("undo"), 4)
	await run_checked(session, inv, 60)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_undo_is_one_step_only() -> void:
	_setup(_lv())
	assert_eq(manager.check("undo"), "not_now", "henüz bırakma yok")
	await _drop(200)
	await _drop(700)
	assert_true(manager.use("undo"))
	assert_eq(manager.check("undo"), "not_now", "art arda ikinci geri alma yok")
	await _drop(450)
	assert_eq(manager.check("undo"), "", "yeni bırakmadan sonra tekrar kullanılabilir")


func test_undo_after_last_move_resumes_play() -> void:
	_setup(_lv({"moves": 2, "stars": [{"type": "complete"}, {"type": "moves_used_max", "value": 2}, {"type": "score", "value": 10}]}))
	await _drop(200)
	await _drop(700)
	assert_eq(session.state, GameSession.State.SETTLING)
	assert_true(manager.use("undo"))
	assert_eq(session.state, GameSession.State.PLAYING)
	assert_eq(session.moves_left(), 1)


func test_no_booster_after_level_is_finished() -> void:
	# Bölüm kazanıldıktan sonra geri al yok: ödül iki kez alınamaz.
	_setup(level_dict({"moves": 10, "layout": [{"level": 1, "x": 450, "y": H - 50}], "spawn_sequence": [1]}))
	await _drop(450)
	for i in steps(240):
		await tree.physics_frame
		if session.is_finished():
			break
	assert_true(session.result.get("won", false), "bölüm kazanılmalı")
	for id in EconomyData.BOOSTER_IDS:
		assert_eq(manager.check(id), "finished", id)
		assert_false(manager.use(id), id)
	assert_eq(profile.booster_count("undo"), 5, "bitmiş bölümde envanter değişmez")


# --- Değiştir ---

func test_swap_exchanges_current_and_next() -> void:
	_setup(_lv({"spawn_sequence": [1, 3, 2]}))
	assert_eq([session.current_level(), session.upcoming_levels()[0]], [1, 3])
	assert_true(manager.use("swap"))
	assert_eq([session.current_level(), session.upcoming_levels()[0]], [3, 1])
	await _drop(450)
	assert_eq([session.current_level(), session.upcoming_levels()[0]], [1, 2], "değiştirilen bina sıradaki olur")
	assert_eq(session.moves, 1, "değiştirmek hamle harcamaz")


func test_swap_needs_different_levels_and_clears_undo() -> void:
	_setup(_lv({"spawn_sequence": [1, 1, 2, 3]}))
	assert_eq(manager.check("swap"), "not_now", "aynı seviyeler değiştirilmez")
	await _drop(200)
	await _drop(700)
	assert_true(session.can_undo())
	assert_true(manager.use("swap"))
	assert_false(session.can_undo(), "değiştirmeden sonra geri al, sonraki bırakmaya kadar kapalı")


# --- Ek hamle ---

func test_extra_moves_continue_after_last_move() -> void:
	_setup(_lv({"moves": 2, "stars": [{"type": "complete"}, {"type": "moves_used_max", "value": 2}, {"type": "score", "value": 10}]}))
	await _drop(200)
	await _drop(700)
	assert_eq(session.state, GameSession.State.SETTLING)
	assert_true(manager.use("extra_moves"))
	assert_eq(session.state, GameSession.State.PLAYING)
	assert_eq(session.moves_left(), int(manager.def("extra_moves").amount))
	await physics_frames(int(GameSession.SETTLE_TIMEOUT_SEC * 60) + 30)
	assert_false(session.is_finished(), "ek hamle varken bölüm bitmez")


func test_extra_moves_survive_undo() -> void:
	_setup(_lv({"moves": 10}))
	await _drop(300)
	assert_true(manager.use("extra_moves"))
	assert_true(manager.use("undo"))
	assert_eq(session.moves, 0)
	assert_eq(session.moves_limit, 10 + int(manager.def("extra_moves").amount), "satın alınan hamleler geri al ile kaybolmaz")


# --- Temizle ---

func test_relieve_removes_small_buildings_only() -> void:
	_setup(_lv({"layout": [
		{"level": 1, "x": 100, "y": H - 50}, {"level": 2, "x": 300, "y": H - 65},
		{"level": 3, "x": 520, "y": H - 82}, {"level": 1, "x": 800, "y": H - 50},
	]}))
	var inv := Invariants.new()
	await run_checked(session, inv, 30)
	var score_before := session.score.score
	assert_true(manager.use("relieve"))
	assert_eq(session.board.building_count(), 1)
	assert_eq(session.board.buildings[0].level, 3)
	assert_eq(session.board.stats.cleared, 3)
	assert_eq(session.score.score, score_before, "temizlik puan vermez")
	assert_eq(manager.check("relieve"), "limit", "bölümde bir kez")
	await run_checked(session, inv, 60)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_relieve_needs_something_to_clear() -> void:
	_setup(_lv({"layout": [{"level": 4, "x": 450, "y": H - 102}]}))
	assert_eq(manager.check("relieve"), "not_now")
	assert_false(manager.use("relieve"))
	assert_eq(profile.booster_count("relieve"), 5, "etki olmayınca harcanmaz")


# --- Vinç ---

func test_crane_lift_and_redrop_costs_no_move() -> void:
	_setup(_lv({"layout": [{"level": 3, "x": 150, "y": H - 82}, {"level": 5, "x": 600, "y": H - 125}]}))
	var inv := Invariants.new()
	await run_checked(session, inv, 30)
	var queued := session.current_level()
	var target := session.board.building_at(Vector2(150, H - 82))
	assert_true(target != null and target.level == 3)
	assert_true(manager.use("crane", target))
	assert_eq(session.current_level(), 3, "alınan bina sıradaki olur")
	assert_eq(session.upcoming_levels()[0], queued)
	assert_eq(session.board.building_count(), 1)
	await run_checked(session, inv, 10)
	assert_true(session.try_drop(800))
	assert_eq(session.moves, 0, "yeniden bırakmak hamle harcamaz")
	assert_eq(session.current_level(), queued)
	await run_checked(session, inv, 120)
	assert_eq(session.board.building_count(), 2)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_crane_respects_max_level_and_hand() -> void:
	_setup(_lv({"layout": [{"level": 7, "x": 450, "y": H - 178}, {"level": 2, "x": 100, "y": H - 65}]}))
	var big := session.board.building_at(Vector2(450, H - 178))
	assert_false(manager.can_lift(big), "en fazla seviye %d alınabilir" % int(manager.def("crane").max_level))
	assert_false(manager.use("crane", big))
	var small := session.board.building_at(Vector2(100, H - 65))
	assert_true(manager.use("crane", small))
	assert_eq(manager.check("crane"), "not_now", "elde bina varken ikinci kez alınmaz")
	assert_eq(manager.check("swap"), "not_now", "elde bina varken değiştirilmez")


func test_undo_after_redrop_returns_building_to_hand() -> void:
	_setup(_lv({"layout": [{"level": 3, "x": 150, "y": H - 82}]}))
	await physics_frames(20)
	assert_true(manager.use("crane", session.board.buildings[0]))
	assert_true(session.try_drop(700))
	await physics_frames(60)
	assert_true(manager.use("undo"))
	assert_eq(session.held_level, 3, "geri al, binayı yeniden ele verir")
	assert_eq(session.board.building_count(), 0)


# --- Envanter, sınırlar, kötüye kullanım ---

func test_booster_is_spent_only_when_applied() -> void:
	_setup(_lv(), 1)
	assert_false(manager.use("undo"), "geri alınacak bırakma yok")
	assert_eq(profile.booster_count("undo"), 1)
	await _drop(450)
	assert_true(manager.use("undo"))
	assert_eq(profile.booster_count("undo"), 0)
	await _drop(450)
	assert_eq(manager.check("undo"), "none_owned")
	assert_false(manager.use("undo"))


func test_per_level_limit_resets_only_on_new_attempt() -> void:
	_setup(_lv())
	var limit := int(manager.def("undo").per_level)
	for i in limit:
		await _drop(200 + i * 100)
		assert_true(manager.use("undo"))
	await _drop(450)
	assert_eq(manager.check("undo"), "limit")
	# Geri al, kullanım sayacını geri getirmez (sayaç oturumda değil, yöneticide).
	assert_eq(manager.uses_left("undo"), 0)
	session.start_level(session.level, session.data)
	manager.reset_attempt()
	await _drop(450)
	assert_eq(manager.check("undo"), "", "yeni denemede sayaç sıfırlanır")


func test_boosters_disabled_in_free_play_and_when_locked() -> void:
	_setup(_lv())
	var lv := session.level
	session.start(5)
	for id in EconomyData.BOOSTER_IDS:
		assert_eq(manager.check(id), "free_play", id)
	assert_true(manager.visible_ids().is_empty(), "serbest oyunda çubuk boş")
	profile.progress.unlock_all = false
	session.start_level(lv, session.data)
	assert_true(manager.visible_ids().is_empty(), "hiçbir bölüm tamamlanmadıysa hepsi kilitli")
	assert_eq(manager.check("undo"), "locked")


func test_random_boosters_keep_invariants() -> void:
	# Kötüye kullanım/stres: rastgele bot her fırsatta rastgele güçlendirici dener.
	_setup(_lv({"moves": 60, "goals": [{"type": "build", "level": 9, "count": 1}]}), 50)
	var bot := SimBot.new(SimBot.Kind.RANDOM, 4242)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var inv := Invariants.new()
	var uses := 0
	var frames := 0
	while not session.is_finished() and frames < steps(60 * 45):
		await tree.physics_frame
		frames += 1
		inv.check(session)
		if rng.randf() < 0.01:
			# Kullanım sınırı dolunca yeni deneme gibi sıfırla (daha çok kullanım için).
			manager.used.clear()
			var id: String = EconomyData.BOOSTER_IDS[rng.randi() % EconomyData.BOOSTER_IDS.size()]
			var target: Building = null
			if not session.board.buildings.is_empty():
				target = session.board.buildings[rng.randi() % session.board.buildings.size()]
			if manager.use(id, target):
				uses += 1
		if session.can_drop() and session.try_drop(bot.choose_x(session)):
			pass
	assert_true(uses >= 10, "yeterince güçlendirici kullanılmalı (%d)" % uses)
	assert_true(inv.ok(), "\n".join(inv.violations))
	var spent := 0
	for id in EconomyData.BOOSTER_IDS:
		spent += 50 - profile.booster_count(id)
	assert_eq(spent, uses, "envanterden düşen adet, başarılı kullanım sayısına eşit")
