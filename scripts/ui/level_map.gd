class_name LevelMap
extends Control
## Bölüm haritası: bölgeler (mahalleler) renk bantları hâlinde alt alta;
## her bölgede bölümler zikzak bir yol üzerinde. Kilitli bölüme dokununca
## gereken koşul gösterilir. Üstte madeni para, elmas (varsa) ve toplam yıldız.
## GEÇİCİ TASARIM: Aşama 6'da görsel kimlikle yenilenecek.

signal level_chosen(id: String)
signal free_play_chosen

const WIDTH := 1080.0
const TOP_BAR := 190.0
const HEADER := 230.0
const STEP_Y := 175.0
const NODE_R := 62.0
const COLUMNS: Array[float] = [540.0, 780.0, 540.0, 300.0]
const SOON_HEIGHT := 260.0
const TAP_SLOP := 24.0

var catalog: LevelCatalog
var profile: PlayerProfile

var _scroll: ScrollContainer
var _canvas: MapCanvas
var _coins_label: Label
var _diamonds_label: Label
var _stars_label: Label
var _toast: Label
var _toast_tween: Tween


## Haritanın tamamını çizen tuval. Düğüm konumları burada hesaplanır.
class MapCanvas:
	extends Control
	var map: LevelMap
	## [{level, pos, unlocked, stars, current}]
	var nodes: Array[Dictionary] = []
	## [{region, top, height, unlocked}]
	var bands: Array[Dictionary] = []
	var _press_pos := Vector2.ZERO
	var _pressed := false

	func rebuild() -> void:
		nodes.clear()
		bands.clear()
		var cat := map.catalog
		var progress := map.profile.progress
		var y := 40.0
		var current_found := false
		for r in cat.regions:
			var lv_list := cat.levels_in_region(r.id)
			var height := LevelMap.SOON_HEIGHT if r.coming_soon or lv_list.is_empty() else LevelMap.HEADER + lv_list.size() * LevelMap.STEP_Y + 60.0
			var unlocked := cat.is_region_unlocked(r, progress)
			bands.append({"region": r, "top": y, "height": height, "unlocked": unlocked})
			for i in lv_list.size():
				var lv := lv_list[i]
				var open := cat.is_unlocked(lv, progress)
				var is_current := open and not progress.is_completed(lv.id) and not current_found
				if is_current:
					current_found = true
				nodes.append({
					"level": lv,
					"pos": Vector2(LevelMap.COLUMNS[i % LevelMap.COLUMNS.size()], y + LevelMap.HEADER + i * LevelMap.STEP_Y + LevelMap.STEP_Y * 0.5),
					"unlocked": open,
					"stars": progress.stars(lv.id),
					"current": is_current,
					"accent": r.accent,
				})
			y += height + 30.0
		custom_minimum_size = Vector2(LevelMap.WIDTH, y + 60.0)
		queue_redraw()

	func current_node_y() -> float:
		for n in nodes:
			if n.current:
				return n.pos.y
		return 0.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_press_pos = event.position
			elif _pressed:
				_pressed = false
				if event.position.distance_to(_press_pos) <= LevelMap.TAP_SLOP:
					_tap(event.position)

	func _tap(p: Vector2) -> void:
		for n in nodes:
			if p.distance_to(n.pos) <= LevelMap.NODE_R + 12.0:
				map._on_node_tapped(n)
				return
		for b in bands:
			if p.y >= b.top and p.y <= b.top + LevelMap.HEADER and not b.unlocked:
				map._on_locked_region_tapped(b.region)
				return

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for b in bands:
			var r: Dictionary = b.region
			var rect := Rect2(24, b.top, LevelMap.WIDTH - 48, b.height)
			var style := StyleBoxFlat.new()
			style.bg_color = r.color if b.unlocked or not r.coming_soon else r.color.lerp(Color(0.9, 0.9, 0.9), 0.5)
			style.set_corner_radius_all(48)
			style.border_color = r.accent.lerp(Color.WHITE, 0.45)
			style.set_border_width_all(4)
			style.draw(get_canvas_item(), rect)
			var title := TranslationServer.translate(r.name_key)
			_center(font, title, 54, b.top + 80, UiKit.INK if b.unlocked else UiKit.INK_SOFT)
			_center(font, map._region_status(r, b.unlocked), 32, b.top + 140, r.accent.darkened(0.25) if b.unlocked else UiKit.INK_SOFT)
		# Yol
		for i in range(1, nodes.size()):
			var a: Dictionary = nodes[i - 1]
			var c: Dictionary = nodes[i]
			if a.level.region != c.level.region:
				continue
			var col: Color = c.accent if c.unlocked else UiKit.LOCKED
			draw_line(a.pos, c.pos, col.lerp(Color.WHITE, 0.3), 14.0, true)
		# Düğümler
		for n in nodes:
			var p: Vector2 = n.pos
			var accent: Color = n.accent
			draw_circle(p + Vector2(0, 7), LevelMap.NODE_R, Color(0.1, 0.15, 0.2, 0.18), true, -1.0, true)
			if n.current:
				draw_circle(p, LevelMap.NODE_R + 16, accent.lerp(Color.WHITE, 0.5), true, -1.0, true)
			draw_circle(p, LevelMap.NODE_R, UiKit.PAPER if n.unlocked else UiKit.BACKDROP.darkened(0.08), true, -1.0, true)
			draw_arc(p, LevelMap.NODE_R - 3, 0, TAU, 48, accent if n.unlocked else UiKit.LOCKED, 7, true)
			if n.unlocked:
				_center_at(font, String(n.level.id), 36, p + Vector2(0, -2), UiKit.INK)
				for k in 3:
					var sp := p + Vector2((k - 1) * 40.0, LevelMap.NODE_R + 26.0)
					draw_colored_polygon(UiKit.star_points(sp, 17), UiKit.STAR if k < n.stars else UiKit.STAR_EMPTY)
			else:
				draw_arc(p + Vector2(0, -12), 15, PI, TAU, 16, UiKit.LOCKED, 7, true)
				draw_rect(Rect2(p + Vector2(-22, -10), Vector2(44, 34)), UiKit.LOCKED)

	func _center(font: Font, text: String, fs: int, y: float, color: Color) -> void:
		_center_at(font, text, fs, Vector2(LevelMap.WIDTH * 0.5, y), color)

	func _center_at(font: Font, text: String, fs: int, c: Vector2, color: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func setup(p_catalog: LevelCatalog, p_profile: PlayerProfile) -> void:
	catalog = p_catalog
	profile = p_profile
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(holder)
	_canvas = MapCanvas.new()
	_canvas.map = self
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(_canvas)

	var bar := ColorRect.new()
	bar.color = UiKit.PAPER
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	_coins_label = UiKit.label("", 44, UiKit.INK)
	bar.add_child(_coins_label)
	_diamonds_label = UiKit.label("", 36, UiKit.INK)
	bar.add_child(_diamonds_label)
	bar.gui_input.connect(_on_bar_input)
	_stars_label = UiKit.label("", 44, UiKit.INK)
	bar.add_child(_stars_label)
	var free := UiKit.button(tr("UI_FREE_PLAY"), 34, false, Vector2(300, 96))
	free.name = "FreePlay"
	free.pressed.connect(func(): free_play_chosen.emit())
	bar.add_child(free)
	bar.draw.connect(func(): _draw_bar_icons(bar))

	_toast = UiKit.label("", 34, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toast_bg := StyleBoxFlat.new()
	toast_bg.bg_color = Color(UiKit.INK, 0.92)
	toast_bg.set_corner_radius_all(28)
	toast_bg.content_margin_left = 28
	toast_bg.content_margin_right = 28
	toast_bg.content_margin_top = 18
	toast_bg.content_margin_bottom = 18
	_toast.add_theme_stylebox_override("normal", toast_bg)
	_toast.visible = false
	add_child(_toast)

	refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_scroll_to_current.call_deferred()


func refresh() -> void:
	_canvas.rebuild()
	_coins_label.text = str(profile.wallet.balance("coins"))
	_diamonds_label.text = str(profile.wallet.balance("diamonds"))
	_diamonds_label.visible = _has_diamonds()
	_stars_label.text = "%d / %d" % [profile.progress.total_stars(), catalog.count() * 3]
	get_node("TopBar").queue_redraw()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var bar: Control = get_node("TopBar")
	bar.position = Vector2.ZERO
	bar.size = Vector2(vp.x, TOP_BAR)
	var left := (vp.x - WIDTH) * 0.5
	# Elmas varsa para ve elmas alt alta.
	_coins_label.position = Vector2(left + 110, 30 if _has_diamonds() else 66)
	_coins_label.size = Vector2(260, 60)
	_diamonds_label.position = Vector2(left + 110, 108)
	_diamonds_label.size = Vector2(260, 50)
	_stars_label.position = Vector2(left + 440, 66)
	_stars_label.size = Vector2(260, 60)
	var free: Control = bar.get_node("FreePlay")
	free.position = Vector2(left + WIDTH - 340, 48)
	_scroll.position = Vector2(0, TOP_BAR)
	_scroll.size = Vector2(vp.x, vp.y - TOP_BAR)
	_toast.position = Vector2(left + 90, vp.y - 260)
	_toast.size = Vector2(WIDTH - 180, 0)
	bar.queue_redraw()


func _draw_bar_icons(bar: Control) -> void:
	var left := (get_viewport_rect().size.x - WIDTH) * 0.5
	var c := Vector2(left + 70, 60 if _has_diamonds() else 96)
	bar.draw_circle(c, 30, Color("#F2B33D"), true, -1.0, true)
	bar.draw_circle(c, 20, Color("#F7CD6B"), true, -1.0, true)
	if _has_diamonds():
		UiKit.draw_diamond(bar, Vector2(left + 70, 134), 26)
	bar.draw_colored_polygon(UiKit.star_points(Vector2(left + 400, 96), 30), UiKit.STAR)
	bar.draw_line(Vector2(0, TOP_BAR - 2), Vector2(bar.size.x, TOP_BAR - 2), Color(UiKit.INK, 0.12), 4.0)


func _has_diamonds() -> bool:
	return profile.wallet.balance("diamonds") > 0


## Elmasa dokununca ne işe yarayacağı söylenir.
func _on_bar_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		return
	var left := (get_viewport_rect().size.x - WIDTH) * 0.5
	if _has_diamonds() and Rect2(left + 30, 100, 300, 80).has_point(event.position):
		_show_toast(tr("UI_DIAMONDS_SOON"))


func _scroll_to_current() -> void:
	var y := _canvas.current_node_y()
	_scroll.scroll_vertical = int(maxf(0.0, y - _scroll.size.y * 0.5))


func _region_status(r: Dictionary, unlocked: bool) -> String:
	if r.coming_soon:
		return tr("UI_COMING_SOON")
	var lv_list := catalog.levels_in_region(r.id)
	if unlocked:
		var got := 0
		for lv in lv_list:
			got += profile.progress.stars(lv.id)
		return tr("UI_REGION_STARS") % [got, lv_list.size() * 3]
	return _region_requirement(r)


func _region_requirement(r: Dictionary) -> String:
	var parts := PackedStringArray()
	if r.unlock_after != "" and not profile.progress.is_completed(r.unlock_after):
		parts.append(tr("UI_REQ_LEVEL") % r.unlock_after)
	if profile.progress.total_stars() < r.unlock_stars:
		parts.append(tr("UI_REQ_STARS") % [r.unlock_stars, profile.progress.total_stars()])
	return "%s: %s" % [tr("UI_LOCKED"), ", ".join(parts)]


func _on_node_tapped(n: Dictionary) -> void:
	if n.unlocked:
		level_chosen.emit(n.level.id)
		return
	var r := catalog.region(n.level.region)
	if not catalog.is_region_unlocked(r, profile.progress):
		_show_toast(_region_requirement(r))
	else:
		_show_toast(tr("UI_REQ_LEVEL") % n.level.unlock_after)


func _on_locked_region_tapped(r: Dictionary) -> void:
	_show_toast(tr("UI_COMING_SOON") if r.coming_soon else _region_requirement(r))


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): _toast.visible = false)
