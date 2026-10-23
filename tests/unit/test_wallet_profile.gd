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


# --- Güçlendirici envanteri, satın alma, hediyeler ---

## Varsayılan güçlendirici kurallarıyla, küçük eşikli bir test ekonomisi.
func _booster_economy() -> EconomyData:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EconomyData.PATH))
	d.star_milestones = [{"stars": 3, "coins": 10, "diamonds": 2, "boosters": {"crane": 1}}]
	return EconomyData.from_dict(d)


func test_default_booster_unlock_levels_exist() -> void:
	var e := EconomyData.load_default()
	var cat := LevelCatalog.load_default()
	for id in EconomyData.BOOSTER_IDS:
		var after: String = e.boosters[id].unlock_after
		assert_true(after == "" or not cat.get_level(after).is_empty(), "%s: %s bölümü yok" % [id, after])


func test_booster_economy_validation() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EconomyData.PATH))
	var cases := {
		"bilinmeyen kimlik": func(d): d.boosters.roket = d.boosters.undo,
		"eksik güçlendirici": func(d): d.boosters.erase("swap"),
		"geçersiz para birimi": func(d): d.boosters.undo.price = {"altın": 5},
		"sıfır fiyat": func(d): d.boosters.undo.price = {"coins": 0},
		"sıfır sınır": func(d): d.boosters.undo.per_level = 0,
		"aralık dışı etki": func(d): d.boosters.extra_moves.amount = 50,
		"eşikte bilinmeyen güçlendirici": func(d): d.star_milestones[0].boosters = {"roket": 1},
		"envanter sınırı yok": func(d): d.erase("inventory_cap"),
	}
	for name in cases:
		var d: Dictionary = base.duplicate(true)
		cases[name].call(d)
		assert_false(EconomyData.from_dict(d).is_valid(), name)


func test_unlock_gift_is_given_once() -> void:
	var e := _booster_economy()
	var p := PlayerProfile.create_new(e)
	assert_eq(p.booster_count("undo"), 0)
	var after: String = e.boosters.undo.unlock_after
	var r := p.apply_result({"id": after, "rewards": {}}, _won(after, 1))
	assert_eq(p.booster_count("undo"), int(e.boosters.undo.gift))
	assert_eq(int(r.boosters.get("undo", 0)), int(e.boosters.undo.gift))
	assert_true(p.boosters_new.has("undo"), "yeni güçlendirici tanıtılmak üzere işaretlenir")
	p.apply_result({"id": after, "rewards": {}}, _won(after, 1))
	assert_eq(p.booster_count("undo"), int(e.boosters.undo.gift), "hediye ikinci kez verilmez")
	var copy := PlayerProfile.from_state(JSON.parse_string(JSON.stringify(p.get_state())), e)
	assert_eq(copy.booster_count("undo"), int(e.boosters.undo.gift), "kayıttan sonra da tekrar verilmez")


func test_old_save_gets_gifts_for_already_unlocked_boosters() -> void:
	var e := _booster_economy()
	var after: String = e.boosters.undo.unlock_after
	# Güçlendiriciler eklenmeden önceki bir kayıt: yalnızca ilerleme var.
	var old := {"progress": {"best": {after: {"stars": 2, "score": 10, "completed": true}}}}
	var p := PlayerProfile.from_state(old, e)
	assert_eq(p.booster_count("undo"), int(e.boosters.undo.gift))


func test_developer_unlock_gives_no_gifts() -> void:
	var p := PlayerProfile.create_new(_booster_economy())
	p.progress.unlock_all = true
	assert_true(p.is_booster_unlocked("relieve"))
	p.apply_result({"id": "x", "rewards": {}}, {"level_id": "", "won": false, "stars": 0, "score": 0})
	assert_eq(p.booster_count("relieve"), 0)


func test_level_booster_reward_only_on_first_clear() -> void:
	var p := PlayerProfile.create_new(_booster_economy())
	var lv := {"id": "9-01", "rewards": {"coins_first": 10, "coins_repeat": 1, "boosters": {"swap": 2}}}
	p.apply_result(lv, _won("9-01", 1))
	assert_eq(p.booster_count("swap"), 2)
	p.apply_result(lv, _won("9-01", 1))
	assert_eq(p.booster_count("swap"), 2, "tekrar oynamada güçlendirici ödülü yok")


func test_milestone_gives_diamonds_and_boosters_once() -> void:
	var p := PlayerProfile.create_new(_booster_economy())
	var r := p.apply_result({"id": "9-01", "rewards": {}}, _won("9-01", 3))
	assert_eq(r.diamonds, 2)
	assert_eq(p.wallet.balance("diamonds"), 2)
	assert_eq(p.booster_count("crane"), 1)
	p.apply_result({"id": "9-02", "rewards": {}}, _won("9-02", 3))
	assert_eq(p.wallet.balance("diamonds"), 2, "eşik bir kez")


func test_buy_booster_rules() -> void:
	var e := _booster_economy()
	var p := PlayerProfile.create_new(e)
	assert_eq(p.buy_booster("undo"), "locked", "açılmamış güçlendirici satın alınmaz")
	assert_eq(p.buy_booster("roket"), "unknown")
	p.progress.unlock_all = true
	var price := int(e.boosters.undo.price)
	var coins := p.wallet.balance("coins")
	assert_eq(p.buy_booster("undo"), "")
	assert_eq(p.booster_count("undo"), 1)
	assert_eq(p.wallet.balance("coins"), coins - price)
	# Yetersiz bakiye: hiçbir şey değişmez.
	p.wallet.spend("coins", p.wallet.balance("coins"), "test")
	assert_eq(p.buy_booster("undo"), "funds")
	assert_eq(p.booster_count("undo"), 1)
	assert_eq(p.wallet.balance("coins"), 0)
	# Envanter dolu: para harcanmaz.
	p.wallet.add("coins", 100000, "test")
	p.add_boosters("undo", 1000)
	assert_eq(p.booster_count("undo"), e.inventory_cap, "envanter sınırı aşılmaz")
	var before := p.wallet.balance("coins")
	assert_eq(p.buy_booster("undo"), "cap")
	assert_eq(p.wallet.balance("coins"), before)


func test_corrupt_booster_state_is_sanitized() -> void:
	var e := _booster_economy()
	var p := PlayerProfile.from_state({
		"boosters": {"undo": -4, "swap": 1e9, "roket": 5, "crane": "çok"},
		"boosters_gifted": ["undo", "roket", 3, "undo"],
		"boosters_new": "bozuk",
	}, e)
	assert_eq(p.booster_count("undo"), 0)
	assert_eq(p.booster_count("swap"), e.inventory_cap)
	assert_eq(p.booster_count("crane"), 0)
	assert_false(p.boosters.has("roket"))
	assert_eq(p.boosters_gifted, ["undo"] as Array[String])
	assert_true(p.boosters_new.is_empty())



func test_language_setting_is_sanitized() -> void:
	var e := _economy()
	assert_eq(PlayerProfile.from_state({"settings": {"language": "fr"}}, e).setting("language"), "")
	assert_eq(PlayerProfile.from_state({"settings": {"language": 5}}, e).setting("language"), "")
	var p := PlayerProfile.from_state({"settings": {"language": "en"}}, e)
	assert_eq(p.locale(), "en")
	p.settings.language = ""
	assert_true(["tr", "en"].has(p.locale()), "boşsa cihaz diline göre tr veya en")
