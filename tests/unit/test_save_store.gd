extends TestCase
## Yerel kayıt: bozuk, eksik veya kurcalanmış dosyalar oyunu çökertmemeli.

var store: SaveStore


func before_each() -> void:
	store = SaveStore.new("user://test_save_%d.json" % randi())


func after_each() -> void:
	store.erase()
	await super.after_each()


func _write_raw(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_roundtrip() -> void:
	var data := {"a": 1, "b": [1, 2, 3], "c": {"d": "metin ğüşıöç"}}
	assert_true(store.save_data(data))
	var loaded := store.load_data()
	assert_eq(store.last_source, "main")
	# JSON tam sayıları ondalık olarak geri verir; karşılaştırma aynı dönüşümle yapılır.
	assert_eq(JSON.stringify(loaded, "", true), JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true))


func test_missing_file_gives_fresh_start() -> void:
	assert_eq(store.load_data(), {})
	assert_eq(store.last_source, "fresh")


func test_corrupt_main_falls_back_to_backup() -> void:
	store.save_data({"v": 1})
	store.save_data({"v": 2})
	_write_raw(store.path, "{bozuk json")
	var loaded := store.load_data()
	assert_eq(store.last_source, "backup")
	assert_eq(int(loaded.v), 1, "bir önceki kayıt geri gelmeli")
	assert_false(store.warnings.is_empty())


func test_tampered_payload_is_rejected() -> void:
	store.save_data({"coins": 10})
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	doc.payload = doc.payload.replace("10", "99999")
	_write_raw(store.path, JSON.stringify(doc))
	assert_eq(store.load_data(), {}, "sağlaması tutmayan kayıt kullanılmamalı")
	assert_eq(store.last_source, "fresh")


func test_truncated_file_is_rejected() -> void:
	store.save_data({"v": 1})
	store.save_data({"v": 2})
	var text := FileAccess.get_file_as_string(store.path)
	_write_raw(store.path, text.substr(0, text.length() / 2))
	assert_eq(int(store.load_data().v), 1)


func test_unsupported_version_is_rejected() -> void:
	store.save_data({"v": 1})
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	doc.version = 99
	_write_raw(store.path, JSON.stringify(doc))
	assert_eq(store.load_data(), {})


func test_both_files_corrupt_gives_fresh_start() -> void:
	store.save_data({"v": 1})
	store.save_data({"v": 2})
	_write_raw(store.path, "çöp")
	_write_raw(store.path + ".bak", "")
	assert_eq(store.load_data(), {})
	assert_eq(store.last_source, "fresh")


func test_non_object_payload_is_rejected() -> void:
	var payload := "[1,2,3]"
	_write_raw(store.path, JSON.stringify({"version": 1, "checksum": payload.sha256_text(), "payload": payload}))
	assert_eq(store.load_data(), {})


func test_leftover_tmp_does_not_break_save() -> void:
	_write_raw(store.path + ".tmp", "yarım kalmış")
	assert_true(store.save_data({"v": 3}))
	assert_eq(int(store.load_data().v), 3)


func test_erase_removes_all_files() -> void:
	store.save_data({"v": 1})
	store.save_data({"v": 2})
	store.erase()
	assert_false(FileAccess.file_exists(store.path))
	assert_false(FileAccess.file_exists(store.path + ".bak"))
