extends TestCase
## Arayüz akışı (duman testi): bölüm listesi → oyun → sonuç → sonraki bölüm,
## duraklatma ve listeye dönüş. Ekransız çalışır; görsel doğruluk için
## tools/screenshots.sh kullanılır.


func _app() -> Node:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_node(app)
	await tree.process_frame
	return app


func _play_until_finished(gs: GameScreen, max_frames: int = 4000) -> void:
	var bot := SimBot.new(SimBot.Kind.GREEDY, 7)
	var frames := 0
	while not gs.session.is_finished() and frames < max_frames:
		if gs.session.can_drop():
			gs.session.try_drop(bot.choose_x(gs.session))
		await tree.physics_frame
		frames += 1


func after_each() -> void:
	tree.paused = false
	await super.after_each()


func test_level_select_lists_levels_with_locks() -> void:
	var app := await _app()
	assert_true(app.screen is LevelSelect)
	var ls: LevelSelect = app.screen
	assert_eq(ls._tiles.size(), app.catalog.count())
	assert_true(ls._tiles[0].unlocked, "ilk bölüm açık")
	assert_false(ls._tiles[1].unlocked, "ikinci bölüm kilitli")


func test_play_win_unlocks_and_goes_next() -> void:
	var app := await _app()
	app.play("1-01")
	await tree.process_frame
	var gs: GameScreen = app.screen
	assert_true(gs.hud.any_panel_visible(), "giriş paneli açık")
	assert_false(gs._input_enabled, "giriş panelinde bırakma yok")
	gs._on_start_pressed()
	assert_true(gs._input_enabled)
	await _play_until_finished(gs)
	assert_true(gs.session.result.get("won", false), "1-01 kazanılmalı")
	assert_true(gs.hud._result[0].visible, "sonuç paneli")
	assert_true(app.progress.is_completed("1-01"))
	assert_true(app.progress.is_unlocked(app.catalog.get_level("1-02")))
	gs._to_next()
	await tree.process_frame
	await tree.process_frame
	assert_true(app.screen is GameScreen)
	assert_eq(app.screen.level.id, "1-02")


func test_pause_resume_and_back_to_levels() -> void:
	var app := await _app()
	app.play("1-01")
	await tree.process_frame
	var gs: GameScreen = app.screen
	gs._on_start_pressed()
	gs._pause()
	assert_true(tree.paused)
	assert_true(gs.hud._pause[0].visible)
	gs._resume()
	assert_false(tree.paused)
	gs._pause()
	gs._to_levels()
	await tree.process_frame
	await tree.process_frame
	assert_false(tree.paused)
	assert_true(app.screen is LevelSelect)


func test_retry_skips_intro_and_resets() -> void:
	var app := await _app()
	app.play("1-01")
	await tree.process_frame
	var gs: GameScreen = app.screen
	gs._on_start_pressed()
	gs.session.try_drop(450)
	await physics_frames(10)
	gs._begin(false)
	assert_false(gs.hud.any_panel_visible(), "yeniden denemede giriş paneli yok")
	assert_eq(gs.session.moves, 0)
	assert_eq(gs.board.building_count(), 0)


func test_tip_only_after_repeated_failures() -> void:
	var app := await _app()
	app.play("1-05")
	await tree.process_frame
	var gs: GameScreen = app.screen
	assert_eq(gs._tip_for(0), "")
	assert_eq(gs._tip_for(1), "")
	assert_ne(gs._tip_for(2), "")


func test_free_play_has_no_goals_and_no_intro() -> void:
	var app := await _app()
	app.play("")
	await tree.process_frame
	var gs: GameScreen = app.screen
	assert_false(gs.hud.any_panel_visible())
	assert_true(gs._input_enabled)
	assert_eq(gs.session.goals.goals.size(), 0)
	assert_eq(gs.session.moves_left(), -1)
