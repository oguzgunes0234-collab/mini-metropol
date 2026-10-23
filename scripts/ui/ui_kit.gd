class_name UiKit
extends RefCounted
## Tasarım sistemi: renk, yazı, boşluk ve köşe belirteçleri; yazı tipi ve
## genel tema; ortak bileşenler (düğme, simge düğmesi, anahtar, kart, panel,
## yıldız, para/elmas, hedef rozeti, güçlendirici simgesi). Ayrıntı:
## docs/DESIGN.md. Bileşenler yalnızca bu belirteçleri kullanır.

# --- Renkler ---
# Yazı renkleri PAPER ve BACKDROP üzerinde en az 4,5:1 kontrast verir
# (tests/unit/test_design_system.gd). Dolgu renkleri (ACCENT, GOOD) yalnızca
# büyük kalın yazıyla ya da yazısız kullanılır.
const INK := Color("#2F4858")
const INK_SOFT := Color("#4E6474")
const PAPER := Color("#FFFDF8")
const BACKDROP := Color("#F7F2E8")
const SURFACE := Color("#EFE8DA")
const LINE := Color("#2F485824")
const ACCENT := Color("#F26419")
const ACCENT_TEXT := Color("#C2410C")
const GOOD := Color("#3E8E48")
const GOOD_TEXT := Color("#2E7D32")
const DANGER := Color("#B3261E")
const STAR := Color("#F6AE2D")
const STAR_EMPTY := Color("#D8D2C4")
const LOCKED := Color("#B9B2A5")
const SHADOW := Color("#1C2A3424")

# --- Yazı ölçeği (tasarım birimi; 1080 genişlikte ~2,8 birim ≈ 1 pt) ---
const T_DISPLAY := 104
const T_TITLE := 60
const T_HEADING := 46
const T_BODY := 38
const T_LABEL := 32
## En küçük yazı (~10 pt). Bunun altında yazı kullanılmaz.
const T_CAPTION := 28

# --- Boşluk, köşe, dokunma ---
const S_XS := 8
const S_SM := 16
const S_MD := 24
const S_LG := 36
const S_XL := 56
const R_SM := 20
const R_MD := 30
const R_LG := 44
## En küçük dokunma hedefi (~44 pt; Apple ve Google önerisi).
const TOUCH := 120

const FONT_REGULAR := "res://assets/fonts/nunito-latin-700-normal.woff2"
const FONT_REGULAR_EXT := "res://assets/fonts/nunito-latin-ext-700-normal.woff2"
const FONT_HEAVY := "res://assets/fonts/nunito-latin-800-normal.woff2"
const FONT_HEAVY_EXT := "res://assets/fonts/nunito-latin-ext-800-normal.woff2"

static var _font: Font
static var _font_heavy: Font


## Gövde yazı tipi (Nunito Bold; Türkçe harfler için latin-ext yedekli).
static func font() -> Font:
	if _font == null:
		_font = _load_font(FONT_REGULAR, FONT_REGULAR_EXT)
	return _font


## Başlık ve sayı yazı tipi (Nunito ExtraBold).
static func font_heavy() -> Font:
	if _font_heavy == null:
		_font_heavy = _load_font(FONT_HEAVY, FONT_HEAVY_EXT)
	return _font_heavy


static func _load_font(path: String, ext_path: String) -> Font:
	var base := load(path) as Font
	if base == null:
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	var fallbacks: Array[Font] = []
	var ext := load(ext_path) as Font
	if ext != null:
		fallbacks.append(ext)
	# Son çare: motorun yerleşik yazı tipi (ör. özel simgeler için).
	fallbacks.append(ThemeDB.get_default_theme().default_font)
	v.fallbacks = fallbacks
	return v


## Uygulama açılırken bir kez: tüm arayüz ve kodla çizilen yazılar Nunito kullanır.
static func apply_global_theme() -> void:
	var f := font()
	var theme := ThemeDB.get_default_theme()
	if theme.default_font != f:
		theme.default_font = f
	theme.default_font_size = T_BODY
	ThemeDB.fallback_font = f
	ThemeDB.fallback_font_size = T_BODY


