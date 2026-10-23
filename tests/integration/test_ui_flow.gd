extends TestCase
## Arayüz akışı (duman testi): bölüm listesi → oyun → sonuç → sonraki bölüm,
## duraklatma ve listeye dönüş. Ekransız çalışır; görsel doğruluk için
## tools/screenshots.sh kullanılır.


## Her test kendi geçici kayıt dosyasıyla başlar (gerçek kayda dokunulmaz).
## Uygulama ana menüyle açılır; bu yardımcı bölüm haritasına geçer.
func _app() -> Node:
	var app: Node = await _app_at_menu()
	app.show_levels()
	await tree.process_frame
	return app


func _app_at_menu() -> Node:
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
	TranslationServer.set_locale("en")
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
	assert_true(app.screen is MainMenu, "bozuk kayıtla da açılmalı")
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


# --- Güçlendiriciler ---

## İlk n bölümü tamamlanmış oyuncuyla bölümü başlatır (giriş paneli geçilir).
func _play_after(app: Node, completed: int, id: String) -> GameScreen:
	for i in completed:
		var lv: Dictionary = app.catalog.levels[i]
		app.profile.apply_result(lv, {"level_id": lv.id, "won": true, "stars": 2, "score": 100})
	app.play(id)
	await tree.process_frame
	var gs: GameScreen = app.screen
	gs._on_start_pressed()
	return gs


func _saved_state() -> Dictionary:
	return SaveStore.new(App.save_path).load_data()


func test_booster_bar_hidden_until_unlocked() -> void:
	var app := await _app()
	app.play("1-01")
	await tree.process_frame
	var gs: GameScreen = app.screen
	assert_eq(gs.boosters.visible_ids().size(), 0)
	assert_false(gs.hud._bar.visible, "ilk bölümde güçlendirici çubuğu yok")
	app.play("")
	await tree.process_frame
	assert_false(app.screen.hud._bar.visible, "serbest oyunda güçlendirici yok")


func test_new_booster_is_introduced_once() -> void:
	var app := await _app()
	for i in 2:
		var lv: Dictionary = app.catalog.levels[i]
		app.profile.apply_result(lv, {"level_id": lv.id, "won": true, "stars": 2, "score": 100})
	assert_true(app.profile.boosters_new.has("undo"))
	app.play("1-03")
	await tree.process_frame
	var gs: GameScreen = app.screen
	assert_false(app.profile.boosters_new.has("undo"), "tanıtım bir kez gösterilir")
	assert_false(_saved_state().get("boosters_new", ["?"]).has("undo"), "tanıtım bilgisi kaydedilir")
	assert_true(gs.hud._bar.visible)
	assert_true(gs.hud.booster_button("undo") != null)


func test_buy_and_use_when_out_of_stock() -> void:
	var app := await _app()
	var gs := await _play_after(app, 2, "1-03")
	app.profile.boosters.undo = 0
	await wait_cooldown(gs.session)
	assert_true(gs.session.try_drop(300))
	var coins: int = app.profile.wallet.balance("coins")
	gs._on_booster_pressed("undo")
	assert_true(gs.hud.is_shop_visible(), "envanter boşken satın alma paneli açılır")
	assert_true(tree.paused, "panel açıkken oyun durur")
	gs.hud.shop_button("Buy").pressed.emit()
	await tree.process_frame
	assert_false(tree.paused)
	var price := int(app.profile.economy.boosters.undo.price)
	assert_eq(app.profile.wallet.balance("coins"), coins - price)
	assert_eq(app.profile.booster_count("undo"), 0, "satın alınan adet hemen kullanıldı")
	assert_eq(gs.session.moves, 0, "bırakma geri alındı")
	var saved := _saved_state()
	assert_eq(int(saved.wallet.balances.coins), coins - price, "satın alma hemen kaydedilir")


func test_not_enough_coins_offers_no_purchase() -> void:
	var app := await _app()
	var gs := await _play_after(app, 2, "1-03")
	app.profile.boosters.undo = 0
	app.profile.wallet.spend("coins", app.profile.wallet.balance("coins"), "test")
	await wait_cooldown(gs.session)
	gs.session.try_drop(300)
	gs._on_booster_pressed("undo")
	assert_true(gs.hud.is_shop_visible())
	assert_true(gs.hud.shop_button("Buy") == null, "bakiye yetmezse satın al düğmesi yok")
	gs.hud.shop_button("Cancel").pressed.emit()
	assert_false(tree.paused)
	assert_false(gs.hud.any_panel_visible())
	assert_eq(gs.session.moves, 1, "hiçbir şey değişmedi")


