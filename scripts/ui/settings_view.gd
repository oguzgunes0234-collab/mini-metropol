class_name SettingsView
extends VBoxContainer
## Ayarların içeriği: ses, müzik, titreşim, hareketi azalt, dil, ilerlemeyi
## sıfırlama ve hakkında. Hem tam ekran ayarlar ekranında hem de oyun içi
## duraklatma panelinde kullanılır (orada dil ve sıfırlama gizlenir).
## Değişiklikler profile hemen yazılır; sahibi `changed` ile kaydeder.

## Bir ayar değişti (key: settings anahtarı). Sahibi kaydetmeli.
signal changed(key: String)
## Oyuncu ilerlemeyi sıfırlamayı onayladı.
signal reset_confirmed

const SWITCHES := [
	["sound", "SET_SOUND"],
	["music", "SET_MUSIC"],
	["haptics", "SET_HAPTICS"],
]

var profile: PlayerProfile
var show_language := true
var show_reset := true
var _confirm: Control


func setup(p_profile: PlayerProfile, p_show_language: bool = true, p_show_reset: bool = true) -> void:
	profile = p_profile
	show_language = p_show_language
	show_reset = p_show_reset
	add_theme_constant_override("separation", UiKit.S_SM)
	rebuild()


func rebuild() -> void:
	UiKit.clear(self)
	_section("SET_SECTION_SOUND")
	for sw in SWITCHES:
		add_child(_switch_row(sw[0], tr(sw[1])))
	add_child(UiKit.paragraph(tr("SET_AUDIO_SOON"), UiKit.T_CAPTION, UiKit.INK_SOFT, 760))
	_section("SET_SECTION_ACCESS")
	add_child(_switch_row("reduced_motion", tr("SET_REDUCED_MOTION")))
	add_child(UiKit.paragraph(tr("SET_REDUCED_MOTION_DESC"), UiKit.T_CAPTION, UiKit.INK_SOFT, 760))
	if show_language:
		_section("SET_SECTION_LANGUAGE")
		var row := HBoxContainer.new()
		row.name = "Languages"
		row.add_theme_constant_override("separation", UiKit.S_SM)
		for lang in [["tr", "LANG_TR"], ["en", "LANG_EN"]]:
			var selected: bool = profile.locale() == lang[0]
			var b := UiKit.button(tr(lang[1]), UiKit.T_BODY, "primary" if selected else "secondary", Vector2(300, UiKit.TOUCH))
			b.name = "Lang_" + lang[0]
			b.pressed.connect(_set_language.bind(lang[0]))
			row.add_child(b)
		add_child(row)
	if show_reset:
		_section("SET_SECTION_DATA")
		var reset := UiKit.button(tr("SET_RESET"), UiKit.T_BODY, "danger", Vector2(620, UiKit.TOUCH))
		reset.name = "Reset"
		reset.pressed.connect(_ask_reset)
		add_child(reset)
		_confirm = _build_confirm()
	_section("SET_SECTION_ABOUT")
	add_child(UiKit.label(tr("SET_VERSION") % ProjectSettings.get_setting("application/config/version", "0"), UiKit.T_LABEL, UiKit.INK_SOFT))
	add_child(UiKit.paragraph(tr("SET_FONT_CREDIT"), UiKit.T_CAPTION, UiKit.INK_SOFT, 760))


func switch(key: String) -> UiKit.Switch:
	return find_child("Switch_" + key, true, false) as UiKit.Switch


func _section(key: String) -> void:
	if get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, UiKit.S_MD)
		add_child(gap)
	var l := UiKit.label(tr(key), UiKit.T_CAPTION, UiKit.INK_SOFT)
	l.add_theme_font_override("font", UiKit.font_heavy())
	add_child(l)


func _switch_row(key: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_" + key
	row.custom_minimum_size = Vector2(760, UiKit.TOUCH)
	var l := UiKit.label(text, UiKit.T_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var sw := UiKit.Switch.new(bool(profile.setting(key)), text)
	sw.name = "Switch_" + key
	sw.toggled.connect(func(on: bool):
		profile.settings[key] = on
		changed.emit(key))
	row.add_child(sw)
	return row


func _set_language(lang: String) -> void:
	if profile.locale() == lang and String(profile.setting("language")) == lang:
		return
	profile.settings["language"] = lang
	TranslationServer.set_locale(lang)
	changed.emit("language")
	rebuild()


func _ask_reset() -> void:
	_confirm.visible = true


func _build_confirm() -> Control:
	var o := UiKit.overlay(self, 760)
	var dim: Control = o[0]
	var box: VBoxContainer = o[1]
	dim.name = "ResetConfirm"
	# Paneli bu kutunun değil tüm ekranın üstünde göstermek için üst düzey.
	dim.top_level = true
	box.add_child(UiKit.heading(tr("SET_RESET_CONFIRM_TITLE"), UiKit.T_TITLE))
	box.add_child(UiKit.paragraph(tr("SET_RESET_CONFIRM"), UiKit.T_BODY, UiKit.INK, 640))
	var yes := UiKit.button(tr("SET_RESET_DO"), UiKit.T_BODY, "danger")
	yes.name = "ConfirmReset"
	yes.pressed.connect(func():
		dim.visible = false
		reset_confirmed.emit())
	box.add_child(yes)
	var no := UiKit.button(tr("UI_CANCEL"), UiKit.T_BODY, "secondary")
	no.name = "CancelReset"
	no.pressed.connect(func(): dim.visible = false)
	box.add_child(no)
	return dim
