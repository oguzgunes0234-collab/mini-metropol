extends TestCase
## Kısa stres testi: otomatik oyuncu yüzlerce bina bırakır, her fizik
## karesinde tutarlılık kuralları denetlenir. Uzun sürümü: tools/run_sim.sh


func _play(bot_kind: SimBot.Kind, seed_value: int, drops: int) -> Invariants:
	var s := make_session(null, seed_value)
	var bot := SimBot.new(bot_kind, seed_value)
	var inv := Invariants.new()
	var done := 0
	var restarts := 0
	while done < drops:
		await tree.physics_frame
		inv.check(s)
		if s.state == GameSession.State.LOST:
			s.start(seed_value + restarts + 1)
			restarts += 1
			inv.reset()
			continue
		if s.can_drop() and s.try_drop(bot.choose_x(s)):
			done += 1
	return inv


func test_random_bot_keeps_invariants() -> void:
	var inv := await _play(SimBot.Kind.RANDOM, 101, 250)
	assert_true(inv.checks > 1000)
	assert_true(inv.ok(), "\n".join(inv.violations))


func test_greedy_bot_keeps_invariants() -> void:
	var inv := await _play(SimBot.Kind.GREEDY, 202, 250)
	assert_true(inv.ok(), "\n".join(inv.violations))
