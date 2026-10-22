extends TestCase
## Oyuncu ilerlemesi: en iyi sonuç, kilitler, başarısızlık sayacı.


func _result(id: String, won: bool, stars: int, score: int) -> Dictionary:
	return {"level_id": id, "won": won, "stars": stars, "score": score}


func test_best_result_is_kept() -> void:
	var p := Progress.new()
	p.record(_result("1-01", true, 2, 100))
	p.record(_result("1-01", true, 1, 300))
	p.record(_result("1-01", false, 0, 999))
	assert_eq(p.stars("1-01"), 2, "en iyi yıldız korunur")
	assert_eq(p.best_score("1-01"), 300, "kaybedilen oyun en iyi puanı değiştirmez")
	assert_true(p.is_completed("1-01"))


func test_unlocking_follows_completion() -> void:
	var cat := LevelCatalog.load_default()
	var p := Progress.new()
	assert_true(cat.is_unlocked(cat.levels[0], p))
	assert_false(cat.is_unlocked(cat.levels[1], p))
	p.record(_result(cat.levels[0].id, false, 0, 10))
	assert_false(cat.is_unlocked(cat.levels[1], p), "kaybetmek açmaz")
	p.record(_result(cat.levels[0].id, true, 1, 10))
	assert_true(cat.is_unlocked(cat.levels[1], p))
	p.unlock_all = true
	assert_true(cat.is_unlocked(cat.levels[cat.count() - 1], p))


func test_fail_counter_resets_on_win() -> void:
	var p := Progress.new()
	p.record(_result("1-02", false, 0, 0))
	p.record(_result("1-02", false, 0, 0))
	assert_eq(p.fail_count("1-02"), 2)
	p.record(_result("1-02", true, 1, 50))
	assert_eq(p.fail_count("1-02"), 0)


func test_total_stars_and_free_best() -> void:
	var p := Progress.new()
	p.record(_result("1-01", true, 3, 10))
	p.record(_result("1-02", true, 2, 10))
	p.record(_result("", false, 0, 777))
	p.record(_result("", false, 0, 500))
	assert_eq(p.total_stars(), 5)
	assert_eq(p.free_best, 777)


func test_state_roundtrip_through_json() -> void:
	var p := Progress.new()
	p.record(_result("1-01", true, 3, 120))
	p.record(_result("1-02", false, 0, 0))
	var p2 := Progress.new()
	p2.set_state(JSON.parse_string(JSON.stringify(p.get_state())))
	assert_eq(p2.stars("1-01"), 3)
	assert_eq(p2.fail_count("1-02"), 1)
