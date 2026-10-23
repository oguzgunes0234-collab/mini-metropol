class_name UiKit
extends RefCounted
## Ortak arayüz parçaları: renkler, yazı, düğme, açılır panel, yıldız ve
## hedef rozeti. GEÇİCİ TASARIM: Aşama 6'da tasarım sistemiyle yenilenecek.

const INK := Color("#2F4858")
const INK_SOFT := Color("#5C7382")
const PAPER := Color("#FFFDF8")
const BACKDROP := Color("#F7F2E8")
const ACCENT := Color("#F26419")
const GOOD := Color("#3E8E48")
const STAR := Color("#F6AE2D")
const STAR_EMPTY := Color("#D8D2C4")
const LOCKED := Color("#B9B2A5")


static func label(text: String, font_size: int, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## primary: koyu dolu düğme; değilse açık zeminli ikincil düğme.
static func button(text: String, font_size: int = 40, primary: bool = true, min_size: Vector2 = Vector2(240, 104)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = min_size
	var bg := INK if primary else PAPER
	var fg := PAPER if primary else INK
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(30)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	if not primary:
		normal.border_color = INK
		normal.set_border_width_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.1) if primary else bg.darkened(0.04)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = LOCKED
	disabled.border_color = LOCKED
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_disabled_color", PAPER)
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
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(44)
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 52
	style.content_margin_bottom = 52
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(min_width, 0)
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
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
		custom_minimum_size = Vector2(96.0 + 10.0 + w + 24.0, 96.0)
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
		draw_string(font, Vector2(size.y + 10, size.y * 0.5 + FONT_SIZE * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiKit.GOOD if goal.get("done", false) else UiKit.INK)


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