## WCAG göreli parlaklık ve kontrast oranı (testler ve renk seçimi için).
static func luminance(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Vurgu renginden, verilen açık zeminde okunabilir (≥4,5:1) yazı rengi.
static func region_text(accent: Color, bg: Color = BACKDROP) -> Color:
	var c := accent
	while contrast(c, bg) < 4.6 and c.get_luminance() > 0.02:
		c = c.darkened(0.08)
	return c


## Ekran okuyucu için ad (motor destekliyorsa).
static func accessible(c: Control, name: String) -> void:
	if "accessibility_name" in c:
		c.set("accessibility_name", name)
	c.tooltip_text = name


static func label(text: String, font_size: int, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(font_size, T_CAPTION))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Kalın başlık (ExtraBold).
static func heading(text: String, font_size: int = T_TITLE, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, font_size, color, align)
	l.add_theme_font_override("font", font_heavy())
	return l


## Satır kaydırmalı paragraf.
static func paragraph(text: String, font_size: int = T_LABEL, color: Color = INK_SOFT, width: float = 640.0) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func flat_box(bg: Color, radius: int = R_MD, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.anti_aliasing = true
	return sb


## Düğme türleri: "primary" (koyu dolu), "secondary" (açık, çerçeveli),
## "accent" (turuncu, ana eylem), "danger" (kırmızı, geri alınamaz eylem).
## Geriye uyum: primary parametresi bool olarak da verilebilir.
static func button(text: String, font_size: int = 42, primary: Variant = true, min_size: Vector2 = Vector2(240, TOUCH)) -> Button:
	var kind: String = ("primary" if primary else "secondary") if typeof(primary) == TYPE_BOOL else String(primary)
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font_heavy())
	b.custom_minimum_size = Vector2(min_size.x, maxf(min_size.y, TOUCH))
	b.focus_mode = Control.FOCUS_NONE
	var bg: Color = {"primary": INK, "secondary": PAPER, "accent": ACCENT, "danger": DANGER}.get(kind, INK)
	var fg := INK if kind == "secondary" else PAPER
	var normal := flat_box(bg, R_MD, INK, 4 if kind == "secondary" else 0)
	normal.content_margin_left = 32
	normal.content_margin_right = 32
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08) if kind != "secondary" else bg.darkened(0.04)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.18) if kind != "secondary" else SURFACE
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = LOCKED
	disabled.border_color = LOCKED
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_disabled_color", PAPER)
	accessible(b, text)
	return b


