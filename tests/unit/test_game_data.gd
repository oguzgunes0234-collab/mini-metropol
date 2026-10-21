extends TestCase
## Veri dosyalarının yüklenmesi ve doğrulanması.


func test_default_data_is_valid() -> void:
	var data := GameData.load_default()
	assert_true(data.is_valid(), "hatalar: %s" % ", ".join(data.errors))
	assert_eq(data.max_level, 9)


func test_levels_are_ordered_and_growing() -> void:
	var data := GameData.load_default()
	for i in data.max_level:
		assert_eq(data.levels[i].level, i + 1)
		if i > 0:
			assert_true(data.levels[i].radius > data.levels[i - 1].radius, "seviye %d yarıçapı" % (i + 1))


func test_missing_file_is_reported() -> void:
	var data := GameData.load_from_files("res://data/yok.json", GameData.RULES_PATH)
	assert_false(data.is_valid())


func test_wrong_level_order_is_reported() -> void:
	var d := default_dicts()
	d.buildings.levels[2].level = 7
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_non_growing_radius_is_reported() -> void:
	var d := default_dicts()
	d.buildings.levels[4].radius = 10
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_bad_color_is_reported() -> void:
	var d := default_dicts()
	d.buildings.levels[0].color = "kırmızımsı"
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_missing_rule_section_is_reported() -> void:
	var d := default_dicts()
	d.rules.erase("merge")
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_spawn_weights_must_match_levels() -> void:
	var d := default_dicts()
	d.rules.drop.spawn_weights = [1, 2]
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_spawning_max_level_is_not_allowed() -> void:
	var d := default_dicts()
	d.rules.drop.spawn_levels = [1, 9]
	d.rules.drop.spawn_weights = [1, 1]
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_unknown_final_rule_is_reported() -> void:
	var d := default_dicts()
	d.rules.final_level.rule = "patlat"
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


func test_board_must_fit_largest_building() -> void:
	var d := default_dicts()
	d.rules.board.width = 300
	assert_false(GameData.from_dicts(d.buildings, d.rules).is_valid())


## Kabul ölçütü: değerler yalnızca veriden gelir, kod değişikliği gerekmez.
func test_scores_come_from_data() -> void:
	var d := default_dicts()
	d.buildings.levels[1].merge_score = 777
	var data := GameData.from_dicts(d.buildings, d.rules)
	assert_true(data.is_valid())
	var keeper := ScoreKeeper.new(data)
	assert_eq(keeper.on_merge(2), 777)


func test_radius_comes_from_data() -> void:
	var d := default_dicts()
	d.buildings.levels[0].radius = 33
	var data := GameData.from_dicts(d.buildings, d.rules)
	assert_eq(data.radius(1), 33.0)
