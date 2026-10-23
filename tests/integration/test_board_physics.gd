extends TestCase
## Gerçek fizik motoruyla birleşme, sınırlar ve temizleme testleri.

const W := 900.0
const H := 1280.0


func _spawn(s: GameSession, inv: Invariants, level: int, pos: Vector2, vel := Vector2.ZERO, origin := "test") -> Building:
	inv.extra_value += GameData.value_of(level)
	return s.board.spawn(level, pos, vel, origin)


func _levels(s: GameSession) -> Array:
	var out := []
	for b in s.board.buildings:
		out.append(b.level)
	out.sort()
	return out


func test_two_same_buildings_merge_exactly_once() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r := s.data.radius(1)
	_spawn(s, inv, 1, Vector2(450, H - r))
	_spawn(s, inv, 1, Vector2(450, H - r * 3 - 10))
	await run_checked(s, inv, 90)
	assert_eq(_levels(s), [2], "iki kulübe bir küçük ev olmalı")
	assert_eq(s.event_log.size(), 1, "tek birleşme olayı")
	assert_eq(s.score.score, s.data.level_def(2).merge_score, "puan bir kez eklenmeli")
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_three_same_buildings_make_one_merge_and_one_leftover() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r := s.data.radius(1)
	for i in 3:
		_spawn(s, inv, 1, Vector2(450, H - r - i * (r * 2 + 10)))
	await run_checked(s, inv, 120)
	assert_eq(_levels(s), [1, 2])
	assert_eq(s.board.stats.merges, 1)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_four_same_buildings_cascade_to_level_three() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r := s.data.radius(1)
	for i in 4:
		_spawn(s, inv, 1, Vector2(450, H - r - i * (r * 2 + 10)))
	await run_checked(s, inv, 180)
	assert_eq(_levels(s), [3])
	assert_eq(s.board.stats.merges, 3)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_chain_reaction_gets_chain_bonus() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r1 := s.data.radius(1)
	var r2 := s.data.radius(2)
	_spawn(s, inv, 2, Vector2(450, H - r2))
	_spawn(s, inv, 1, Vector2(450, H - r2 * 2 - r1 - 2))
	await run_checked(s, inv, 30)
	s.score.on_drop()
	s.board.drop(1, 450)
	await run_checked(s, inv, 180)
	assert_eq(_levels(s), [3])
	assert_eq(s.event_log.size(), 2)
	if s.event_log.size() == 2:
		assert_eq(s.event_log[0].chain, 1)
		assert_eq(s.event_log[1].chain, 2)
	var expected := s.score.points_for(2, 1) + s.score.points_for(3, 2)
	assert_eq(s.score.score, expected)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_two_max_level_buildings_complete_landmark() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r := s.data.radius(9)
	_spawn(s, inv, 9, Vector2(450, H - r))
	_spawn(s, inv, 9, Vector2(450, H - r * 3 + 4))
	await run_checked(s, inv, 60)
	assert_eq(s.board.building_count(), 0, "iki ikonik kule anıt olarak kaldırılmalı")
	assert_eq(s.board.stats.landmarks, 1)
	assert_eq(s.score.score, int(s.data.section("final_level").bonus_score))
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_max_level_with_none_rule_stays() -> void:
	var d := default_dicts()
	d.rules.final_level.rule = "none"
	var data := GameData.from_dicts(d.buildings, d.rules)
	var s := make_session(data)
	var inv := Invariants.new()
	var r := data.radius(9)
	_spawn(s, inv, 9, Vector2(450, H - r))
	_spawn(s, inv, 9, Vector2(450, H - r * 3 + 4))
	await run_checked(s, inv, 120)
	assert_eq(_levels(s), [9, 9])
	assert_eq(s.score.score, 0)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_merge_next_to_wall_stays_inside() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r8 := s.data.radius(8)
	_spawn(s, inv, 8, Vector2(r8, H - r8))
	_spawn(s, inv, 8, Vector2(r8, H - r8 * 3 - 10))
	await run_checked(s, inv, 150)
	assert_eq(_levels(s), [9])
	if s.board.building_count() == 1:
		var b := s.board.buildings[0]
		assert_true(b.position.x >= s.data.radius(9) - 2.0, "yeni bina duvarın içinde: x=%f" % b.position.x)
	assert_eq(s.board.stats.out_of_bounds, 0)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_drop_position_is_clamped_to_walls() -> void:
	var s := make_session()
	var r := s.data.radius(4)
	assert_near(s.board.drop(4, -500).position.x, r, 0.001)
	assert_near(s.board.drop(4, 99999).position.x, W - r, 0.001)


