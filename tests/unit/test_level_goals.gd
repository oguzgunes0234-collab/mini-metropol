extends TestCase
## Bölüm hedefleri ve yıldız hesabı.


func test_build_counts_only_exact_level() -> void:
	var g := LevelGoals.new([{"type": "build", "level": 3, "count": 2}])
	g.on_merge(2)
	g.on_merge(4)
	assert_eq(g.progress[0], 0)
	g.on_merge(3)
	assert_false(g.all_done())
	g.on_merge(3)
	assert_true(g.all_done())


func test_score_and_chain_use_best_value() -> void:
	var g := LevelGoals.new([{"type": "score", "value": 100}, {"type": "chain", "value": 3}])
	g.on_score(60)
	g.on_chain(2)
	assert_false(g.all_done())
	g.on_score(120)
	g.on_chain(3)
	assert_true(g.all_done())
	g.on_chain(1)
	assert_true(g.is_done(1), "en iyi zincir geri düşmez")


func test_all_goals_required() -> void:
	var g := LevelGoals.new([{"type": "build", "level": 2, "count": 1}, {"type": "landmark", "count": 1}])
	g.on_merge(2)
	assert_false(g.all_done())
	g.on_landmark()
	assert_true(g.all_done())


func test_summary_caps_progress_at_target() -> void:
	var g := LevelGoals.new([{"type": "score", "value": 50}])
	g.on_score(80)
	var s := g.summary()
	assert_eq(s[0].progress, 50)
	assert_eq(s[0].target, 50)
	assert_true(s[0].done)


func test_state_roundtrip() -> void:
	var g := LevelGoals.new([{"type": "build", "level": 2, "count": 3}])
	g.on_merge(2)
	var g2 := LevelGoals.new([{"type": "build", "level": 2, "count": 3}])
	g2.set_state(JSON.parse_string(JSON.stringify(g.get_state())))
	assert_eq(g2.progress, g.progress)


func test_stars() -> void:
	var stars := [{"type": "complete"}, {"type": "moves_used_max", "value": 10}, {"type": "score", "value": 200}]
	assert_eq(LevelGoals.star_flags(stars, true, 10, 150, 1), [true, true, false] as Array[bool])
	assert_eq(LevelGoals.star_flags(stars, true, 11, 250, 1), [true, false, true] as Array[bool])
	assert_eq(LevelGoals.star_count(LevelGoals.star_flags(stars, true, 5, 500, 1)), 3)
	assert_eq(LevelGoals.star_count(LevelGoals.star_flags(stars, false, 5, 500, 1)), 0, "tamamlanmadan yıldız yok")


func test_chain_star() -> void:
	var stars := [{"type": "complete"}, {"type": "chain", "value": 3}, {"type": "chain", "value": 4}]
	assert_eq(LevelGoals.star_count(LevelGoals.star_flags(stars, true, 1, 0, 3)), 2)
