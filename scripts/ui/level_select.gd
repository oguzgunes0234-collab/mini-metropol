class_name LevelSelect
extends Control
## Bölüm listesi: bölge adı, toplam yıldız, bölüm kutucukları (yıldızlar ve
## kilit durumu) ve serbest oyun düğmesi. Aşama 4'te bölge haritasıyla değişecek.

signal level_chosen(id: String)
signal free_play_chosen

const COLUMNS := 3
const TILE := Vector2(300, 230)
const GAP := 30.0

var catalog: LevelCatalog
var progress: Progress

var _tiles: Array[LevelTile] = []
var _stars_label: Label
var _content: Control


## Tek bir bölüm kutucuğu; dokununca seçer (kilitliyse tepki vermez).
class LevelTile:
	extends Control
	signal chosen(id: String)
	var level: Dictionary
	var stars := 0
	var unlocked := false
	var _pressed := false

	func _init(p_level: Dictionary) -> void:
		level = p_level
		custom_minimum_size = LevelSelect.TILE
		size = LevelSelect.TILE
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if not unlocked:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				queue_redraw()
			elif _pressed:
				_pressed = false
				queue_redraw()
				if Rect2(Vector2.ZERO, size).has_point(event.position):
					chosen.emit(level.id)

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.set_corner_radius_all(36)
		bg.bg_color = UiKit.PAPER if unlocked else UiKit.BACKDROP.darkened(0.06)
		if _pressed:
			bg.bg_color = UiKit.STAR.lightened(0.6)
		bg.border_color = UiKit.INK.lightened(0.55) if unlocked else UiKit.LOCKED
		bg.set_border_width_all(4)
		bg.shadow_color = Color(0.18, 0.28, 0.35, 0.10)
		bg.shadow_size = 10
		bg.shadow_offset = Vector2(0, 5)
		bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		var ink := UiKit.INK if unlocked else UiKit.LOCKED
		_center_text(font, String(level.id), 52, size.y * 0.32, ink)
		_center_text(font, TranslationServer.translate(level.name_key), 28, size.y * 0.52, ink)
		if unlocked:
			for i in 3:
				var c := Vector2(size.x * 0.5 + (i - 1) * 56.0, size.y * 0.78)
				draw_colored_polygon(UiKit.star_points(c, 22), UiKit.STAR if i < stars else UiKit.STAR_EMPTY)
		else:
			_draw_lock(Vector2(size.x * 0.5, size.y * 0.78))

	func _center_text(font: Font, text: String, fs: int, y: float, color: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) * 0.5, y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _draw_lock(c: Vector2) -> void:
		draw_arc(c + Vector2(0, -10), 16, PI, TAU, 16, UiKit.LOCKED, 7, true)
		draw_rect(Rect2(c + Vector2(-24, -8), Vector2(48, 36)), UiKit.LOCKED)


func setup(p_catalog: LevelCatalog, p_progress: Progress) -> void:
	catalog = p_catalog
	progress = p_progress
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var title := UiKit.label(tr("REGION_STARTER"), 64, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 120)
	title.size = Vector2(1080, 90)
	_content.add_child(title)
	_stars_label = UiKit.label("", 36, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_stars_label.position = Vector2(0, 215)
	_stars_label.size = Vector2(1080, 50)
	_content.add_child(_stars_label)

	var grid_w := COLUMNS * TILE.x + (COLUMNS - 1) * GAP
	for i in catalog.count():
		var tile := LevelTile.new(catalog.levels[i])
		tile.position = Vector2((1080 - grid_w) * 0.5 + (i % COLUMNS) * (TILE.x + GAP), 320 + (i / COLUMNS) * (TILE.y + GAP))
		tile.chosen.connect(func(id: String): level_chosen.emit(id))
		_content.add_child(tile)
		_tiles.append(tile)

	var rows := ceili(float(catalog.count()) / COLUMNS)
	var free := UiKit.button(tr("UI_FREE_PLAY"), 42, false, Vector2(420, 110))
	free.position = Vector2((1080 - 420) * 0.5, 320 + rows * (TILE.y + GAP) + 40)
	free.pressed.connect(func(): free_play_chosen.emit())
	_content.add_child(free)

	refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()


func refresh() -> void:
	var total := 0
	for t in _tiles:
		t.unlocked = progress.is_unlocked(t.level)
		t.stars = progress.stars(t.level.id)
		total += 3
		t.queue_redraw()
	_stars_label.text = tr("UI_STARS_TOTAL") % [progress.total_stars(), total]


func _layout() -> void:
	var vp := get_viewport_rect().size
	_content.position = Vector2(roundf((vp.x - 1080.0) * 0.5), roundf(maxf(0.0, (vp.y - 1920.0) * 0.5)))