func test_unavailable_booster_explains_why() -> void:
	var app := await _app()
	var gs := await _play_after(app, 2, "1-03")
	gs._on_booster_pressed("undo")
	assert_false(gs.hud.is_shop_visible())
	assert_eq(gs.hud.toast_text(), tr("BOOST_NOT_NOW_UNDO"), "neden kullanılamadığı yazılır")
	assert_eq(app.profile.booster_count("undo"), int(app.profile.economy.boosters.undo.gift))


func test_crane_pick_by_tapping_a_building() -> void:
	var app := await _app()
	var gs := await _play_after(app, 7, "1-08")
	await wait_cooldown(gs.session)
	gs.session.try_drop(200)
	await physics_frames(150)
	var target: Building = gs.session.board.buildings[0]
	gs._on_booster_pressed("crane")
	assert_true(gs._picking, "vinç seçimi başlar")
	assert_true(gs.hud.toast_text() != "", "yönerge gösterilir")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = gs.board.to_global(target.position)
	gs._unhandled_input(ev)
	assert_false(gs._picking)
	assert_eq(gs.session.held_level, target.level, "dokunulan bina alındı")
	assert_eq(gs.dropper.level, target.level, "bırakıcıda alınan bina var")
	# Bırakma: alınan bina, hamle harcamadan.
	ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = gs.board.to_global(Vector2(700, 0))
	gs._aiming = true
	gs._unhandled_input(ev)
	await tree.process_frame
	assert_eq(gs.session.held_level, 0)
	assert_eq(gs.session.moves, 1, "yeniden bırakmak hamle harcamaz")



# --- Ana menü ve ayarlar (Aşama 6) ---

func test_app_starts_at_menu_and_navigates() -> void:
	var app: Node = await _app_at_menu()
	assert_true(app.screen is MainMenu, "uygulama ana menüyle açılır")
	app.screen.play_pressed.emit()
	await tree.process_frame
	assert_true(app.screen is LevelMap, "Oyna → bölüm haritası")
	app.screen.back_pressed.emit()
	await tree.process_frame
	assert_true(app.screen is MainMenu, "haritadan geri → ana menü")
	app.screen.settings_pressed.emit()
	await tree.process_frame
	assert_true(app.screen is SettingsScreen)
	app.screen.back_pressed.emit()
	await tree.process_frame
	assert_true(app.screen is MainMenu, "ayarlardan geri → geldiği ekran")
	app.screen.free_play_pressed.emit()
	await tree.process_frame
	assert_true(app.screen is GameScreen and app.screen.level.is_empty(), "serbest oyun")


func test_menu_shows_next_level() -> void:
	var app: Node = await _app_at_menu()
	assert_eq(app.screen.next_level().id, "1-01")
	var lv: Dictionary = app.catalog.levels[0]
	app.profile.apply_result(lv, {"level_id": lv.id, "won": true, "stars": 1, "score": 10})
	assert_eq(app.screen.next_level().id, "1-02")


func test_setting_change_is_saved_immediately() -> void:
	var app: Node = await _app_at_menu()
	app.show_settings("menu")
	await tree.process_frame
	var view: SettingsView = app.screen.view
	var sw := view.switch("haptics")
	assert_true(sw.on)
	sw.on = false
	sw.toggled.emit(false)
	assert_eq(app.profile.setting("haptics"), false)
	assert_eq(_saved_state().settings.haptics, false, "ayar hemen kaydedilir")


func test_language_can_be_changed() -> void:
	var app: Node = await _app_at_menu()
	app.show_settings("menu")
	await tree.process_frame
	var view: SettingsView = app.screen.view
	(view.find_child("Lang_tr", true, false) as Button).pressed.emit()
	assert_eq(TranslationServer.get_locale(), "tr")
	assert_eq(app.profile.setting("language"), "tr")
	assert_eq(_saved_state().settings.language, "tr")
	(view.find_child("Lang_en", true, false) as Button).pressed.emit()
	assert_eq(TranslationServer.get_locale(), "en")