## Ekranı karartan, ortasında kart bulunan panel. Dönüş: [overlay, içerik kutusu].
static func overlay(parent: Control, min_width: float = 760.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.15, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	parent.add_child(dim)
	var panel := PanelContainer.new()
	var style := flat_box(PAPER, R_LG)
	style.content_margin_left = S_XL
	style.content_margin_right = S_XL
	style.content_margin_top = S_XL - 4
	style.content_margin_bottom = S_XL - 4
	style.shadow_color = SHADOW
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(min_width, 0)
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", S_MD)
	panel.add_child(box)
	return [dim, box]


static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


## Beş köşeli yıldız noktaları.
static func star_points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts


## Kazanılan/kazanılmayan yıldızları gösteren satır.
class StarRow:
	extends Control
	var flags: Array = [false, false, false]
	var star_size := 40.0

	func _init(p_flags: Array = [false, false, false], p_size: float = 40.0) -> void:
		flags = p_flags
		star_size = p_size
		custom_minimum_size = Vector2(star_size * 2.4 * flags.size(), star_size * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_flags(p_flags: Array) -> void:
		flags = p_flags
		queue_redraw()

	func _draw() -> void:
		var step := star_size * 2.4
		var x0 := (size.x - step * flags.size()) * 0.5 + step * 0.5
		for i in flags.size():
			var c := Vector2(x0 + i * step, size.y * 0.5)
			draw_colored_polygon(UiKit.star_points(c, star_size), UiKit.STAR if flags[i] else UiKit.STAR_EMPTY)


## Madeni para simgesi.
class CoinIcon:
	extends Control
	var radius := 22.0

	func _init(p_radius: float = 22.0) -> void:
		radius = p_radius
		custom_minimum_size = Vector2(radius * 2.2, radius * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, radius, Color("#E39B1F"), true, -1.0, true)
		draw_circle(c, radius * 0.72, Color("#F7CD6B"), true, -1.0, true)


## Bir hedefin simgesi ve ilerlemesi ("1/2", "350/600", "x2/x3").
class GoalChip:
	extends Control
	var data: GameData
	var goal: Dictionary = {}
	var shape_mode := "circle"

	const FONT_SIZE := 34

	func _init(p_data: GameData, p_goal: Dictionary) -> void:
		data = p_data
		shape_mode = data.section("physics").shape_mode
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_goal(p_goal)

	func set_goal(p_goal: Dictionary) -> void:
		goal = p_goal
		# Genişlik en uzun ilerleme yazısına ("900/900") göre: yazı asla kesilmez.
		var target := int(goal.get("target", 0))
		var widest := "%d/%d" % [target, target]
		var w := ThemeDB.fallback_font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		custom_minimum_size = Vector2(88.0 + 10.0 + w + 24.0, 88.0)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = UiKit.GOOD.lightened(0.75) if goal.get("done", false) else UiKit.PAPER
		bg.set_corner_radius_all(26)
		bg.border_color = UiKit.GOOD if goal.get("done", false) else UiKit.INK.lightened(0.6)
		bg.set_border_width_all(3)
		bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var icon_c := Vector2(size.y * 0.5 + 4, size.y * 0.5)
		var r := size.y * 0.36
		match String(goal.type):
			"build":
				draw_set_transform(icon_c)
				BuildingArt.draw_building(self, data.level_def(int(goal.level)), r, shape_mode, 1.0, false)
				draw_set_transform(Vector2.ZERO)
			"landmark":
				draw_set_transform(icon_c)
				BuildingArt.draw_building(self, data.level_def(data.max_level), r, shape_mode, 1.0, false)
				draw_set_transform(Vector2.ZERO)
			"score":
				draw_colored_polygon(UiKit.star_points(icon_c, r), UiKit.STAR)
			"chain":
				var font := ThemeDB.fallback_font
				draw_circle(icon_c, r, UiKit.ACCENT, true, -1.0, true)
				var t := "x%d" % int(goal.target)
				var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
				draw_string(font, icon_c + Vector2(-w * 0.5, 11), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiKit.PAPER)
		var text := UiKit.goal_progress_text(goal)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(size.y + 10, size.y * 0.5 + FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiKit.GOOD_TEXT if goal.get("done", false) else UiKit.INK)


## Tamamlanan hedef yeşil yazılır (yazı tipinde onay işareti bulunmayabilir).
static func goal_progress_text(g: Dictionary) -> String:
	return "%d/%d" % [int(g.get("progress", 0)), int(g.target)]


## Hedefin cümle hâli ("Modern Ev üret", "600 puana ulaş").
static func goal_text(data: GameData, g: Dictionary) -> String:
	match String(g.type):
		"build":
			var name := TranslationServer.translate(data.level_def(int(g.level)).name_key)
			var t := TranslationServer.translate("GOAL_BUILD") % name
			return t if int(g.count) == 1 else "%s ×%d" % [t, int(g.count)]
		"score":
			return TranslationServer.translate("GOAL_SCORE") % int(g.value)
		"chain":
			return TranslationServer.translate("GOAL_CHAIN") % int(g.value)
		"landmark":
			var t := TranslationServer.translate("GOAL_LANDMARK")
			return t if int(g.count) == 1 else "%s ×%d" % [t, int(g.count)]
	return ""


## Yıldız ölçütünün cümle hâli.
static func star_text(s: Dictionary) -> String:
	match String(s.type):
		"moves_used_max":
			return TranslationServer.translate("STAR_MOVES") % int(s.value)
		"score":
			return TranslationServer.translate("STAR_SCORE") % int(s.value)
		"chain":
			return TranslationServer.translate("STAR_CHAIN") % int(s.value)
	return TranslationServer.translate("STAR_COMPLETE")


# --- Güçlendiriciler ve elmas ---

const BOOSTER_COLORS := {
	"undo": Color("#3E7CB1"),
	"swap": Color("#8E5DB0"),
	"crane": Color("#E39B1F"),
	"relieve": Color("#3E8E48"),
	"extra_moves": Color("#F26419"),
}


static func booster_name(id: String) -> String:
	return TranslationServer.translate("BOOSTER_" + id.to_upper())


## Açıklama metni; etki ayarı (vinç/temizle seviyesi, ek hamle sayısı) yerine konur.
static func booster_desc(id: String, def: Dictionary) -> String:
	var t := TranslationServer.translate("BOOSTER_%s_DESC" % id.to_upper())
	match id:
		"crane", "relieve":
			return t % int(def.get("max_level", 0))
		"extra_moves":
			return t % int(def.get("amount", 0))
	return t


## Güçlendirici simgesi (GEÇİCİ ÇİZİM): yuvarlak zemin üstünde basit bir işaret.
## extra_amount: ek hamle simgesinde yazılacak sayı.
static func draw_booster_icon(ci: CanvasItem, id: String, c: Vector2, r: float, extra_amount: int = 5) -> void:
	var col: Color = BOOSTER_COLORS.get(id, INK)
	ci.draw_circle(c, r, col, true, -1.0, true)
	var w := maxf(3.0, r * 0.16)
	var ink := PAPER
	match id:
		"undo":
			# Saat yönünün tersine dönen ok
			ci.draw_arc(c, r * 0.5, -PI * 0.85, PI * 0.55, 24, ink, w, true)
			var tip := c + Vector2(cos(-PI * 0.85), sin(-PI * 0.85)) * r * 0.5
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.28, r * 0.02), tip + Vector2(r * 0.16, -r * 0.2), tip + Vector2(r * 0.12, r * 0.28)]), ink)
		"swap":
			# Karşılıklı iki ok
			for k: int in [-1, 1]:
				var y := c.y + k * r * 0.24
				var dir := float(k)
				ci.draw_line(Vector2(c.x - r * 0.45, y), Vector2(c.x + r * 0.45, y), ink, w, true)
				var head := Vector2(c.x + dir * r * 0.5, y)
				ci.draw_colored_polygon(PackedVector2Array([head, head + Vector2(-dir * r * 0.24, -r * 0.16), head + Vector2(-dir * r * 0.24, r * 0.16)]), ink)
		"crane":
			# Halat ve kanca
			ci.draw_line(c + Vector2(0, -r * 0.62), c + Vector2(0, r * 0.08), ink, w, true)
			ci.draw_arc(c + Vector2(-r * 0.16, r * 0.1), r * 0.24, 0.0, PI * 1.05, 16, ink, w, true)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.7), Vector2(r * 0.6, r * 0.14)), ink)
		"relieve":
			# Süpürge
			ci.draw_line(c + Vector2(r * 0.45, -r * 0.55), c + Vector2(-r * 0.05, r * 0.1), ink, w, true)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.15, r * 0.0), c + Vector2(r * 0.12, r * 0.22),
				c + Vector2(-r * 0.2, r * 0.6), c + Vector2(-r * 0.6, r * 0.3)]), ink)
		"extra_moves":
			var font := ThemeDB.fallback_font
			var fs := int(r * 0.9)
			var t := "+%d" % extra_amount
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## Bir güçlendirici simgesini çizen küçük denetim (panellerde ve ödül satırlarında).
class BoosterIcon:
	extends Control
	var id := ""
	var radius := 22.0
	var amount := 5

	func _init(p_id: String, p_radius: float = 22.0, p_amount: int = 5) -> void:
		id = p_id
		radius = p_radius
		amount = p_amount
		custom_minimum_size = Vector2(radius * 2.2, radius * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.draw_booster_icon(self, id, size * 0.5, radius, amount)


static func draw_diamond(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.2)])
	ci.draw_colored_polygon(pts, Color("#4FB3D9"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2), c + Vector2(0, -r * 0.05)]), Color("#9EDCF2"))


