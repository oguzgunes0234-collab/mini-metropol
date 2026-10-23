class_name MainMenu
extends Control
## Ana menü: oyunun adı, şehir silueti, para/yıldız, "Oyna" (bölüm
## haritası), "Serbest Oyun" ve "Ayarlar".

signal play_pressed
signal free_play_pressed
signal settings_pressed

var catalog: LevelCatalog
var profile: PlayerProfile
var _top: HBoxContainer
var _hero: Skyline
var _content: VBoxContainer


## Seviye 1'den 9'a binaların yan yana dizildiği şehir silueti (kodla çizilir).
class Skyline:
	extends Control
	var data: GameData

	func _draw() -> void:
		if data == null:
			return
		var ground := size.y - 40.0
		draw_rect(Rect2(0, ground, size.x, 40), Color("#8FB996"))
		draw_rect(Rect2(0, ground, size.x, 8), Color("#7AA982"))
		# Büyükten küçüğe sırayla, ortada en büyük: göz ortadan iki yana akar.
		var order := [1, 3, 5, 7, 9, 8, 6, 4, 2]
		var scale := Skyline.scale_for(data, size.x)
		var total := Skyline.total_width(data)
		var x := (size.x - total * scale * 0.8) * 0.5
		for lv in order:
			var r := data.radius(lv) * scale
			draw_set_transform(Vector2(x + r, ground - r + 6.0))
			BuildingArt.draw_building(self, data.level_def(lv), r, "circle", 1.0, false)
			draw_set_transform(Vector2.ZERO)
			x += r * 1.6

	static func total_width(d: GameData) -> float:
		var total := 0.0
		for lv in range(1, d.max_level + 1):
			total += d.radius(lv) * 2.0
		return total

	static func scale_for(d: GameData, width: float) -> float:
		return (width - 40.0) / total_width(d) * 1.25

	## Siluetin çizilmesi için gereken yükseklik (en büyük bina + zemin).
	static func height_for(d: GameData, width: float) -> float:
		return d.radius(d.max_level) * 2.0 * scale_for(d, width) + 50.0


func setup(p_catalog: LevelCatalog, p_profile: PlayerProfile) -> void:
	catalog = p_catalog
	profile = p_profile
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiKit.BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_top = HBoxContainer.new()
	_top.alignment = BoxContainer.ALIGNMENT_CENTER
	_top.add_theme_constant_override("separation", UiKit.S_SM)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var coins := UiKit.CurrencyPill.new("coins")
	coins.set_text(str(profile.wallet.balance("coins")))
	_top.add_child(coins)
	if profile.wallet.balance("diamonds") > 0:
		var diamonds := UiKit.CurrencyPill.new("diamonds")
		diamonds.set_text(str(profile.wallet.balance("diamonds")))
		_top.add_child(diamonds)
	var stars := UiKit.CurrencyPill.new("stars")
	stars.set_text("%d / %d" % [profile.progress.total_stars(), catalog.count() * 3])
	_top.add_child(stars)

	_content = VBoxContainer.new()
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", UiKit.S_MD)
	add_child(_content)
	_hero = Skyline.new()
	_hero.data = catalog.base
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_hero)
	_content.add_child(UiKit.heading(tr("GAME_TITLE"), UiKit.T_DISPLAY))
	_content.add_child(UiKit.label(tr("MENU_TAGLINE"), UiKit.T_BODY, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, UiKit.S_MD)
	_content.add_child(spacer)
	var play := UiKit.button(tr("MENU_PLAY"), UiKit.T_HEADING, "accent", Vector2(640, UiKit.TOUCH + 16))
	play.name = "Play"
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): play_pressed.emit())
	_content.add_child(play)
	var next := next_level()
	if not next.is_empty():
		_content.add_child(UiKit.label(tr("MENU_NEXT_FMT") % [next.id, tr(next.name_key)], UiKit.T_LABEL, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var free := UiKit.button(tr("UI_FREE_PLAY"), UiKit.T_BODY + 4, "secondary", Vector2(640, UiKit.TOUCH))
	free.name = "FreePlay"
	free.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	free.pressed.connect(func(): free_play_pressed.emit())
	_content.add_child(free)
	var settings := UiKit.button(tr("UI_SETTINGS"), UiKit.T_BODY + 4, "secondary", Vector2(640, UiKit.TOUCH))
	settings.name = "Settings"
	settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings.pressed.connect(func(): settings_pressed.emit())
	_content.add_child(settings)

	get_viewport().size_changed.connect(_layout)
	_layout()


## Oyuncunun sıradaki bölümü (açık ve tamamlanmamış ilk bölüm; hepsi bittiyse boş).
func next_level() -> Dictionary:
	for lv in catalog.levels:
		if catalog.is_unlocked(lv, profile.progress) and not profile.progress.is_completed(lv.id):
			return lv
	return {}


func _layout() -> void:
	var vp := get_viewport_rect().size
	var top := UiKit.S_LG + App.safe_top(vp)
	var w := minf(vp.x, 1080.0)
	var left := (vp.x - w) * 0.5
	_top.position = Vector2(left, top)
	_top.size = Vector2(w, 84)
	# Siluet, başlık ve düğmeler üst çubuğun altındaki alanda dikey ortalanır.
	_hero.custom_minimum_size = Vector2(w - 80, Skyline.height_for(catalog.base, w - 80))
	var content_top := top + 84 + UiKit.S_LG
	_content.position = Vector2(left, content_top)
	_content.size = Vector2(w, maxf(0.0, vp.y - content_top - UiKit.S_XL - App.safe_insets(vp).y))