func test_reset_progress_needs_confirmation_and_keeps_settings() -> void:
	var app: Node = await _app_at_menu()
	var lv: Dictionary = app.catalog.levels[0]
	app.profile.apply_result(lv, {"level_id": lv.id, "won": true, "stars": 3, "score": 10})
	app.profile.settings.haptics = false
	app.show_settings("menu")
	await tree.process_frame
	var view: SettingsView = app.screen.view
	(view.find_child("Reset", true, false) as Button).pressed.emit()
	var confirm: Control = view.find_child("ResetConfirm", true, false)
	assert_true(confirm.visible, "önce onay sorulur")
	assert_true(app.progress.is_completed(lv.id), "onaysız hiçbir şey silinmez")
	(confirm.find_child("CancelReset", true, false) as Button).pressed.emit()
	assert_false(confirm.visible)
	assert_true(app.progress.is_completed(lv.id))
	(view.find_child("Reset", true, false) as Button).pressed.emit()
	(confirm.find_child("ConfirmReset", true, false) as Button).pressed.emit()
	await tree.process_frame
	assert_false(app.progress.is_completed(lv.id), "ilerleme silindi")
	assert_eq(app.profile.wallet.balance("coins"), EconomyData.load_default().start_coins)
	assert_eq(app.profile.setting("haptics"), false, "ayarlar korunur")
	assert_true(app.screen is MainMenu)
	assert_false(_saved_state().progress.best.has(lv.id), "sıfırlama kaydedildi")


func test_in_game_settings_from_pause() -> void:
	var app := await _app()
	app.play("1-01")
	await tree.process_frame
	var gs: GameScreen = app.screen
	gs._on_start_pressed()
	gs._pause()
	(gs.hud._pause[1].find_child("Settings", true, false) as Button).pressed.emit()
	assert_true(gs.hud.is_settings_visible())
	var view: SettingsView = gs.hud._settings[1].get_child(1)
	assert_true(view.find_child("Languages", true, false) == null, "oyun içinde dil seçimi yok")
	assert_true(view.find_child("Reset", true, false) == null, "oyun içinde sıfırlama yok")
	var sw := view.switch("reduced_motion")
	sw.on = true
	sw.toggled.emit(true)
	assert_true(gs.effects.reduced_motion, "hareketi azalt hemen uygulanır")
	assert_eq(_saved_state().settings.reduced_motion, true)
	(gs.hud._settings[1].find_child("Close", true, false) as Button).pressed.emit()
	assert_true(gs.hud._pause[0].visible, "kapatınca duraklatma paneline dönülür")
	assert_true(tree.paused, "oyun hâlâ duraklatılmış")


## Görünen her etkileşimli öğe en az TOUCH boyutunda, her yazı en az T_CAPTION.
func _check_accessibility(root: Node, where: String) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		for c in n.get_children():
			stack.append(c)
		if not (n is Control):
			continue
		var c := n as Control
		var interactive := c is BaseButton or c is UiKit.IconButton or c is UiKit.Switch or c is Hud.BoosterButton
		if interactive:
			assert_true(c.size.y >= UiKit.TOUCH - 0.5 and c.size.x >= UiKit.TOUCH - 0.5,
				"%s: %s dokunma hedefi küçük (%s)" % [where, c.name, c.size])
		if c is Label:
			assert_true(c.get_theme_font_size("font_size") >= UiKit.T_CAPTION, "%s: '%s' yazısı küçük" % [where, (c as Label).text])


func test_screens_meet_touch_and_text_minimums() -> void:
	var app: Node = await _app_at_menu()
	await tree.process_frame
	_check_accessibility(app.screen, "ana menü")
	app.show_levels()
	await tree.process_frame
	_check_accessibility(app.screen, "harita")
	app.show_settings("menu")
	await tree.process_frame
	_check_accessibility(app.screen, "ayarlar")
	var gs := await _play_after(app, 9, "1-10")
	await tree.process_frame
	_check_accessibility(gs.hud._root, "oyun")
	gs._pause()
	_check_accessibility(gs.hud._root, "duraklatma")
	gs._open_settings()
	_check_accessibility(gs.hud._root, "oyun içi ayarlar")