## Elmas simgesi.
class DiamondIcon:
	extends Control
	var radius := 22.0

	func _init(p_radius: float = 22.0) -> void:
		radius = p_radius
		custom_minimum_size = Vector2(radius * 2.2, radius * 2.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.draw_diamond(self, size * 0.5, radius)



# --- Ortak bileşenler (Aşama 6) ---

## Simge çizer (GEÇİCİ ÇİZİM DEĞİL: basit geometrik simgeler, lisans gerektirmez).
## id: pause, settings, back, close, play, map
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(4.0, r * 0.2)
	match id:
		"pause":
			for dx in [-0.32, 0.32]:
				ci.draw_rect(Rect2(c + Vector2(dx * r - w * 0.6, -r * 0.55), Vector2(w * 1.2, r * 1.1)), col)
		"settings":
			# Dişli: dış halka + 8 diş + iç delik
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var p0 := c + d * r * 0.55
				var p1 := c + d * r * 0.95
				ci.draw_colored_polygon(PackedVector2Array([p0 - n * r * 0.17, p1 - n * r * 0.12, p1 + n * r * 0.12, p0 + n * r * 0.17]), col)
			ci.draw_circle(c, r * 0.68, col, true, -1.0, true)
			ci.draw_circle(c, r * 0.28, PAPER, true, -1.0, true)
		"back":
			ci.draw_line(c + Vector2(r * 0.55, 0), c + Vector2(-r * 0.45, 0), col, w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.5), c + Vector2(-r * 0.55, 0), c + Vector2(-r * 0.05, r * 0.5)]), col, w, true)
		"close":
			ci.draw_line(c + Vector2(-r, -r) * 0.48, c + Vector2(r, r) * 0.48, col, w, true)
			ci.draw_line(c + Vector2(r, -r) * 0.48, c + Vector2(-r, r) * 0.48, col, w, true)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.55), c + Vector2(r * 0.6, 0), c + Vector2(-r * 0.4, r * 0.55)]), col)
		"map":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.4), c + Vector2(-r * 0.2, -r * 0.55), c + Vector2(r * 0.2, -r * 0.4), c + Vector2(r * 0.6, -r * 0.55), c + Vector2(r * 0.6, r * 0.4), c + Vector2(r * 0.2, r * 0.55), c + Vector2(-r * 0.2, r * 0.4), c + Vector2(-r * 0.6, r * 0.55), c + Vector2(-r * 0.6, -r * 0.4)]), col, w * 0.8, true)
			ci.draw_line(c + Vector2(-r * 0.2, -r * 0.55), c + Vector2(-r * 0.2, r * 0.4), col, w * 0.6, true)
			ci.draw_line(c + Vector2(r * 0.2, -r * 0.4), c + Vector2(r * 0.2, r * 0.55), col, w * 0.6, true)


