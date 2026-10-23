extends SceneTree
## Oyun ekranlarının görüntüsünü alır (görsel kontrol ve farklı ekran oranları için).
## Ekranlı (sanal ekran da olur) çalıştırılmalıdır, --headless ile çalışmaz.
##
## Kullanım (pencere boyutu --resolution ile verilir):
##   godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/screenshot.gd -- \
##         --screen=play --level=1-04 --drops=12 --out=reports/shot.png [--locale=tr] [--debug]
##
## --screen: buildings | menu | settings | levels | intro | play | pause | game_settings | won | lost | free | shop | pick
## --completed=N: önce ilk N bölüm tamamlanmış sayılır (güçlendiriciler açılır).
## shop: satın alma paneli (--booster=extra_moves, --coins=N ile bakiye).
## pick: vinç seçimi (alınabilecek binalar vurgulu).
## "lost" ekranı, sonuç panelini göstermek için bölümü birkaç hamleden sonra
## "hamleler bitti" ile sonlandırır (yalnızca arayüz kontrolü içindir).

var _opts := {"screen": "play", "level": "1-01", "drops": "10", "seed": "3", "out": "reports/shot.png", "bot": "greedy", "locale": "tr"}
var _flags := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
		elif arg.begins_with("--"):
			_flags[arg.substr(2)] = true
	_run.call_deferred()


func _run() -> void:
	TranslationServer.set_locale(String(_opts.locale))
	if _opts.has("shape"):
		GameData.load_default().rules.physics.shape_mode = String(_opts.shape)
	# Ekran görüntüsü gerçek oyuncu kaydına dokunmaz.
	App.save_path = "user://screenshot_save.json"
	SaveStore.new(App.save_path).erase()
	if _opts.has("safe"):
		# Çentikli telefon benzetimi: --safe=üst,alt (tasarım birimi)
		var parts := String(_opts.safe).split(",")
		App.safe_area_override = Vector2(float(parts[0]), float(parts[1]))
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	# Uygulama dili kayıttan gelir; görüntü için istenen dile geç.
	app.profile.settings.language = String(_opts.locale)
	TranslationServer.set_locale(String(_opts.locale))
	var screen := String(_opts.screen)
	# Örnek ilerleme: ilk N bölüm farklı yıldızlarla tamamlanmış.
	for i in int(_opts.get("completed", "3" if screen == "levels" else "0")):
		var lv: Dictionary = app.catalog.levels[i]
		app.profile.apply_result(lv, {"level_id": lv.id, "won": true, "stars": 3 - i % 3, "score": 100})
	if _opts.has("coins"):
		var w: Wallet = app.profile.wallet
		w.spend("coins", w.balance("coins"), "screenshot")
		if int(_opts.coins) > 0:
			w.add("coins", int(_opts.coins), "screenshot")
	if screen == "levels":
		app.show_levels()
		await _capture()
		return
	if screen == "buildings":
		# Tüm bina seviyeleri tek sayfada (görsel kontrol için).
		var sheet := Control.new()
		sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
		sheet.draw.connect(func():
			var data := GameData.load_default()
			sheet.draw_rect(Rect2(Vector2.ZERO, sheet.size), UiKit.BACKDROP)
			var cell := Vector2(sheet.size.x / 3.0, (sheet.size.y - 40.0) / 3.0)
			for lv in range(1, data.max_level + 1):
				var i := lv - 1
				var c := Vector2(cell.x * (i % 3 + 0.5), 40.0 + cell.y * (i / 3) + cell.y * 0.42)
				var r := minf(cell.x, cell.y) * 0.34
				sheet.draw_set_transform(c)
				BuildingArt.draw_building(sheet, data.level_def(lv), r, "circle")
				sheet.draw_set_transform(Vector2.ZERO)
				var name := "%d · %s" % [lv, tr(data.level_def(lv).name_key)]
				var f := UiKit.font_heavy()
				var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
				sheet.draw_string(f, Vector2(c.x - w * 0.5, c.y + r + 60), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiKit.INK))
		app.add_child(sheet)
		await _capture()
		return
	if screen == "menu":
		app.show_menu()
		await _capture()
		return
	if screen == "settings":
		app.show_settings("menu")
		await _capture()
		return

	app.play("" if screen == "free" else String(_opts.level))
	await process_frame
	var gs: GameScreen = app.screen
	if screen == "intro":
		await _capture()
		return
	gs._on_start_pressed()
	var bot := SimBot.new(SimBot.kind_from_name(String(_opts.bot)), int(_opts.seed))
	var target := int(_opts.drops) if screen != "won" else 999
	var drops := 0
	var guard := 0
	while drops < target and not gs.session.is_finished() and guard < 60 * 600:
		await physics_frame
		guard += 1
		if gs.session.can_drop() and gs.session.try_drop(bot.choose_x(gs.session)):
			drops += 1
	for i in 100:
		await physics_frame
	match screen:
		"pause":
			gs._pause()
		"game_settings":
			gs._pause()
			gs._open_settings()
		"lost":
			app.progress.fails[gs.level.id] = 1
			if not gs.session.is_finished():
				gs.session._finish(false, "out_of_moves")
		"shop":
			# Gerçek akışta panel yalnızca envanter boşken açılır.
			var id := String(_opts.get("booster", "extra_moves"))
			app.profile.boosters[id] = 0
			gs._refresh_boosters()
			gs._open_shop(id)
		"pick":
			gs._on_booster_pressed("crane")
			for i in 30:
				await process_frame
	if _flags.has("debug"):
		gs.hud.toggle_debug()
	gs.dropper.set_aim(gs.board.width * 0.5)
	await _capture()


func _capture() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://").path_join(String(_opts.out))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print("Kaydedildi: ", out, " (", img.get_width(), "x", img.get_height(), ")")
	SaveStore.new(App.save_path).erase()
	quit()
