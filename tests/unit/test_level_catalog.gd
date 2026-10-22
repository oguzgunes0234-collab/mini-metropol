extends TestCase
## Bölüm verisinin yüklenmesi ve doğrulanması.


func _levels_dict() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LevelCatalog.LEVELS_PATH))


func _catalog(d: Dictionary) -> LevelCatalog:
	return LevelCatalog.from_dict(d, GameData.load_default())


func _errors(d: Dictionary) -> String:
	return "\n".join(_catalog(d).errors)


func test_default_levels_are_valid() -> void:
	var c := LevelCatalog.load_default()
	assert_true(c.is_valid(), "\n".join(c.errors))
	assert_true(c.count() >= 10, "en az 10 bölüm")


func test_every_name_and_hint_is_translated() -> void:
	var c := LevelCatalog.load_default()
	for lv in c.levels:
		for key in [lv.name_key, lv.hint_key]:
			for loc in ["tr", "en"]:
				TranslationServer.set_locale(loc)
				assert_ne(tr(key), key, "%s için %s çevirisi yok" % [key, loc])
	TranslationServer.set_locale("en")


func test_level_rules_override_base() -> void:
	var c := LevelCatalog.load_default()
	var narrow := c.get_level("1-06")
	assert_eq(float(c.data_for(narrow).section("board").width), 720.0)
	assert_eq(float(c.base.section("board").width), 900.0, "genel kural değişmemeli")


func test_next_id() -> void:
	var c := LevelCatalog.load_default()
	assert_eq(c.next_id("1-01"), "1-02")
	assert_eq(c.next_id(c.levels[c.count() - 1].id), "")


func test_duplicate_id_is_reported() -> void:
	var d := _levels_dict()
	d.levels[1].id = d.levels[0].id
	assert_true(_errors(d).contains("tekrar"))


func test_unknown_rule_key_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].rules = {"drop": {"spawn_levelz": [1]}}
	assert_true(_errors(d).contains("bilinmeyen"))


func test_invalid_rule_value_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].rules = {"board": {"width": 200}}
	assert_false(_catalog(d).is_valid())


func test_goal_level_out_of_range_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].goals = [{"type": "build", "level": 12, "count": 1}]
	assert_false(_catalog(d).is_valid())


func test_build_level_one_is_not_a_goal() -> void:
	var d := _levels_dict()
	d.levels[0].goals = [{"type": "build", "level": 1, "count": 1}]
	assert_false(_catalog(d).is_valid(), "seviye 1 birleşmeyle üretilemez")


func test_first_star_must_be_complete() -> void:
	var d := _levels_dict()
	d.levels[0].stars = [{"type": "score", "value": 10}, {"type": "complete"}, {"type": "score", "value": 20}]
	assert_false(_catalog(d).is_valid())


func test_star_moves_cannot_exceed_limit() -> void:
	var d := _levels_dict()
	d.levels[0].stars[1] = {"type": "moves_used_max", "value": 999}
	assert_false(_catalog(d).is_valid())


func test_unlock_must_reference_earlier_level() -> void:
	var d := _levels_dict()
	d.levels[0].unlock = {"after": "9-99"}
	assert_false(_catalog(d).is_valid())


func test_layout_outside_board_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].layout = [{"level": 3, "x": 10, "y": 1200}]
	assert_false(_catalog(d).is_valid())


func test_layout_same_level_touching_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].layout = [{"level": 1, "x": 300, "y": 1230}, {"level": 1, "x": 400, "y": 1230}]
	assert_true(_errors(d).contains("aynı seviyedeki"))


func test_obstacle_in_drop_area_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].obstacles = [{"shape": "circle", "x": 450, "y": 100, "r": 50}]
	assert_false(_catalog(d).is_valid())


func test_bad_spawn_sequence_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].spawn_sequence = [1, 9]
	assert_false(_catalog(d).is_valid())
