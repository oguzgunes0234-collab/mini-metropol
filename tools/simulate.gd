extends SceneTree
## Uzun stres simülasyonu. Otomatik oyuncu binlerce bina bırakır; her fizik
## karesinde tutarlılık kuralları (tests/support/invariants.gd) denetlenir,
## oyun bitince yeni oyun başlar. Sonuç JSON raporu olarak yazılır.
##
## Kullanım:
##   godot --headless --path . --fixed-fps 60 -s res://tools/simulate.gd -- \
##         --drops=10000 --seed=1 --bot=random --out=reports/sim.json
##
## Not: Fizik motoru her makinede birebir aynı sonucu vermez; bu yüzden
## sonuçlar "kanıt" değil, istatistiksel güven sağlar.

## --buildings ve --rules: denge denemeleri için başka veri dosyaları kullan.
var _opts := {"drops": 2000, "seed": 1, "bot": "random", "out": "", "buildings": GameData.BUILDINGS_PATH, "rules": GameData.RULES_PATH}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	var data := GameData.load_from_files(String(_opts.buildings), String(_opts.rules))
	if not data.is_valid():
		printerr("Veri hatalı: ", data.errors)
		quit(2)
		return
	# --ticks: fizik adım sıklığı denemesi (komut satırında --fixed-fps aynı değer verilmeli).
	if _opts.has("ticks"):
		Engine.physics_ticks_per_second = int(_opts.ticks)
	var target := int(_opts.drops)
	var seed_value := int(_opts.seed)
	var bot := SimBot.new(SimBot.kind_from_name(String(_opts.bot)), seed_value)

	var world := Node2D.new()
	root.add_child(world)
	var board := Board.new()
	world.add_child(board)
	board.setup(data)
	var session := GameSession.new()
	world.add_child(session)
	session.setup(data, board)
	session.record_events = true

	var inv := Invariants.new()
	var all_violations: PackedStringArray = []
	var games: Array[Dictionary] = []
	var level_reached := {}
	var drops := 0
	var frames := 0
	# Kare süresi: fizik adımı + tüm oyun betikleri (çizim yok, ekransız).
	var frame_ms: PackedFloat32Array = []
	var last_usec := Time.get_ticks_usec()
	var max_bodies := 0
	var total_merges := 0
	var total_landmarks := 0
	var reset_leftovers := 0
	var started := Time.get_ticks_msec()
	var game_seed := seed_value
	session.start(game_seed)

	while drops < target:
		await physics_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - last_usec) / 1000.0)
		frames += 1
		inv.check(session)
		_measure_penetration(board, frames)
		last_usec = Time.get_ticks_usec()
		max_bodies = maxi(max_bodies, board.building_count())

		if session.state == GameSession.State.GAME_OVER:
			games.append(_game_summary(session))
			total_merges += board.stats.merges
			total_landmarks += board.stats.landmarks
			var top := board.highest_level()
			for e in session.event_log:
				top = maxi(top, int(e.level))
			level_reached[top] = level_reached.get(top, 0) + 1
			for v in inv.violations:
				all_violations.append("oyun %d: %s" % [games.size(), v])
			game_seed += 1
			session.start(game_seed)
			inv.reset(true)
			await physics_frame
			# Yeniden başlatma sonrası alan tamamen boş olmalı.
			if board.building_count() != 0 or board.get_node("Buildings").get_child_count() != 0:
				reset_leftovers += 1
			continue

		if session.can_drop() and session.try_drop(bot.choose_x(session)):
			drops += 1
			if drops % 1000 == 0:
				print("  %d / %d bırakma, %d oyun, %.0f sn" % [drops, target, games.size(), (Time.get_ticks_msec() - started) / 1000.0])

	# Yarım kalan son oyunun ihlallerini de ekle.
	for v in inv.violations:
		all_violations.append("son oyun: %s" % v)
	total_merges += board.stats.merges
	total_landmarks += board.stats.landmarks

	var drops_per_game := []
	var scores := []
	for g in games:
		drops_per_game.append(g.moves)
		scores.append(g.score)
	var report := {
		"bot": _opts.bot,
		"seed": seed_value,
		"drops": drops,
		"frames": frames,
		"simulated_seconds": snappedf(frames / 60.0, 0.1),
		"wall_seconds": snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1),
		"games_finished": games.size(),
		"merges": total_merges,
		"landmarks": total_landmarks,
		"highest_level_per_game": level_reached,
		"drops_per_game": _stats(drops_per_game),
		"score_per_game": _stats(scores),
		"violations": all_violations.size(),
		"violation_samples": all_violations.slice(0, 20),
		"reset_leftovers": reset_leftovers,
		"max_bodies": max_bodies,
		"penetration_max": snappedf(_pen_max, 0.001),
		"penetration_frames_over_25pct": _pen_deep_frames,
		"penetration_resting_max": snappedf(_pen_resting_max, 0.001),
		"penetration_resting_frames_over_25pct": _pen_resting_frames,
		"penetration_resting_first": _pen_first,
		"frame_ms": _frame_stats(frame_ms),
		"godot": Engine.get_version_info().string,
	}
	var text := JSON.stringify(report, "  ")
	print(text)
	if String(_opts.out) != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(String(_opts.out).get_base_dir()))
		var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join(String(_opts.out)), FileAccess.WRITE)
		if f != null:
			f.store_string(text)
	quit(0 if all_violations.is_empty() and reset_leftovers == 0 else 1)


