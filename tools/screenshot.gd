extends SceneTree
## Oyun ekranlarının görüntüsünü alır (görsel kontrol ve farklı ekran oranları için).
## Ekranlı (sanal ekran da olur) çalıştırılmalıdır, --headless ile çalışmaz.
##
## Kullanım (pencere boyutu --resolution ile verilir):
##   godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/screenshot.gd -- \
##         --screen=play --level=1-04 --drops=12 --out=reports/shot.png [--locale=tr] [--debug]
##
## --screen: levels | intro | play | pause | won | lost | free
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
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var screen := String(_opts.screen)
	if screen == "levels":
		# Örnek ilerleme: ilk bölge tamamlanmış (farklı yıldızlarla), ikinci bölge açık.
		for i in int(_opts.get("completed", "3")):
			var lv: Dictionary = app.catalog.levels[i]
			app.profile.apply_result(lv, {"level_id": lv.id, "won": true, "stars": 3 - i % 3, "score": 100})
		app.show_levels()
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
		"lost":
			app.progress.fails[gs.level.id] = 1
			if not gs.session.is_finished():
				gs.session._finish(false, "out_of_moves")
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
