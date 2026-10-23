class_name App
extends Node
## Uygulama kökü: verileri ve oyuncu kaydını yükler; ana menü, bölüm haritası,
## ayarlar ve oyun ekranı arasında geçiş yapar. Kayıt her bölüm sonunda, her
## ayar değişikliğinde ve uygulama arka plana alınınca/kapatılınca yazılır.

## Kayıt dosyasının yolu (testler geçici bir yol verir).
static var save_path := SaveStore.DEFAULT_PATH

var catalog: LevelCatalog
var profile: PlayerProfile
var store: SaveStore
## Şu an görünen ekran (MainMenu, LevelMap, SettingsScreen veya GameScreen).
var screen: Node

## Kısayol: oyuncunun bölüm ilerlemesi.
var progress: Progress:
	get:
		return profile.progress


## Testler ve araçlar için: güvenli alan payı (çentik), tasarım biriminde.
static var safe_area_override := Vector2(-1, -1)


func _ready() -> void:
	UiKit.apply_global_theme()
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
	TranslationServer.set_locale(profile.locale())
	show_menu()


func save() -> void:
	if store != null and profile != null:
		store.save_data(profile.get_state())


func show_menu() -> void:
	var menu := MainMenu.new()
	menu.name = "Menu"
	_swap(menu)
	menu.setup(catalog, profile)
	menu.play_pressed.connect(show_levels, CONNECT_DEFERRED)
	menu.free_play_pressed.connect(play.bind(""), CONNECT_DEFERRED)
	menu.settings_pressed.connect(show_settings.bind("menu"), CONNECT_DEFERRED)


func show_levels() -> void:
	var map := LevelMap.new()
	map.name = "Map"
	_swap(map)
	map.setup(catalog, profile)
	map.level_chosen.connect(play, CONNECT_DEFERRED)
	map.back_pressed.connect(show_menu, CONNECT_DEFERRED)
	map.settings_pressed.connect(show_settings.bind("map"), CONNECT_DEFERRED)


## from: geri dönülecek ekran ("menu" veya "map").
func show_settings(from: String) -> void:
	var st := SettingsScreen.new()
	st.name = "Settings"
	_swap(st)
	st.setup(profile)
	st.changed.connect(func(_key: String): save())
	st.back_pressed.connect(show_levels if from == "map" else show_menu, CONNECT_DEFERRED)
	st.reset_confirmed.connect(reset_progress, CONNECT_DEFERRED)


## Ayarlardaki "İlerlemeyi sıfırla" (onaydan sonra): yeni oyuncu profili, ayarlar korunur.
func reset_progress() -> void:
	var keep := profile.settings.duplicate()
	profile = PlayerProfile.create_new(profile.economy)
	profile.settings = keep
	save()
	show_menu()


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
	# Android geri tuşu: ayarlar/harita → bir önceki ekran, ana menü → çıkış.
	# Oyun ekranı geri tuşunu kendisi ele alır (duraklatır).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen is SettingsScreen:
			screen.back_pressed.emit()
		elif screen is LevelMap:
			show_menu.call_deferred()
		elif screen is MainMenu:
			save()
			get_tree().quit()


## Çentik/durum çubuğu (x) ve ana ekran çubuğu (y) payları, tasarım biriminde.
static func safe_insets(vp: Vector2) -> Vector2:
	if safe_area_override.x >= 0.0:
		return safe_area_override
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var scale := vp.y / float(win.y)
	return Vector2(float(safe.position.y) * scale, float(win.y - safe.end.y) * scale)


static func safe_top(vp: Vector2) -> float:
	return safe_insets(vp).x


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
