extends TestCase
## Tasarım sistemi: yazı/zemin kontrastı (WCAG AA), en küçük yazı ve dokunma
## hedefi, yazı tipinin Türkçe harfleri içermesi, bölge yazı renkleri.


func test_text_colors_meet_contrast_on_light_backgrounds() -> void:
	for fg in [UiKit.INK, UiKit.INK_SOFT, UiKit.ACCENT_TEXT, UiKit.GOOD_TEXT, UiKit.DANGER]:
		for bg in [UiKit.PAPER, UiKit.BACKDROP]:
			assert_true(UiKit.contrast(fg, bg) >= 4.5, "%s üstünde %s: %.2f" % [bg.to_html(false), fg.to_html(false), UiKit.contrast(fg, bg)])


func test_button_text_contrast() -> void:
	# Koyu, kırmızı ve yeşil düğmelerde açık yazı: normal yazı ölçütü (4,5).
	for bg in [UiKit.INK, UiKit.DANGER, UiKit.GOOD_TEXT]:
		assert_true(UiKit.contrast(UiKit.PAPER, bg) >= 4.5, bg.to_html(false))
	# Turuncu ana düğme yalnızca büyük kalın yazıyla kullanılır: büyük yazı ölçütü (3).
	assert_true(UiKit.contrast(UiKit.PAPER, UiKit.ACCENT) >= 3.0)


func test_region_text_colors_are_readable() -> void:
	var cat := LevelCatalog.load_default()
	for r in cat.regions:
		var c := UiKit.region_text(r.accent, r.color)
		assert_true(UiKit.contrast(c, r.color) >= 4.5, "%s bölge yazısı %.2f" % [r.id, UiKit.contrast(c, r.color)])


func test_minimum_sizes() -> void:
	assert_true(UiKit.T_CAPTION >= 28, "en küçük yazı ~10 pt")
	assert_true(UiKit.TOUCH >= 120, "dokunma hedefi ~44 pt")
	assert_true(UiKit.label("x", 10).get_theme_font_size("font_size") >= UiKit.T_CAPTION, "küçük yazı en küçük boyuta yükseltilir")
	assert_true(UiKit.button("x", 30, true, Vector2(100, 60)).custom_minimum_size.y >= UiKit.TOUCH)


func test_font_covers_turkish_letters() -> void:
	for f: Font in [UiKit.font(), UiKit.font_heavy()]:
		assert_true(f is FontVariation, "Nunito yüklenmeli")
		var text := "ğüşıöçĞÜŞİÖÇ Mini Metropol 0123456789 ×–…"
		for i in text.length():
			var ch := text.unicode_at(i)
			var found: bool = f.has_char(ch)
			for fb in f.fallbacks:
				found = found or fb.has_char(ch)
			assert_true(found, "eksik harf: %s" % text[i])
