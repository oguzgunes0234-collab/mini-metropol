class_name BuildingArt
extends RefCounted
## Bina çizimleri kodla üretilir (dış görsel dosyası ve lisans gerektirmez).
## Her binanın: kendi rengi, kendine özgü silueti (çatı, kat, pencere düzeni)
## ve köşede seviye numarası vardır; böylece bilgi yalnızca renge dayanmaz.
## Işık sol üstten gelir: gövdenin sağ yüzü ve zemin şeridi koyu, sol üstte
## parlama. Ayrıntı: docs/DESIGN.md.

const FACADE := Color("#FFF7EA")
const WINDOW := Color("#BFE3F2")
const SHADOW := Color(0.11, 0.16, 0.2, 0.22)
const BADGE_TEXT := Color("#FFFFFF")

## Yuvarlatılmış kare gövdenin yarı genişliği; alanı aynı yarıçaplı daireye yakındır.
const BOX_HALF := 0.886
const BOX_CORNER := 0.3


## Bir binayı ci üzerine, yerel (0,0) merkezli olarak çizer.
static func draw_building(ci: CanvasItem, def: Dictionary, r: float, shape_mode: String, alpha: float = 1.0, show_badge: bool = true) -> void:
	var base: Color = def.color
	var accent: Color = def.accent
	base.a *= alpha
	accent.a *= alpha
	var shadow := SHADOW
	shadow.a *= alpha

	if shape_mode == "rounded_box":
		var pts := rounded_box_points(r)
		ci.draw_colored_polygon(_offset(pts, Vector2(0, r * 0.07)), shadow)
		ci.draw_colored_polygon(pts, base)
		var inner := rounded_box_points(r * 0.86)
		ci.draw_colored_polygon(inner, base.lightened(0.22))
	else:
		ci.draw_circle(Vector2(0, r * 0.07), r, shadow, true, -1.0, true)
		ci.draw_circle(Vector2.ZERO, r, base.darkened(0.06), true, -1.0, true)
		ci.draw_circle(Vector2.ZERO, r * 0.88, base.lightened(0.22), true, -1.0, true)
		# Zemin şeridi (dairenin alt kirişi) ve sol üstte parlama
		ci.draw_colored_polygon(_chord(r * 0.88, 0.42), base.darkened(0.05))
		var shine := Color(1, 1, 1, 0.38 * alpha)
		ci.draw_arc(Vector2.ZERO, r * 0.76, PI * 1.08, PI * 1.42, 16, shine, maxf(2.0, r * 0.06), true)

	_draw_silhouette(ci, int(def.level), r, accent, alpha)

	if show_badge:
		_draw_badge(ci, int(def.level), r, accent, alpha)


## Yuvarlatılmış kare fizik/çizim şekli için dışbükey nokta listesi.
static func rounded_box_points(r: float, segments: int = 5) -> PackedVector2Array:
	var half := r * BOX_HALF
	var cr := half * BOX_CORNER
	var pts := PackedVector2Array()
	var centers := [Vector2(half - cr, half - cr), Vector2(-half + cr, half - cr), Vector2(-half + cr, -half + cr), Vector2(half - cr, -half + cr)]
	for i in 4:
		var start_angle := i * PI * 0.5
		for s in segments + 1:
			var a := start_angle + (PI * 0.5) * s / segments
			pts.append(centers[i] + Vector2(cos(a), sin(a)) * cr)
	return pts


