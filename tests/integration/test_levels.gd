extends TestCase
## Bölüm akışı gerçek fizikle: kurulum, kazanma, kaybetme, yıldız, yeniden deneme.

const H := 1280.0


func _wait_finished(s: GameSession, max_frames: int = 900) -> int:
	var frames := 0
	while not s.is_finished() and frames < steps(max_frames):
		await tree.physics_frame
		frames += 1
	return frames


func test_level_setup_applies_board_layout_obstacles_and_moves() -> void:
	var s := make_level_session("1-06")
	assert_eq(s.board.width, 720.0, "dar bölüm")
	assert_eq(s.moves_limit, int(s.level.moves))
	assert_eq(s.moves_left(), int(s.level.moves))
	s = make_level_session("1-04")
	assert_eq(s.board.building_count(), 2, "başlangıç binaları")
	assert_eq(s.board.stats.placed_value, GameData.value_of(2) + GameData.value_of(1))
	s = make_level_session("1-07")
	assert_eq(s.board.obstacles.size(), 2)


func test_scripted_sequence_comes_first() -> void:
	var s := make_level_session("1-01")
	var seen: Array[int] = []
	for i in 4:
		seen.append(s.current_level())
		s.queue.advance()
	assert_eq(seen, [1, 1, 1, 1] as Array[int])


func test_obstacles_block_buildings() -> void:
	var s := make_level_session(level_dict({
		"obstacles": [{"shape": "rect", "x": 450, "y": 900, "w": 700, "h": 40}],
		"goals": [{"type": "build", "level": 9, "count": 1}],
		"moves": 50,
	}))
	s.try_drop(450)
	await physics_frames(150)
	var b := s.board.buildings[0]
	assert_true(b.position.y < 900, "bina engelin üstünde kalmalı: y=%f" % b.position.y)


func test_win_when_goal_reached() -> void:
	var s := make_level_session(level_dict({
		"spawn_sequence": [1],
		"layout": [{"level": 1, "x": 450, "y": H - 50}],
	}))
	var results := []
	s.finished.connect(func(r: Dictionary): results.append(r))
	assert_true(s.try_drop(450))
	await _wait_finished(s)
	assert_eq(s.state, GameSession.State.WON)
	assert_eq(results.size(), 1, "sonuç bir kez bildirilmeli")
	var r: Dictionary = results[0]
	assert_true(r.won)
	assert_eq(r.reason, "goals")
	assert_eq(r.moves_used, 1)
	assert_eq(r.star_flags, [true, true, true] as Array[bool], "1 hamle ≤ 5, puan 10 ≥ 10")
	assert_eq(r.stars, 3)
	assert_false(s.board.active, "kazanınca alan durur")
	assert_false(s.try_drop(450))


func test_merge_after_last_move_still_counts() -> void:
	var s := make_level_session(level_dict({
		"moves": 1,
		"stars": [{"type": "complete"}, {"type": "moves_used_max", "value": 1}, {"type": "score", "value": 10}],
		"spawn_sequence": [1],
		"layout": [{"level": 1, "x": 450, "y": H - 50}],
	}))
	assert_true(s.try_drop(450))
	assert_eq(s.state, GameSession.State.SETTLING, "son hamleden sonra bekleme")
	await _wait_finished(s)
	assert_eq(s.state, GameSession.State.WON, "son bırakmanın birleşmesi hedefi tamamlar")


func test_lose_when_out_of_moves_after_settling() -> void:
	var s := make_level_session(level_dict({
		"moves": 2,
		"goals": [{"type": "build", "level": 5, "count": 1}],
		"stars": [{"type": "complete"}, {"type": "moves_used_max", "value": 2}, {"type": "score", "value": 10}],
		"spawn_sequence": [1, 2],
	}))
	s.try_drop(200)
	await wait_cooldown(s)
	s.try_drop(700)
	assert_eq(s.state, GameSession.State.SETTLING)
	var frames := await _wait_finished(s)
	assert_eq(s.state, GameSession.State.LOST)
	assert_eq(s.result.reason, "out_of_moves")
	assert_eq(s.result.stars, 0)
	assert_true(frames >= ceili(GameSession.SETTLE_HOLD_SEC * Engine.physics_ticks_per_second), "binaların durması beklenmeli")
	assert_true(s.board.is_settled())


func test_lose_when_lot_overflows_in_level() -> void:
	var s := make_level_session(level_dict({
		"moves": 50,
		"goals": [{"type": "build", "level": 9, "count": 1}],
		"rules": {"final_level": {"rule": "none"}},
	}))
	var r := s.data.radius(9)
	for i in 5:
		var x := r + 10.0 if i % 2 == 0 else s.board.width - r - 10.0
		s.board.spawn(9, Vector2(x, H - r - i * 280.0), Vector2.ZERO, "test")
	await _wait_finished(s)
	assert_eq(s.state, GameSession.State.LOST)
	assert_eq(s.result.reason, "danger")


func test_retry_resets_level_cleanly() -> void:
	var s := make_level_session("1-07")
	for i in 6:
		await wait_cooldown(s)
		s.try_drop(150 + i * 110)
	await physics_frames(60)
	s.start_level(s.level, LevelCatalog.load_default().data_for(s.level))
	await physics_frames(2)
	assert_eq(s.board.building_count(), 0)
	assert_eq(s.moves, 0)
	assert_eq(s.score.score, 0)
	assert_eq(s.goals.progress, [0] as Array[int])
	var walls := 0
	for c in s.board.get_children():
		if c is StaticBody2D:
			walls += 1
			assert_eq(c.get_child_count(), 4 + 2, "duvarlar + 2 kaya, tekrar eklenmemeli")
	assert_eq(walls, 1, "tek duvar gövdesi")


func test_snapshot_includes_goal_progress() -> void:
	var s := make_level_session(level_dict({
		"moves": 20,
		"goals": [{"type": "build", "level": 2, "count": 5}],
		"spawn_sequence": [1, 1, 1, 1],
	}))
	for i in 2:
		await wait_cooldown(s)
		s.try_drop(450)
	await physics_frames(90)
	assert_eq(s.goals.progress[0], 1)
	var snap := s.capture_snapshot()
	for i in 2:
		await wait_cooldown(s)
		s.try_drop(200)
	await physics_frames(90)
	s.restore_snapshot(JSON.parse_string(JSON.stringify(snap)))
	assert_eq(s.goals.progress[0], 1)
	assert_eq(s.moves, 2)


func test_all_levels_start_without_errors() -> void:
	var cat := LevelCatalog.load_default()
	var s := make_session()
	for lv in cat.levels:
		s.start_level(lv, cat.data_for(lv))
		await physics_frames(30)
		assert_eq(s.state, GameSession.State.PLAYING, "%s başlangıçta oynanabilir olmalı" % lv.id)
		assert_eq(s.board.building_count(), lv.layout.size(), "%s başlangıç binaları birleşmemeli" % lv.id)
