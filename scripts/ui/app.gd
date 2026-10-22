extends Node
## Uygulama kökü: verileri yükler, bölüm listesi ile oyun ekranı arasında geçiş yapar.
## Oyuncu ilerlemesi şimdilik bellekte (Aşama 4'te kalıcı kayıt).

var catalog: LevelCatalog
var progress := Progress.new()
## Şu an görünen ekran (LevelSelect veya GameScreen).
var screen: Node


func _ready() -> void:
	var data := GameData.load_default()
	if not data.is_valid():
		_show_errors(data.errors)
		return
	catalog = LevelCatalog.load_default()
	if not catalog.is_valid():
		_show_errors(catalog.errors)
		return
	show_levels()


func show_levels() -> void:
	var ls := LevelSelect.new()
	_swap(ls)
	ls.setup(catalog, progress)
	ls.level_chosen.connect(play, CONNECT_DEFERRED)
	ls.free_play_chosen.connect(play.bind(""), CONNECT_DEFERRED)


## id boşsa serbest oyun.
func play(id: String) -> void:
	var gs := GameScreen.new()
	gs.name = "Game"
	_swap(gs)
	gs.exit_to_levels.connect(show_levels, CONNECT_DEFERRED)
	gs.play_level.connect(play, CONNECT_DEFERRED)
	gs.start(catalog, progress, catalog.get_level(id) if id != "" else {})


func _swap(next: Node) -> void:
	get_tree().paused = false
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(screen)


func _unhandled_input(event: InputEvent) -> void:
	# Geliştirici: U tüm bölümleri açar.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U and catalog != null:
		progress.unlock_all = true
		if screen is LevelSelect:
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
