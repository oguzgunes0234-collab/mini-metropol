extends TestCase
## Puan ve zincir hesabı.

var data: GameData


func before_each() -> void:
	data = GameData.load_default()


func test_merge_points_come_from_data() -> void:
	var k := ScoreKeeper.new(data)
	assert_eq(k.on_merge(2), data.level_def(2).merge_score)
	assert_eq(k.score, data.level_def(2).merge_score)


func test_chain_bonus_applies_within_one_drop() -> void:
	var k := ScoreKeeper.new(data)
	k.on_drop()
	var first := k.on_merge(3)
	var second := k.on_merge(3)
	var bonus := float(data.section("merge").chain_bonus_per_step)
	assert_eq(first, data.level_def(3).merge_score)
	assert_eq(second, roundi(data.level_def(3).merge_score * (1.0 + bonus)))
	assert_eq(k.chain, 2)
	assert_eq(k.best_chain, 2)


func test_drop_resets_chain() -> void:
	var k := ScoreKeeper.new(data)
	k.on_merge(2)
	k.on_merge(2)
	k.on_drop()
	assert_eq(k.chain, 0)
	assert_eq(k.on_merge(2), data.level_def(2).merge_score)


func test_chain_bonus_is_capped() -> void:
	var k := ScoreKeeper.new(data)
	var cap := int(data.section("merge").chain_bonus_max_steps)
	assert_eq(k.multiplier(cap + 1), k.multiplier(cap + 50))


func test_landmark_bonus_is_flat() -> void:
	var k := ScoreKeeper.new(data)
	var bonus := int(data.section("final_level").bonus_score)
	k.on_merge(2)
	assert_eq(k.on_landmark(), bonus)
	assert_eq(k.landmarks, 1)


func test_state_roundtrip() -> void:
	var k := ScoreKeeper.new(data)
	k.on_merge(4)
	k.on_merge(5)
	var s := k.get_state()
	var k2 := ScoreKeeper.new(data)
	k2.set_state(s)
	assert_eq(k2.get_state(), s)