## Dairenin, merkezden y = h·rr çizgisinin altında kalan parçası (zemin şeridi).
static func _chord(rr: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := asin(h)
	var steps := 18
	for i in steps + 1:
		var a := a0 + (PI - 2.0 * a0) * i / steps
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


static func _draw_badge(ci: CanvasItem, level: int, r: float, accent: Color, alpha: float) -> void:
	var c := Vector2(r * 0.6, -r * 0.6)
	var br := maxf(r * 0.22, 13.0)
	ci.draw_circle(c, br, accent, true, -1.0, true)
	var font := ThemeDB.fallback_font
	var size := int(maxf(br * 1.25, 14.0))
	var text := str(level)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var col := BADGE_TEXT
	col.a *= alpha
	ci.draw_string(font, c + Vector2(-tw * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# --- Siluet yardımcıları: koordinatlar yarıçap birimindedir ---

static func _rect(ci: CanvasItem, r: float, x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	ci.draw_rect(Rect2(Vector2(x0, y0) * r, Vector2(x1 - x0, y1 - y0) * r), color)


## Cephe bloğu: sağ yüzü gölgeli (derinlik hissi).
static func _block(ci: CanvasItem, r: float, x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	_rect(ci, r, x0, y0, x1, y1, color)
	var side := x1 - (x1 - x0) * 0.24
	_rect(ci, r, side, y0, x1, y1, color.darkened(0.1))


static func _poly(ci: CanvasItem, r: float, pts: Array, color: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(v * r)
	ci.draw_colored_polygon(p, color)


static func _windows(ci: CanvasItem, r: float, x0: float, y0: float, cols: int, rows: int, w: float, h: float, gx: float, gy: float, color: Color) -> void:
	for row in rows:
		for col in cols:
			var x := x0 + col * (w + gx)
			var y := y0 + row * (h + gy)
			_rect(ci, r, x, y, x + w, y + h, color)


static func _draw_silhouette(ci: CanvasItem, level: int, r: float, accent: Color, alpha: float) -> void:
	var facade := FACADE
	facade.a *= alpha
	var win := WINDOW
	win.a *= alpha
	var dark := accent.darkened(0.25)
	match level:
		1: # Kulübe
			_block(ci, r, -0.32, 0.0, 0.32, 0.42, facade)
			_poly(ci, r, [Vector2(-0.44, 0.04), Vector2(0, -0.36), Vector2(0.44, 0.04)], accent)
			_rect(ci, r, -0.09, 0.16, 0.09, 0.42, dark)
		2: # Küçük ev
			_rect(ci, r, 0.16, -0.40, 0.28, -0.14, dark)
			_block(ci, r, -0.38, -0.06, 0.38, 0.42, facade)
			_poly(ci, r, [Vector2(-0.5, -0.04), Vector2(0, -0.44), Vector2(0.5, -0.04)], accent)
			_rect(ci, r, -0.08, 0.16, 0.08, 0.42, dark)
			_rect(ci, r, -0.3, 0.04, -0.15, 0.17, win)
			_rect(ci, r, 0.15, 0.04, 0.3, 0.17, win)
		3: # Modern ev
			_block(ci, r, -0.46, 0.04, 0.46, 0.42, facade)
			_block(ci, r, -0.3, -0.28, 0.36, 0.04, facade)
			_rect(ci, r, -0.36, -0.33, 0.42, -0.27, accent)
			_rect(ci, r, -0.5, -0.01, 0.5, 0.05, accent)
			_rect(ci, r, -0.38, 0.13, -0.02, 0.32, win)
			_rect(ci, r, -0.2, -0.2, 0.26, -0.04, win)
			_rect(ci, r, 0.1, 0.18, 0.26, 0.42, dark)
		4: # Mahalle dükkânı
			_block(ci, r, -0.46, -0.12, 0.46, 0.42, facade)
			_rect(ci, r, -0.3, -0.34, 0.3, -0.16, accent)
			for i in 6:
				var x0 := -0.5 + i * (1.0 / 6.0)
				_poly(ci, r, [Vector2(x0, -0.14), Vector2(x0 + 1.0 / 6.0, -0.14), Vector2(x0 + 1.0 / 6.0, 0.02), Vector2(x0, 0.02)], accent if i % 2 == 0 else facade.darkened(0.04))
			_rect(ci, r, -0.38, 0.1, 0.02, 0.32, win)
			_rect(ci, r, 0.12, 0.1, 0.3, 0.42, dark)
		5: # Apartman
			_block(ci, r, -0.34, -0.5, 0.34, 0.42, facade)
			_rect(ci, r, -0.38, -0.56, 0.38, -0.49, accent)
			_windows(ci, r, -0.26, -0.42, 3, 4, 0.12, 0.1, 0.07, 0.07, win)
			_rect(ci, r, -0.08, 0.26, 0.08, 0.42, dark)
		6: # Ofis binası
			_rect(ci, r, 0.28, -0.1, 0.46, 0.42, facade.darkened(0.06))
			_block(ci, r, -0.3, -0.62, 0.3, 0.42, win.lerp(facade, 0.35))
			_rect(ci, r, -0.33, -0.66, 0.33, -0.6, accent)
			for i in 5:
				var x := -0.3 + i * 0.15
				_rect(ci, r, x - 0.012, -0.6, x + 0.012, 0.42, accent.lerp(facade, 0.3))
			for i in 6:
				var y := -0.48 + i * 0.16
				_rect(ci, r, -0.3, y, 0.3, y + 0.025, accent.lerp(facade, 0.5))
			_rect(ci, r, -0.1, 0.28, 0.1, 0.42, dark)
		7: # Ticaret merkezi
			_block(ci, r, -0.52, -0.16, 0.52, 0.42, facade)
			_block(ci, r, -0.24, -0.46, 0.24, -0.16, facade.darkened(0.05))
			_rect(ci, r, -0.27, -0.5, 0.27, -0.45, accent)
			_rect(ci, r, -0.18, -0.38, 0.18, -0.24, accent)
			_rect(ci, r, -0.56, -0.2, 0.56, -0.14, accent)
			_rect(ci, r, -0.44, 0.02, 0.44, 0.24, win)
			_rect(ci, r, -0.12, 0.24, 0.12, 0.42, dark)
		8: # Gökdelen
			_block(ci, r, -0.26, -0.28, 0.26, 0.42, facade)
			_block(ci, r, -0.18, -0.7, 0.18, -0.28, facade.darkened(0.04))
			_rect(ci, r, -0.015, -0.86, 0.015, -0.7, accent)
			_rect(ci, r, -0.21, -0.74, 0.21, -0.69, accent)
			_rect(ci, r, -0.29, -0.31, 0.29, -0.26, accent)
			_windows(ci, r, -0.12, -0.62, 2, 4, 0.09, 0.05, 0.06, 0.05, win)
			_windows(ci, r, -0.2, -0.18, 3, 4, 0.1, 0.06, 0.05, 0.05, win)
			_rect(ci, r, -0.08, 0.3, 0.08, 0.42, dark)
		_: # İkonik kule (son seviye)
			_rect(ci, r, -0.46, 0.26, 0.46, 0.42, accent)
			for side in [-1.0, 1.0]:
				var x0: float = 0.12 * side
				var x1: float = 0.36 * side
				_block(ci, r, minf(x0, x1), -0.5, maxf(x0, x1), 0.26, facade)
				_poly(ci, r, [Vector2(minf(x0, x1), -0.5), Vector2((x0 + x1) * 0.5, -0.74), Vector2(maxf(x0, x1), -0.5)], accent)
				_windows(ci, r, minf(x0, x1) + 0.04, -0.42, 2, 6, 0.07, 0.06, 0.02, 0.05, win)
			_rect(ci, r, -0.12, -0.22, 0.12, -0.12, accent)
			_poly(ci, r, [Vector2(0, -0.66), Vector2(0.06, -0.52), Vector2(0, -0.38), Vector2(-0.06, -0.52)], accent.lightened(0.35))