## Kare simge düğmesi (en az TOUCH boyutunda). Ekran okuyucu adı zorunludur.
class IconButton:
	extends Control
	signal pressed
	var icon := ""
	var dark := false
	var _down := false

	func _init(p_icon: String, p_name: String, p_dark: bool = false) -> void:
		icon = p_icon
		dark = p_dark
		name = "Icon_" + p_icon
		custom_minimum_size = Vector2(UiKit.TOUCH, UiKit.TOUCH)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		UiKit.accessible(self, p_name)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_down = event.pressed
			queue_redraw()
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()

	func _draw() -> void:
		var bg := UiKit.INK if dark else UiKit.PAPER
		if _down:
			bg = bg.darkened(0.15) if dark else UiKit.SURFACE
		UiKit.flat_box(bg, UiKit.R_MD, UiKit.LINE, 0 if dark else 3).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		UiKit.draw_icon(self, icon, size * 0.5, minf(size.x, size.y) * 0.3, UiKit.PAPER if dark else UiKit.INK)


## Açık/kapalı anahtarı (ayarlar). Dokunma alanı TOUCH yüksekliğinde.
class Switch:
	extends Control
	signal toggled(on: bool)
	var on := false

	func _init(p_on: bool, p_name: String) -> void:
		on = p_on
		custom_minimum_size = Vector2(150, UiKit.TOUCH)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		UiKit.accessible(self, p_name)

	func set_on(value: bool) -> void:
		on = value
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				on = not on
				queue_redraw()
				toggled.emit(on)

	func _draw() -> void:
		var track := Rect2(Vector2((size.x - 128) * 0.5, (size.y - 72) * 0.5), Vector2(128, 72))
		UiKit.flat_box(UiKit.GOOD if on else UiKit.LOCKED, 36).draw(get_canvas_item(), track)
		var knob_x := track.end.x - 36 if on else track.position.x + 36
		draw_circle(Vector2(knob_x, track.get_center().y), 28, UiKit.PAPER, true, -1.0, true)
		# Durum yalnızca renkle değil, düğmenin konumu ve içindeki işaretle de anlaşılır.
		var mark := Vector2(knob_x, track.get_center().y)
		if on:
			draw_polyline(PackedVector2Array([mark + Vector2(-11, 1), mark + Vector2(-3, 9), mark + Vector2(12, -8)]), UiKit.GOOD_TEXT, 6, true)
		else:
			draw_line(mark + Vector2(-9, 0), mark + Vector2(9, 0), UiKit.INK_SOFT, 6, true)


## Para / elmas / yıldız göstergesi (üst çubuklar).
class CurrencyPill:
	extends Control
	var kind := "coins"
	var text := "0"

	func _init(p_kind: String) -> void:
		kind = p_kind
		name = "Pill_" + p_kind
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_text("0")

	func set_text(t: String) -> void:
		text = t
		var w := UiKit.font_heavy().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		custom_minimum_size = Vector2(96 + w + 28, 84)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		UiKit.flat_box(UiKit.PAPER, 42, UiKit.LINE, 3).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var c := Vector2(48, size.y * 0.5)
		match kind:
			"coins":
				draw_circle(c, 26, Color("#E39B1F"), true, -1.0, true)
				draw_circle(c, 18, Color("#F7CD6B"), true, -1.0, true)
			"diamonds":
				UiKit.draw_diamond(self, c, 26)
			"stars":
				draw_colored_polygon(UiKit.star_points(c, 28), UiKit.STAR)
		draw_string(UiKit.font_heavy(), Vector2(88, size.y * 0.5 + 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiKit.INK)


## Kart: açık zeminli, köşeleri yuvarlak içerik kutusu.
static func card(padding: int = S_LG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat_box(PAPER, R_LG, LINE, 3)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = padding
	sb.content_margin_bottom = padding
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p
