class_name SaveStore
extends RefCounted
## Cihazda yerel kayıt. Bozulmaya dayanıklıdır ve asla çökme nedeni olmaz:
## - Yazma: önce "<kayıt>.tmp" dosyasına yazılır; eski kayıt "<kayıt>.bak"
##   olarak saklanır; sonra .tmp asıl kaydın yerine taşınır. Yazma yarıda
##   kesilirse en kötü ihtimalle bir önceki kayıt (.bak) kalır.
## - Dosyada sürüm ve SHA-256 sağlaması bulunur. Sağlama, verinin JSON metni
##   üzerinden hesaplanır (metin olarak saklanır, sayı biçimi değişmez).
## - Okuma: asıl dosya → bozuksa yedek → o da bozuksa boş kayıt.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"

var path: String
## Son okumanın kaynağı: "main", "backup" veya "fresh".
var last_source := ""
## Son okumada karşılaşılan sorunlar (günlük ve test için).
var warnings: PackedStringArray = []


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_data() -> Dictionary:
	warnings.clear()
	for candidate in [[path, "main"], [path + ".bak", "backup"]]:
		var data = _read(candidate[0])
		if data != null:
			last_source = candidate[1]
			if last_source == "backup":
				warnings.append("Asıl kayıt okunamadı; yedekten yüklendi")
			return data
	last_source = "fresh"
	return {}


func save_data(data: Dictionary) -> bool:
	var payload := JSON.stringify(data, "", true)
	var doc := {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"checksum": payload.sha256_text(),
		"payload": payload,
	}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Kayıt yazılamadı: %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	var abs_main := ProjectSettings.globalize_path(path)
	var abs_bak := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_main, abs_bak)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_main)
	if err != OK:
		push_warning("Kayıt yerine taşınamadı: %s" % error_string(err))
		return false
	return true


## Tüm kayıt dosyalarını siler (testler ve "ilerlemeyi sıfırla" için).
func erase() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Dosyayı okur ve doğrular; geçersizse null.
func _read(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var doc = _parse(FileAccess.get_file_as_string(p))
	if typeof(doc) != TYPE_DICTIONARY:
		warnings.append("%s: JSON okunamadı" % p.get_file())
		return null
	if typeof(doc.get("payload")) != TYPE_STRING or typeof(doc.get("checksum")) != TYPE_STRING:
		warnings.append("%s: eksik alan" % p.get_file())
		return null
	if not (typeof(doc.get("version")) in [TYPE_INT, TYPE_FLOAT]) or int(doc.version) > VERSION or int(doc.version) < 1:
		warnings.append("%s: desteklenmeyen sürüm" % p.get_file())
		return null
	if String(doc.payload).sha256_text() != doc.checksum:
		warnings.append("%s: sağlama tutmuyor (dosya bozulmuş)" % p.get_file())
		return null
	var data = _parse(doc.payload)
	if typeof(data) != TYPE_DICTIONARY:
		warnings.append("%s: veri bozuk" % p.get_file())
		return null
	return data


## Sessiz ayrıştırma: bozuk metinde hata günlüğü basmaz, null döner.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
