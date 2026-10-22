extends TestCase
## Oyun oturumu: bırakma sırası, bekleme süresi, oyun sonu, anlık görüntü.

const H := 1280.0


func test_drops_follow_queue_and_count_moves() -> void:
	var s := make_session(null, 77)
	var expected := SpawnQueue.from_data(s.data, 77)
	var dropped_levels: Array[int] = []
	s.dropped.connect(func(level: int, _b: Building): dropped_levels.append(level))
	var want: Array[int] = []
	for i in 6:
		want.append(expected.advance())
		await wait_cooldown(s)
		assert_true(s.try_drop(150 + i * 120))
	assert_eq(dropped_levels, want)
	assert_eq(s.moves, 6)


func test_cooldown_blocks_rapid_drops() -> void:
	var s := make_session()
	assert_true(s.try_drop(450))
	assert_false(s.try_drop(450), "bekleme süresi içinde ikinci bırakma reddedilmeli")
	assert_eq(s.moves, 1)
	var frames := ceili(float(s.data.section("drop").cooldown_sec) * 60.0) + 1
	await physics_frames(frames)
	assert_true(s.try_drop(450))
	assert_eq(s.moves, 2)


func test_restart_with_same_seed_gives_same_queue() -> void:
	var s := make_session(null, 9)
	var first := [s.queue.current(), s.queue.upcoming()]
	s.try_drop(300)
	s.start(9)
	assert_eq([s.queue.current(), s.queue.upcoming()], first)


## Son seviye birleşmesin diye "none" kuralıyla, alanı taşıracak kadar
## ikonik kuleyi zikzak bir sütun hâlinde yerleştirir.
func _tower_session(danger_time: float = -1.0) -> GameSession:
	var d := default_dicts()
	d.rules.final_level.rule = "none"
	if danger_time > 0.0:
		d.rules.game_over.danger_time_sec = danger_time
	var s := make_session(GameData.from_dicts(d.buildings, d.rules))
	var r := s.data.radius(9)
	# Yatayda 400 px aralıklı zikzak: dikeyde 280 px aralık binaları
	# başlangıçta üst üste bindirmez; 5 kule tehlike çizgisini aşar.
	for i in 5:
		var x := r + 10.0 if i % 2 == 0 else s.board.width - r - 10.0
		s.board.spawn(9, Vector2(x, H - r - i * 280.0), Vector2.ZERO, "test")
	return s


func test_game_over_when_lot_overflows() -> void:
	var s := _tower_session()
	var finished_count := [0]
	s.finished.connect(func(_result: Dictionary): finished_count[0] += 1)
	var limit := 60 * 15
	var frames := 0
	while s.state == GameSession.State.PLAYING and frames < limit:
		await tree.physics_frame
		frames += 1
	assert_eq(s.state, GameSession.State.LOST, "alan taşınca oyun bitmeli")
	await physics_frames(30)
	assert_eq(finished_count[0], 1, "oyun sonu bir kez bildirilmeli")
	assert_false(s.board.active)
	assert_false(s.try_drop(450), "oyun bitince bırakma yapılamamalı")
	# Tehlike süresi dolmadan bitmemeli.
	var danger_frames := float(s.data.section("game_over").danger_time_sec) * 60.0
	assert_true(frames >= danger_frames, "oyun sonu %d karede geldi, en az %d olmalı" % [frames, danger_frames])


func test_drop_into_full_lot_ends_game() -> void:
	# Tehlike süresini uzatıp yalnızca "bırakma noktası dolu" kuralını sınıyoruz.
	var s := _tower_session(1000.0)
	await physics_frames(240)
	assert_eq(s.state, GameSession.State.PLAYING)
	var top: Building = null
	for b in s.board.buildings:
		if top == null or b.position.y < top.position.y:
			top = b
	var count := s.board.building_count()
	assert_false(s.try_drop(top.position.x), "dolu noktaya bırakılmamalı")
	assert_eq(s.state, GameSession.State.LOST)
	assert_eq(s.board.game_over_reason, "no_room")
	assert_eq(s.board.building_count(), count, "yeni bina oluşmamalı")
	assert_eq(s.moves, 0)


func test_drop_waits_while_previous_building_is_still_at_drop_point() -> void:
	var d := default_dicts()
	d.rules.drop.cooldown_sec = 0
	var s := make_session(GameData.from_dicts(d.buildings, d.rules))
	assert_true(s.try_drop(450))
	assert_false(s.try_drop(450), "önceki bina hâlâ bırakma noktasında")
	assert_eq(s.state, GameSession.State.PLAYING, "geçici engel oyunu bitirmemeli")
	assert_eq(s.moves, 1)
	await physics_frames(40)
	assert_true(s.try_drop(450), "önceki bina düştükten sonra bırakılabilmeli")
	assert_eq(s.moves, 2)


func test_fresh_drop_does_not_end_game() -> void:
	var s := make_session()
	s.try_drop(450)
	await physics_frames(400)
	assert_eq(s.state, GameSession.State.PLAYING)
	assert_near(s.board.danger_time, 0.0, 0.0001)


func test_brief_crossing_does_not_end_game() -> void:
	var s := make_session()
	s.board.spawn(1, Vector2(450, -150), Vector2.ZERO, "merge")
	await physics_frames(400)
	assert_eq(s.state, GameSession.State.PLAYING)
	assert_near(s.board.danger_time, 0.0, 0.0001)


func _summary(s: GameSession) -> Dictionary:
	var list := []
	for b in s.board.buildings:
		list.append([b.level, snappedf(b.position.x, 0.01), snappedf(b.position.y, 0.01), snappedf(b.rotation, 0.0001)])
	list.sort()
	return {
		"buildings": list,
		"score": s.score.get_state(),
		"moves": s.moves,
		"queue": [s.queue.current(), s.queue.upcoming()],
		"state": s.state,
	}


func test_snapshot_restores_exact_state() -> void:
	var s := make_session(null, 11)
	for i in 10:
		await wait_cooldown(s)
		s.try_drop(120 + (i * 97) % 660)
	await physics_frames(120)
	var snap := s.capture_snapshot()
	var before := _summary(s)
	assert_true(before.buildings.size() > 0)
	# Sıradaki bırakmaların seviyeleri (geri aldıktan sonra aynı olmalı).
	var next_levels := []
	for i in 5:
		await wait_cooldown(s)
		next_levels.append(s.current_level())
		s.try_drop(200 + i * 100)
	await physics_frames(60)

	s.restore_snapshot(snap)
	assert_eq(_summary(s), before, "geri yükleme sonrası durum aynı olmalı")

	var replay := []
	for i in 5:
		await wait_cooldown(s)
		replay.append(s.current_level())
		s.try_drop(200 + i * 100)
	assert_eq(replay, next_levels, "sıradaki binalar da geri yüklenmeli")


func test_snapshot_survives_json_roundtrip() -> void:
	var s := make_session(null, 21)
	for i in 6:
		await wait_cooldown(s)
		s.try_drop(150 + i * 110)
	await physics_frames(90)
	var before := _summary(s)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(s.capture_snapshot()))
	s.start(999)
	s.restore_snapshot(snap)
	assert_eq(_summary(s), before)
