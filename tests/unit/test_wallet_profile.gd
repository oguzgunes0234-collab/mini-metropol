extends TestCase
## Cüzdan, ekonomi verisi ve oyuncu profili (ödüller, kayıt durumu).


func _economy() -> EconomyData:
	return EconomyData.from_dict({
		"start": {"coins": 100, "diamonds": 0},
		"coins_per_new_star": 10,
		"star_milestones": [{"stars": 3, "coins": 50}, {"stars": 6, "coins": 80}],
	})


func _level(id: String) -> Dictionary:
	return {"id": id, "rewards": {"coins_first": 30, "coins_repeat": 5}}


func _won(id: String, stars: int) -> Dictionary:
	return {"level_id": id, "won": true, "stars": stars, "score": 100}


func test_wallet_add_and_spend() -> void:
	var w := Wallet.new()
	w.add("coins", 50, "test")
	assert_true(w.spend("coins", 20, "test"))
	assert_eq(w.balance("coins"), 30)
	assert_false(w.spend("coins", 31, "test"), "yetersiz bakiye")
	assert_eq(w.balance("coins"), 30, "başarısız harcama bakiyeyi değiştirmez")


func test_wallet_ignores_invalid_amounts() -> void:
	var w := Wallet.new()
	w.add("coins", -5, "test")
	w.add("altın", 5, "test")
	assert_eq(w.balance("coins"), 0)
	assert_false(w.spend("coins", -1, "test"))


func test_wallet_state_is_sanitized() -> void:
	var w := Wallet.new()
	w.set_state({"balances": {"coins": -40, "diamonds": "çok"}, "ledger": "bozuk"})
	assert_eq(w.balance("coins"), 0)
	assert_eq(w.balance("diamonds"), 0)
	assert_eq(w.ledger.size(), 0)


func test_wallet_ledger_is_capped() -> void:
	var w := Wallet.new()
	for i in Wallet.LEDGER_SIZE + 20:
		w.add("coins", 1, "test")
	assert_eq(w.ledger.size(), Wallet.LEDGER_SIZE)


func test_default_economy_is_valid() -> void:
	var e := EconomyData.load_default()
	assert_true(e.is_valid(), "\n".join(e.errors))


func test_economy_validation() -> void:
	assert_false(EconomyData.from_dict({}).is_valid())
	var bad := EconomyData.from_dict({"start": {"coins": -1, "diamonds": 0}, "coins_per_new_star": 1, "star_milestones": []})
	assert_false(bad.is_valid())
	var unordered := EconomyData.from_dict({"start": {"coins": 0, "diamonds": 0}, "coins_per_new_star": 1, "star_milestones": [{"stars": 5, "coins": 1}, {"stars": 3, "coins": 1}]})
	assert_false(unordered.is_valid())


func test_new_profile_gets_start_coins() -> void:
	var p := PlayerProfile.create_new(_economy())
	assert_eq(p.wallet.balance("coins"), 100)


func test_first_completion_rewards() -> void:
	var p := PlayerProfile.create_new(_economy())
	var r := p.apply_result(_level("1-01"), _won("1-01", 2))
	# İlk tamamlama 30 + 2 yeni yıldız × 10
	assert_eq(r.coins, 50)
	assert_eq(p.wallet.balance("coins"), 150)


func test_repeat_completion_rewards_and_star_improvement() -> void:
	var p := PlayerProfile.create_new(_economy())
	p.apply_result(_level("1-01"), _won("1-01", 2))
	var again := p.apply_result(_level("1-01"), _won("1-01", 2))
	assert_eq(again.coins, 5, "tekrar: yalnızca küçük ödül, yıldız bonusu yok")
	var better := p.apply_result(_level("1-01"), _won("1-01", 3))
	assert_eq(better.coins, 5 + 10 + 50, "tekrar + 1 yeni yıldız + 3 yıldız kilometre taşı")


func test_loss_gives_nothing() -> void:
	var p := PlayerProfile.create_new(_economy())
	var r := p.apply_result(_level("1-01"), {"level_id": "1-01", "won": false, "stars": 0, "score": 50})
	assert_eq(r.coins, 0)
	assert_eq(p.progress.fail_count("1-01"), 1)


func test_milestone_given_once() -> void:
	var p := PlayerProfile.create_new(_economy())
	p.apply_result(_level("1-01"), _won("1-01", 3))
	var before := p.wallet.balance("coins")
	p.apply_result(_level("1-01"), _won("1-01", 3))
	assert_eq(p.wallet.balance("coins") - before, 5, "kilometre taşı ikinci kez verilmemeli")


func test_profile_state_roundtrip_through_json() -> void:
	var p := PlayerProfile.create_new(_economy())
	p.apply_result(_level("1-01"), _won("1-01", 3))
	p.settings.haptics = false
	var copy := PlayerProfile.from_state(JSON.parse_string(JSON.stringify(p.get_state())), _economy())
	assert_eq(copy.wallet.balance("coins"), p.wallet.balance("coins"))
	assert_eq(copy.progress.stars("1-01"), 3)
	assert_eq(copy.setting("haptics"), false)
	assert_eq(copy.milestones_claimed, [3] as Array[int])


func test_corrupt_profile_state_is_sanitized() -> void:
	var p := PlayerProfile.from_state({
		"progress": {"best": {"1-01": {"stars": 99, "score": -5, "completed": "evet"}, "5": "bozuk"}, "fails": {"1-01": -3}},
		"wallet": {"balances": {"coins": 1e12}},
		"settings": {"haptics": "hayır", "bilinmeyen": true},
		"milestones_claimed": ["x", 10, 10],
	}, _economy())
	assert_eq(p.progress.stars("1-01"), 3, "yıldız 0-3 aralığına sıkıştırılır")
	assert_eq(p.progress.best_score("1-01"), 0)
	assert_false(p.progress.is_completed("1-01"))
	assert_eq(p.progress.fail_count("1-01"), 0)
	assert_eq(p.setting("haptics"), true, "geçersiz ayar varsayılana döner")
	assert_false(p.settings.has("bilinmeyen"))
	assert_eq(p.milestones_claimed, [10] as Array[int])
