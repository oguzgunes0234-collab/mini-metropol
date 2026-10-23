class_name GameLayout
extends RefCounted
## Oyun ekranının yerleşimi: saf hesap (sahne gerektirmez), bu yüzden her
## ekran oranı ve güvenli alan için birim testiyle denetlenir
## (tests/unit/test_layout.gd).
##
## Dikey düzen (tasarım birimi, içerik 1920 yüksekliğinde):
##   üst sıra (menü, hamle, puan, sıradaki) .......... HUD_ROW
##   hedef rozetleri .................................. GOALS_Y .. HUD_HEIGHT
##   bırakma bölgesi + arsa ........................... arsanın altı: CONTENT_HEIGHT - BOTTOM_SPACE
##   güçlendirici çubuğu .............................. BAR_HEIGHT

const CONTENT_HEIGHT := 1920.0
const CONTENT_WIDTH := 1080.0
## Üst sıranın üst kenardan boşluğu.
const HUD_PAD := 12.0
const HUD_ROW := 120.0
const GOALS_Y := HUD_PAD + HUD_ROW + 8.0
const GOALS_H := 88.0
const HUD_HEIGHT := GOALS_Y + GOALS_H
## Arsa paneli alttan 18 birim taşar; çubuk ondan sonra.
const PANEL_OVERHANG := 18.0
const BAR_GAP := 8.0
const BAR_HEIGHT := 120.0
const BOTTOM_SPACE := PANEL_OVERHANG + BAR_GAP + BAR_HEIGHT + 14.0


## vp: görünür alan (tasarım birimi). safe_top/safe_bottom: çentik ve ana ekran
## çubuğu payları. board_size: bölümün arsa boyutu.
## Dönüş: offset (içeriğin üst kenarı), hud_top, left, width, board_pos, bar_y, toast_y.
static func compute(vp: Vector2, safe_top: float, safe_bottom: float, board_size: Vector2) -> Dictionary:
	var avail := vp.y - safe_top - safe_bottom
	var offset: float
	if avail >= CONTENT_HEIGHT:
		# Güvenli alanın içinde dikey ortala.
		offset = safe_top + (avail - CONTENT_HEIGHT) * 0.5
	else:
		# Sığmıyor (ör. 16:9 ekranda görünür durum çubuğu): çubuk ekranda kalsın diye
		# üst pay elden geldiğince korunur.
		offset = maxf(0.0, minf(safe_top, vp.y - safe_bottom - CONTENT_HEIGHT))
	var width := minf(vp.x, CONTENT_WIDTH)
	var left := (vp.x - width) * 0.5
	var board_bottom := offset + CONTENT_HEIGHT - BOTTOM_SPACE
	var board_pos := Vector2(roundf((vp.x - board_size.x) * 0.5), roundf(board_bottom - board_size.y))
	return {
		"offset": offset,
		"hud_top": offset,
		"left": left,
		"width": width,
		"board_pos": board_pos,
		"bar_y": board_bottom + PANEL_OVERHANG + BAR_GAP,
		"toast_y": board_pos.y + 70.0,
	}
