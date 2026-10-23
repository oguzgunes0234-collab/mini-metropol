class_name SettingsScreen
extends Control
## Tam ekran ayarlar: üstte geri düğmesi ve başlık, altında kaydırılabilir
## ayarlar kartı (SettingsView).

signal back_pressed
## Bir ayar değişti; sahibi kaydetmeli.
signal changed(key: String)
signal reset_confirmed

var profile: PlayerProfile
var view: SettingsView
var _header: Control
var _scroll: ScrollContainer
var _title: Label


func setup(p_profile: PlayerProfile) -> void:
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
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var card := UiKit.card(UiKit.S_XL)
	center.add_child(card)
	view = SettingsView.new()
	view.setup(profile)
	view.changed.connect(_on_changed)
	view.reset_confirmed.connect(func(): reset_confirmed.emit())
	card.add_child(view)

	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var back := UiKit.IconButton.new("back", tr("UI_BACK"))
	back.name = "Back"
	back.pressed.connect(func(): back_pressed.emit())
	_header.add_child(back)
	_title = UiKit.heading(tr("UI_SETTINGS"), UiKit.T_TITLE)
	_header.add_child(_title)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _on_changed(key: String) -> void:
	if key == "language":
		_title.text = tr("UI_SETTINGS")
		UiKit.accessible(_header.get_node("Back"), tr("UI_BACK"))
	changed.emit(key)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var top := UiKit.S_LG + App.safe_top(vp)
	var left := (vp.x - minf(vp.x, 1080.0)) * 0.5
	_header.position = Vector2(left, top)
	_header.size = Vector2(minf(vp.x, 1080.0), UiKit.TOUCH)
	var back: Control = _header.get_node("Back")
	back.position = Vector2(UiKit.S_MD, 0)
	_title.position = Vector2(0, 0)
	_title.size = Vector2(_header.size.x, UiKit.TOUCH)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var scroll_top := top + UiKit.TOUCH + UiKit.S_MD
	_scroll.position = Vector2(0, scroll_top)
	_scroll.size = Vector2(vp.x, vp.y - scroll_top)