func test_buildings_never_escape_even_when_flung() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 24:
		var level := rng.randi_range(1, 4)
		var r := s.data.radius(level)
		var pos := Vector2(rng.randf_range(r, W - r), rng.randf_range(-600, H - r))
		var vel := Vector2(rng.randf_range(-6000, 6000), rng.randf_range(-6000, 6000))
		_spawn(s, inv, level, pos, vel)
	var max_speed := float(s.data.section("physics").max_speed)
	for i in 300:
		await tree.physics_frame
		inv.check(s)
		for b in s.board.buildings:
			if b.linear_velocity.length() > max_speed * 1.6:
				fail("hız sınırı aşıldı: %f" % b.linear_velocity.length())
				break
	assert_eq(s.board.stats.out_of_bounds, 0)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_restart_leaves_nothing_behind() -> void:
	var s := make_session()
	var inv := Invariants.new()
	await physics_frames(2)
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		var level := rng.randi_range(1, 5)
		_spawn(s, inv, level, Vector2(rng.randf_range(100, 800), rng.randf_range(-500, 1100)))
	await run_checked(s, inv, 90)
	s.start(5)
	await physics_frames(2)
	assert_eq(s.board.building_count(), 0)
	assert_eq(s.board.get_node("Buildings").get_child_count(), 0, "sahnede gövde kalmamalı")
	assert_eq(s.score.score, 0)
	assert_eq(s.moves, 0)
	assert_eq(s.board.stats.merges, 0)
	assert_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans_before, "artık (orphan) düğüm kalmamalı")
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_building_pushed_through_wall_is_rescued_not_lost() -> void:
	var s := make_session()
	var inv := Invariants.new()
	var r := s.data.radius(1)
	# Merkezi zemin ve duvar çizgisini geçmiş binalar (kayayla duvar arasında ezilmeyi taklit eder)
	_spawn(s, inv, 1, Vector2(450, H + r * 0.3))
	_spawn(s, inv, 2, Vector2(-s.data.radius(2) * 0.2, H - 300))
	await run_checked(s, inv, 3)
	assert_eq(s.board.building_count(), 2, "bina kaybolmamalı")
	assert_eq(s.board.stats.out_of_bounds, 0)
	assert_true(s.board.stats.rescues >= 2, "iki bina da geri konmalı")
	for b in s.board.buildings:
		var rr := b.current_radius()
		assert_true(b.position.y <= H - rr + 1.0 and b.position.x >= rr - 1.0, "bina alanın içinde: %s" % b.position)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_rescue_uses_free_spot_not_occupied_one() -> void:
	# Sınırın hemen içi büyük bir binayla dolu: kurtarılan bina oraya konarsa
	# yığın onu yeniden duvara iter (döngü). Bunun yerine yukarıdaki boş yere konur.
	var s := make_session()
	var inv := Invariants.new()
	var big := s.data.radius(5)
	var r := s.data.radius(1)
	_spawn(s, inv, 5, Vector2(big, H - big))
	var small := _spawn(s, inv, 1, Vector2(-r * 0.2, H - r))
	s.board._rescue_deep_penetrations()
	assert_eq(s.board.stats.rescues, 1)
	var other: Building = s.board.buildings[0]
	assert_true(small.position.distance_to(other.position) >= r + big - 1.0, "boş yere konmalı: %s" % small.position)
	assert_near(small.position.x, r, 0.01, "duvarın hemen içinde, aynı sütunda")
	assert_true(small.position.y < H - r, "yukarıda")
	await run_checked(s, inv, 120)
	assert_eq(s.board.building_count(), 2)
	assert_true(s.board.stats.rescues <= 1, "döngü yok: %d kurtarma" % s.board.stats.rescues)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_shallow_penetration_is_left_to_physics() -> void:
	var s := make_session()
	var r := s.data.radius(1)
	# Sığ gömülme kurtarmayı tetiklemez; fizik çözer.
	s.board.spawn(1, Vector2(450, H - r * 0.6), Vector2.ZERO, "test")
	await physics_frames(30)
	assert_eq(s.board.stats.rescues, 0)
	assert_true(s.board.buildings[0].position.y <= H - r + 2.0)


func test_bounds_are_enforced_after_game_over() -> void:
	var s := make_session()
	var r := s.data.radius(1)
	s.board.end_game("danger")
	s.board.spawn(1, Vector2(450, H + r * 0.3), Vector2.ZERO, "test")
	await physics_frames(3)
	assert_eq(s.board.building_count(), 1)
	assert_true(s.board.buildings[0].position.y <= H - r + 1.0, "oyun bitse de bina alanın içinde kalmalı")
