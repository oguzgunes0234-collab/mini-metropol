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


func _regions_dict() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LevelCatalog.REGIONS_PATH))


func test_default_regions_are_valid_and_linked() -> void:
	var c := LevelCatalog.load_default()
	assert_true(c.regions.size() >= 3)
	for r in c.regions:
		if not r.coming_soon:
			assert_true(c.levels_in_region(r.id).size() > 0, "%s bölgesinde bölüm olmalı" % r.id)
		for loc in ["tr", "en"]:
			TranslationServer.set_locale(loc)
			assert_ne(tr(r.name_key), r.name_key, "%s için %s çevirisi yok" % [r.name_key, loc])
	TranslationServer.set_locale("en")


func test_region_unlock_needs_level_and_stars() -> void:
	var c := LevelCatalog.load_default()
	var coast := c.region("coast")
	var p := Progress.new()
	assert_false(c.is_region_unlocked(coast, p))
	# Bölge 1'in son bölümü tamamlandı ama yıldız yetersiz
	p.record({"level_id": coast.unlock_after, "won": true, "stars": 1, "score": 0})
	assert_eq(p.total_stars() < coast.unlock_stars, true)
	assert_false(c.is_region_unlocked(coast, p), "yıldız yetmezse kilitli kalır")
	assert_false(c.is_unlocked(c.levels_in_region("coast")[0], p))
	# Yeterli yıldız
	for lv in c.levels_in_region("starter"):
		p.record({"level_id": lv.id, "won": true, "stars": 2, "score": 0})
	assert_true(c.is_region_unlocked(coast, p))
	assert_true(c.is_unlocked(c.levels_in_region("coast")[0], p))
	assert_false(c.is_unlocked(c.levels_in_region("coast")[1], p), "bölge içinde sıra korunur")


func test_coming_soon_region_never_unlocks() -> void:
	var c := LevelCatalog.load_default()
	var p := Progress.new()
	p.unlock_all = true
	for r in c.regions:
		if r.coming_soon:
			assert_false(c.is_region_unlocked(r, p))


func test_level_with_unknown_region_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].region = "atlantis"
	var c := LevelCatalog.from_dict(d, GameData.load_default(), _regions_dict())
	assert_true("\n".join(c.errors).contains("atlantis"))


func test_region_with_unknown_unlock_level_is_reported() -> void:
	var r := _regions_dict()
	r.regions[1].unlock.after_level = "9-99"
	var c := LevelCatalog.from_dict(_levels_dict(), GameData.load_default(), r)
	assert_true("\n".join(c.errors).contains("9-99"))


func test_level_in_coming_soon_region_is_reported() -> void:
	var d := _levels_dict()
	d.levels[0].region = "green"
	var c := LevelCatalog.from_dict(d, GameData.load_default(), _regions_dict())
	assert_true("\n".join(c.errors).contains("coming_soon"))


func test_level_booster_reward_is_validated() -> void:
	var d := _levels_dict()
	d.levels[0].rewards.boosters = {"roket": 1}
	assert_true(_errors(d).contains("roket"))
	d.levels[0].rewards.boosters = {"undo": 0}
	assert_false(_catalog(d).is_valid(), "adet en az 1")
	d.levels[0].rewards.boosters = {"undo": 2}
	assert_true(_catalog(d).is_valid())
