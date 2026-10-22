extends TestCase
## Arayüz akışı (duman testi): bölüm listesi → oyun → sonuç → sonraki bölüm,
## duraklatma ve listeye dönüş. Ekransız çalışır; görsel doğruluk için
## tools/screenshots.sh kullanılır.


## Her test kendi geçici kayıt dosyasıyla başlar (gerçek kayda dokunulmaz).
func _app() -> Node:
	App.save_path = "user://test_ui_%d.json" % randi()
	SaveStore.new(App.save_path).erase()
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
	SaveStore.new(App.save_path).erase()
	App.save_path = SaveStore.DEFAULT_PATH
	await super.after_each()


func test_map_lists_levels_with_locks() -> void:
	var app := await _app()
	assert_true(app.screen is LevelMap)
	var map: LevelMap = app.screen
	var nodes: Array[Dictionary] = map._canvas.nodes
	assert_eq(nodes.size(), app.catalog.count())
	assert_true(nodes[0].unlocked, "ilk bölüm açık")
	assert_true(nodes[0].current, "ilk bölüm sıradaki")
	assert_false(nodes[1].unlocked, "ikinci bölüm kilitli")


func test_new_player_gets_start_coins_and_save_file() -> void:
	var app := await _app()
	assert_eq(app.profile.wallet.balance("coins"), EconomyData.load_default().start_coins)
	assert_true(FileAccess.file_exists(App.save_path), "ilk açılışta kayıt oluşturulmalı")


func test_progress_survives_restart() -> void:
	var app := await _app()
	app.play("1-01")
	await tree.process_frame
	var gs: GameScreen = app.screen
	gs._on_start_pressed()
	await _play_until_finished(gs)
	assert_true(gs.session.result.get("won", false))
	var coins: int = app.profile.wallet.balance("coins")
	var stars: int = app.progress.stars("1-01")
	assert_true(coins > EconomyData.load_default().start_coins, "ödül verilmeli")
	# Uygulamayı "kapatıp açmak": yeni App aynı kayıt dosyasını okur.
	app.queue_free()
	await tree.process_frame
	var again: Node = load("res://scenes/main.tscn").instantiate()
	add_node(again)
	await tree.process_frame
	assert_eq(again.profile.wallet.balance("coins"), coins)
	assert_eq(again.progress.stars("1-01"), stars)
	assert_true(again.catalog.is_unlocked(again.catalog.get_level("1-02"), again.progress))


func test_corrupt_save_does_not_crash() -> void:
	App.save_path = "user://test_ui_corrupt_%d.json" % randi()
	var f := FileAccess.open(App.save_path, FileAccess.WRITE)
	f.store_string("{bozuk")
	f.close()
	var app: Node = load("res://scenes/main.tscn").instantiate()
	add_node(app)
	await tree.process_frame
	assert_true(app.screen is LevelMap, "bozuk kayıtla da açılmalı")
	assert_eq(app.profile.wallet.balance("coins"), EconomyData.load_default().start_coins, "temiz başlangıç")


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
	assert_true(app.catalog.is_unlocked(app.catalog.get_level("1-02"), app.progress))
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
	assert_true(app.screen is LevelMap)


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
