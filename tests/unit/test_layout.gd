extends TestCase
## Oyun ekranı yerleşimi farklı ekran oranlarında ve güvenli alanlarda:
## arayüz ekranda kalır, arsa ve bırakma bölgesi üst arayüzle çakışmaz.

## [ad, görünür alan, üst güvenli pay, alt güvenli pay]
const SCREENS := [
	["16:9 (iPhone SE)", Vector2(1080, 1920), 0.0, 0.0],
	["19.5:9 çentikli (iPhone 15)", Vector2(1080, 2337), 163.0, 94.0],
	["20:9 Android", Vector2(1080, 2400), 90.0, 40.0],
	["21:9 uzun Android", Vector2(1080, 2520), 110.0, 50.0],
	["3:4 tablet (iPad)", Vector2(1440, 1920), 0.0, 55.0],
	["iPad Pro 11 (dikey)", Vector2(1341, 1920), 0.0, 55.0],
	["16:9 görünür durum çubuğu", Vector2(1080, 1920), 55.0, 0.0],
]

## Bölümlerde kullanılan arsa boyutları (genel 900×1280, dar ve alçak bölümler).
const BOARDS := [Vector2(900, 1280), Vector2(720, 1280), Vector2(760, 1280), Vector2(900, 1000), Vector2(720, 1050)]


func test_layout_fits_every_screen_and_board() -> void:
	var data := GameData.load_default()
	var dropper_y := float(data.section("drop").dropper_y)
	# Bırakılan binaların en büyüğü (bölümler en fazla seviye 5 bırakır).
	var largest_drop := data.radius(5)
	for sc in SCREENS:
		var vp: Vector2 = sc[1]
		for board in BOARDS:
			var l := GameLayout.compute(vp, sc[2], sc[3], board)
			var where := "%s, arsa %s" % [sc[0], board]
			var bp: Vector2 = l.board_pos
			assert_true(bp.x >= 0.0 and bp.x + board.x <= vp.x, "arsa yatayda ekranda: " + where)
			assert_true(l.bar_y + GameLayout.BAR_HEIGHT <= vp.y + 0.5, "çubuk ekranda: " + where)
			assert_true(l.hud_top >= 0.0, "üst arayüz ekranda: " + where)
			if vp.y - sc[2] - sc[3] >= GameLayout.CONTENT_HEIGHT:
				assert_true(l.hud_top >= sc[2], "üst arayüz çentiğin altında: " + where)
				assert_true(l.bar_y + GameLayout.BAR_HEIGHT <= vp.y - sc[3] + 0.5, "çubuk ana ekran çubuğunun üstünde: " + where)
			var drop_top: float = bp.y + dropper_y - largest_drop
			assert_true(drop_top >= l.hud_top + GameLayout.HUD_HEIGHT - 2.0,
				"bırakılan bina hedef rozetlerinin altında (%.0f < %.0f): %s" % [drop_top, l.hud_top + GameLayout.HUD_HEIGHT, where])
			assert_true(l.bar_y >= bp.y + board.y + GameLayout.PANEL_OVERHANG, "çubuk arsanın altında: " + where)


func test_tall_screen_centers_content_inside_safe_area() -> void:
	var l := GameLayout.compute(Vector2(1080, 2337), 163.0, 94.0, Vector2(900, 1280))
	var top_gap: float = l.hud_top - 163.0
	var bottom_gap: float = (2337.0 - 94.0) - (l.offset + GameLayout.CONTENT_HEIGHT)
	assert_near(top_gap, bottom_gap, 1.0, "içerik güvenli alanın ortasında")
