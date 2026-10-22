class_name App
extends Node
## Uygulama kökü: verileri ve oyuncu kaydını yükler, bölüm haritası ile oyun
## ekranı arasında geçiş yapar. Kayıt her bölüm sonunda ve uygulama arka
## plana alınınca/kapatılınca yazılır.

## Kayıt dosyasının yolu (testler geçici bir yol verir).
static var save_path := SaveStore.DEFAULT_PATH

var catalog: LevelCatalog
var profile: PlayerProfile
var store: SaveStore
## Şu an görünen ekran (LevelMap veya GameScreen).
var screen: Node

## Kısayol: oyuncunun bölüm ilerlemesi.
var progress: Progress:
	get:
		return profile.progress


func _ready() -> void:
	var data := GameData.load_default()
	var economy := EconomyData.load_default()
	if not data.is_valid() or not economy.is_valid():
		_show_errors(data.errors + economy.errors)
		return
	catalog = LevelCatalog.load_default()
	if not catalog.is_valid():
		_show_errors(catalog.errors)
		return
	store = SaveStore.new(save_path)
	var saved := store.load_data()
	for w in store.warnings:
		push_warning("Kayıt: %s" % w)
	if saved.is_empty():
		profile = PlayerProfile.create_new(economy)
		save()
	else:
		profile = PlayerProfile.from_state(saved, economy)
	show_levels()


func save() -> void:
	if store != null and profile != null:
		store.save_data(profile.get_state())


func show_levels() -> void:
	var map := LevelMap.new()
	_swap(map)
	map.setup(catalog, profile)
	map.level_chosen.connect(play, CONNECT_DEFERRED)
	map.free_play_chosen.connect(play.bind(""), CONNECT_DEFERRED)


## id boşsa serbest oyun.
func play(id: String) -> void:
	var gs := GameScreen.new()
	gs.name = "Game"
	_swap(gs)
	gs.exit_to_levels.connect(show_levels, CONNECT_DEFERRED)
	gs.play_level.connect(play, CONNECT_DEFERRED)
	gs.profile_changed.connect(save)
	gs.start(catalog, profile, catalog.get_level(id) if id != "" else {})


func _swap(next: Node) -> void:
	get_tree().paused = false
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(screen)


func _notification(what: int) -> void:
	# Uygulama arka plana alınırken ya da kapanırken kaydet.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


func _unhandled_input(event: InputEvent) -> void:
	# Geliştirici: U tüm bölümleri açar (kaydedilmez).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U and catalog != null:
		profile.progress.unlock_all = true
		if screen is LevelMap:
			screen.refresh()


func _show_errors(errors: PackedStringArray) -> void:
	for e in errors:
		push_error(e)
	var label := Label.new()
	label.text = "%s\n%s" % [tr("DATA_ERROR"), "\n".join(errors)]
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("#B00020"))
	label.position = Vector2(40, 120)
	label.size = Vector2(1000, 1600)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
