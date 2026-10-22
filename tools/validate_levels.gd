extends SceneTree
## Bölüm doğrulama: her bölümü üç bot türüyle defalarca oynar, kazanma
## oranını, yıldızları, kullanılan hamleyi ve kaybetme nedenlerini raporlar.
## Her gerçek fizik karesinde tutarlılık denetimi de yapılır.
##
## Kullanım:
##   godot --headless --path . --fixed-fps 120 -s res://tools/validate_levels.gd -- \
##         [--attempts=20] [--planner_attempts=6] [--bots=random,greedy,planner] \
##         [--levels=1-01,1-02] [--out=reports/levels.json] [--moves_override=200]
##
## --moves_override: hamle sınırını geçici olarak değiştirir. Çok büyük bir
## değerle kaba bir keşif yapılabilir. DİKKAT: sınırsız modda bot, zincirleme
## birleşmeler sürerken bırakmaya devam eder; kullanılan hamle gerçek oyuna
## göre fazla çıkar. Son ayar her zaman gerçek hamle sınırıyla yapılmalıdır.
##
## Önemli: Bir botun bir bölümü en az bir kez kazanması, bölümün bu makinede
## çözülebilir olduğunu gösterir. Fizik motoru farklı cihazlarda birebir aynı
## sonucu vermediği için bu kesin bir kanıt değildir.

var _opts := {
	"attempts": "20", "planner_attempts": "6", "bots": "random,greedy,planner",
	"levels": "", "out": "reports/levels.json", "max_frames": "30000",
}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var kv := arg.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
		elif arg.begins_with("--"):
			_opts[arg.substr(2)] = true
	_run.call_deferred()


func _run() -> void:
	# --levels_file: tasarım denemeleri için başka bir bölüm dosyası.
	# --buildings: kütle/boyut denemeleri için başka bir bina dosyası.
	var base := GameData.load_default()
	if _opts.has("buildings"):
		base = GameData.load_from_files(String(_opts.buildings), GameData.RULES_PATH)
	if _opts.has("no_rescue"):
		Board.rescue_enabled = false
	var cat := LevelCatalog.load_from_file(String(_opts.get("levels_file", LevelCatalog.LEVELS_PATH)), base)
	if not cat.is_valid():
		printerr("Bölüm verisi hatalı:\n", "\n".join(cat.errors))
		quit(2)
		return
	var only := PackedStringArray()
	if String(_opts.levels) != "":
		only = String(_opts.levels).split(",")
	var bots := String(_opts.bots).split(",")
	var max_frames := int(_opts.max_frames)

	var world := Node2D.new()
	root.add_child(world)
	var board := Board.new()
	world.add_child(board)
	var session := GameSession.new()
	world.add_child(session)
	board.setup(cat.base)
	session.setup(cat.base, board)
	session.record_events = true

	var started := Time.get_ticks_msec()
	var report := {"godot": Engine.get_version_info().string, "levels": []}
	var total_violations := 0
	for original in cat.levels:
		if not only.is_empty() and not only.has(original.id):
			continue
		var lv: Dictionary = original
		if _opts.has("moves_override"):
			lv = original.duplicate(true)
			lv.moves = int(_opts.moves_override)
		var entry := {"id": lv.id, "difficulty": lv.difficulty, "moves": lv.moves, "goals": lv.goals, "stars": lv.stars, "bots": {}}
		for bot_name in bots:
			var kind := SimBot.kind_from_name(bot_name)
			var attempts := int(_opts.planner_attempts) if kind == SimBot.Kind.PLANNER else int(_opts.attempts)
			var stats := {"attempts": attempts, "wins": 0, "stars": [0, 0, 0, 0], "moves_on_win": [], "scores_on_win": [], "chains_on_win": [], "scores": [], "reasons": {}, "violations": 0}
			for a in attempts:
				var bot := SimBot.new(kind, hash(lv.id) + a * 7919)
				session.start_level(lv, cat.data_for(lv))
				var inv := Invariants.new()
				var frames := 0
				while not session.is_finished() and frames < max_frames:
					if session.can_drop():
						var x: float = await bot.choose(session, self)
						if session.can_drop():
							session.try_drop(x)
					await physics_frame
					frames += 1
					inv.check(session)
				var reason := String(session.result.get("reason", "timeout"))
				stats.reasons[reason] = stats.reasons.get(reason, 0) + 1
				stats.violations += inv.violations.size()
				for v in inv.violations.slice(0, 3):
					printerr("  İHLAL %s/%s: %s" % [lv.id, bot_name, v])
				if session.result.get("won", false):
					stats.wins += 1
					stats.moves_on_win.append(session.result.moves_used)
					stats.scores_on_win.append(session.score.score)
					stats.chains_on_win.append(session.score.best_chain)
				stats.stars[int(session.result.get("stars", 0))] += 1
				stats.scores.append(session.score.score)
			total_violations += stats.violations
			stats.win_rate = snappedf(float(stats.wins) / attempts, 0.01)
			stats.moves_on_win_median = _median(stats.moves_on_win)
			stats.score_median = _median(stats.scores)
			stats.score_p75 = _percentile(stats.scores, 0.75)
			entry.bots[bot_name] = stats
			print("%s %-8s kazanma %3d%%  yıldız(0/1/2/3)=%s  hamle(ortanca)=%s  puan(ortanca)=%s  nedenler=%s  [%.0f sn]" % [
				lv.id, bot_name, int(stats.win_rate * 100), stats.stars, stats.moves_on_win_median, stats.score_median, stats.reasons,
				(Time.get_ticks_msec() - started) / 1000.0])
		report.levels.append(entry)

	report.violations = total_violations
	var out := ProjectSettings.globalize_path("res://").path_join(String(_opts.out))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f = null
	var md := FileAccess.open(out.get_basename() + ".md", FileAccess.WRITE)
	md.store_string(_markdown(report, bots))
	print("Rapor: ", out, "  ihlal: ", total_violations)
	quit(0 if total_violations == 0 else 1)


func _markdown(report: Dictionary, bots: PackedStringArray) -> String:
	var lines := PackedStringArray()
	var head := "| Bölüm | Zorluk | Hamle |"
	var sep := "|---|---|---|"
	for b in bots:
		head += " %s kazanma |" % b
		sep += "---|"
	head += " Kazanınca hamle (ortanca) | Yıldız 0/1/2/3 (son bot) |"
	sep += "---|---|"
	lines.append(head)
	lines.append(sep)
	for e in report.levels:
		var row := "| %s | %d | %d |" % [e.id, e.difficulty, e.moves]
		var last: Dictionary = {}
		for b in bots:
			var s: Dictionary = e.bots[b]
			row += " %d%% (%d/%d) |" % [int(s.win_rate * 100), s.wins, s.attempts]
			last = s
		row += " %s | %s |" % [last.moves_on_win_median, "/".join(PackedStringArray(last.stars.map(func(v): return str(v))))]
		lines.append(row)
	return "\n".join(lines) + "\n"


func _median(values: Array) -> Variant:
	if values.is_empty():
		return "-"
	var s := values.duplicate()
	s.sort()
	return s[s.size() / 2]


func _percentile(values: Array, p: float) -> Variant:
	if values.is_empty():
		return "-"
	var s := values.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * p))]
