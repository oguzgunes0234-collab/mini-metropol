extends SceneTree
## Test çalıştırıcı. Kullanım (proje klasöründe):
##   godot --headless --path . --fixed-fps 120 -s res://tests/run_tests.gd [-- --filter=metin]
## --fixed-fps: her kare tam bir fizik adımı (1/120 sn) olur ve testler gerçek
## zamanı beklemeden hızlı çalışır.

const TEST_DIRS := ["res://tests/unit", "res://tests/integration"]

var _passed := 0
var _failed := 0
var _failed_names: PackedStringArray = []


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)

	var started := Time.get_ticks_msec()
	for dir in TEST_DIRS:
		for path in _list_tests(dir):
			await _run_file(path, filter)

	var secs := (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print("==== SONUÇ: %d başarılı, %d başarısız (%.1f sn) ====" % [_passed, _failed, secs])
	for n in _failed_names:
		print("  BAŞARISIZ: ", n)
	quit(1 if _failed > 0 else 0)


func _run_file(path: String, filter: String) -> void:
	var script := load(path) as Script
	if script == null:
		_failed += 1
		_failed_names.append(path + " (yüklenemedi)")
		return
	var case: TestCase = script.new()
	case.tree = self
	print("\n# ", path.get_file())
	for m in script.get_script_method_list():
		var name: String = m.name
		if not name.begins_with("test_"):
			continue
		var full := "%s:%s" % [path.get_file(), name]
		if filter != "" and not full.contains(filter):
			continue
		case.reset_case()
		await case.before_each()
		await case.call(name)
		await case.after_each()
		if case.failures.is_empty():
			_passed += 1
			print("  ok    ", name)
		else:
			_failed += 1
			_failed_names.append(full)
			print("  HATA  ", name)
			for f in case.failures:
				print("        - ", f)


func _list_tests(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	out.sort()
	return out
