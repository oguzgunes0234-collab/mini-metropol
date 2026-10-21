extends SceneTree
## Oyun ekranının görüntüsünü alır (görsel kontrol ve farklı ekran oranları için).
## Ekranlı (sanal ekran da olur) çalıştırılmalıdır, --headless ile çalışmaz.
##
## Kullanım (pencere boyutu --resolution ile verilir):
##   godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/screenshot.gd -- \
##         --drops=40 --seed=3 --out=reports/shot.png [--locale=tr] [--game-over] [--debug]

var _opts := {"drops": "40", "seed": "3", "out": "reports/shot.png", "bot": "greedy", "locale": "tr"}
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
	await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var session: GameSession = scene.session
	var seed_value := int(_opts.seed)
	session.start(seed_value)
	var bot := SimBot.new(SimBot.kind_from_name(String(_opts.bot)), seed_value)
	var drops := 0
	var target := int(_opts.drops)
	var guard := 0
	while drops < target and session.state == GameSession.State.PLAYING and guard < 60 * 600:
		await physics_frame
		guard += 1
		if session.can_drop() and session.try_drop(bot.choose_x(session)):
			drops += 1
	for i in 150:
		await physics_frame
	if _flags.has("game-over") and session.state == GameSession.State.PLAYING:
		session.board.end_game("danger")
		await process_frame
	if _flags.has("debug"):
		scene.hud.toggle_debug()
	# Nişangâhı ortaya al, sıradaki bina görünsün.
	scene.dropper.set_aim(session.board.width * 0.5)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://").path_join(String(_opts.out))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print("Kaydedildi: ", out, " (", img.get_width(), "x", img.get_height(), ") bina=", session.board.building_count(), " puan=", session.score.score)
	quit()