var _pen_max := 0.0
var _pen_resting_max := 0.0
var _pen_deep_frames := 0
var _pen_resting_frames := 0
var _pen_first := {}


## Duvara/zemine gömülme derinliği (yarıçapa oranla). Fizik kararlılığının
## ölçüsüdür. İki tür ayrılır:
## - anlık: hızlı çarpışma karesinde kısa süreli iç içe geçme (bir sonraki
##   karede düzelir),
## - durağan: yavaş/duran binanın yığın altında ezilip gömülü kalması
##   (görsel olarak kötüdür, olmaması gerekir).
func _measure_penetration(board: Board, frame: int) -> void:
	var deep := false
	var resting := false
	for b in board.buildings:
		var r := b.current_radius()
		var box := b.bounds()
		var pen := maxf(maxf(-box.position.x, box.end.x - board.width), box.end.y - board.height)
		var rel := pen / r
		var slow := b.linear_velocity.length() < 120.0
		_pen_max = maxf(_pen_max, rel)
		if slow:
			_pen_resting_max = maxf(_pen_resting_max, rel)
		if rel > 0.25:
			deep = true
			if slow:
				resting = true
				if _pen_first.is_empty():
					_pen_first = {
						"frame": frame, "level": b.level, "origin": b.origin, "age": snappedf(board.sim_time - b.born_time, 0.01),
						"pos": str(b.position), "vel": str(b.linear_velocity), "grow": b.grow, "bodies": board.building_count(),
					}
	if deep:
		_pen_deep_frames += 1
	if resting:
		_pen_resting_frames += 1


func _game_summary(s: GameSession) -> Dictionary:
	return {"moves": s.moves, "score": s.score.score, "merges": s.board.stats.merges, "best_chain": s.score.best_chain, "reason": s.board.game_over_reason}


## Kare süreleri (ms): ortalama, %99'luk dilim, en kötü. Denetim kodunun
## süresi hariçtir. Masaüstü sunucu işlemcisinde ölçülür; telefon değildir.
func _frame_stats(ms: PackedFloat32Array) -> Dictionary:
	if ms.is_empty():
		return {}
	var sorted := ms.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	return {
		"avg": snappedf(total / sorted.size(), 0.001),
		"p99": snappedf(sorted[int(sorted.size() * 0.99)], 0.001),
		"max": snappedf(sorted[sorted.size() - 1], 0.001),
	}


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += float(v)
	return {
		"min": sorted[0],
		"median": sorted[sorted.size() / 2],
		"avg": snappedf(total / sorted.size(), 0.1),
		"max": sorted[sorted.size() - 1],
	}
