# Tasarım sistemi (Aşama 6)

Kaynak: `scripts/ui/ui_kit.gd` (belirteçler ve bileşenler),
`scripts/game/game_layout.gd` (oyun ekranı yerleşimi). Ekranlar bu iki
dosyadaki değerleri kullanır; sabit renk ve boyut yazmaz.

## İlkeler
- Sıcak, temiz, okunaklı: krem zemin, koyu lacivert yazı, binalarda canlı renkler.
- Bilgi yalnızca renkle verilmez: binalarda seviye numarası ve farklı siluet;
  anahtarlarda konum ve işaret (✓ / –); yıldızlarda dolu/boş biçim.
- Dokunulan her şey en az ~44 pt (`TOUCH` = 120 tasarım birimi).
- En küçük yazı ~10 pt (`T_CAPTION` = 28); gövde yazısı 38.
- Kısa, ölçülü geri bildirim; "Hareketi azalt" açıkken hareketli efektler sadeleşir.

## Ölçek
Tasarım çözünürlüğü 1080×1920 (dikey). 1080 birim genişlik ≈ telefonda
390 pt → **1 pt ≈ 2,8 birim**.

## Renkler
| Belirteç | Değer | Kullanım | Kontrast (krem zemin) |
|---|---|---|---|
| `INK` | #2F4858 | Ana yazı, koyu düğme | 9,4 |
| `INK_SOFT` | #4E6474 | İkincil yazı | 6,1 / 5,5 |
| `PAPER` | #FFFDF8 | Kart, panel | — |
| `BACKDROP` | #F7F2E8 | Ekran zemini | — |
| `ACCENT` | #F26419 | Ana eylem düğmesi (büyük kalın yazıyla) | 3,1 (büyük yazı ölçütü ≥3) |
| `ACCENT_TEXT` | #C2410C | Turuncu yazı | 5,1 |
| `GOOD` / `GOOD_TEXT` | #3E8E48 / #2E7D32 | Başarı dolgusu / yeşil yazı | — / 5,0 |
| `DANGER` | #B3261E | Geri alınamaz eylem (ilerlemeyi sıfırla) | 6,4 |
| `STAR`, `STAR_EMPTY` | #F6AE2D, #D8D2C4 | Yıldızlar (biçimle birlikte) | — |

Bölge yazıları bölgenin vurgu renginden, kendi zemininde ≥4,5:1 olacak
şekilde koyulaştırılır (`UiKit.region_text`). Kontrastlar
`tests/unit/test_design_system.gd` ile denetlenir.

## Yazı
Yazı tipi **Nunito** (SIL OFL 1.1; bkz. [ASSETS.md](ASSETS.md)): gövde Bold
(700), başlık ve sayılar ExtraBold (800). Türkçe harfler (ğ, ş, İ…) ayrı
"latin-ext" dosyasından yedek olarak gelir; test bunu doğrular.

| Belirteç | Boyut | Kullanım |
|---|---|---|
| `T_DISPLAY` | 104 | Oyun adı |
| `T_TITLE` | 60 | Ekran/panel başlığı |
| `T_HEADING` | 46 | Ana düğme |
| `T_BODY` | 38 | Gövde, satırlar |
| `T_LABEL` | 32 | Açıklama |
| `T_CAPTION` | 28 | En küçük: rozet, bölüm başlığı |

## Boşluk ve köşe
`S_XS 8 · S_SM 16 · S_MD 24 · S_LG 36 · S_XL 56` — `R_SM 20 · R_MD 30 · R_LG 44`.

## Bileşenler
| Bileşen | Açıklama |
|---|---|
| `button(text, size, kind)` | primary (koyu), secondary (çerçeveli), accent (turuncu ana eylem), danger (kırmızı) |
| `IconButton` | Kare simge düğmesi (duraklat, ayarlar, geri, kapat); ekran okuyucu adı zorunlu |
| `Switch` | Açık/kapalı anahtarı; durum renk + konum + işaretle |
| `CurrencyPill` | Para, elmas, yıldız göstergesi |
| `card()`, `overlay()` | Kart ve karartılmış zemin üstünde panel |
| `heading()`, `label()`, `paragraph()` | Yazılar (en küçük boyut zorunlu) |
| `StarRow`, `GoalChip`, `CoinIcon`, `DiamondIcon`, `BoosterIcon` | Oyun öğeleri |
| `Hud.StatCard`, `Hud.BoosterButton` | Oyun ekranı kartları ve güçlendirici düğmesi |

## Ekranlar
| # | Şartnamedeki ekran | Durum |
|---|---|---|
| 1 | Ana menü | **Yeni**: siluet, oyun adı, para/yıldız, Oyna (sıradaki bölüm yazılı), Serbest Oyun, Ayarlar |
| 2 | Bölüm haritası | Yeni üst çubuk: geri, para, elmas, yıldız, ayarlar |
| 3 | Oyun ekranı | Yeni üst sıra (duraklat, hamle, puan, sıradaki kartları), hedef rozetleri, güçlendirici çubuğu |
| 4 | Bölüm hedefi ve sonuç | Giriş ve sonuç panelleri tasarım sistemiyle |
| 5 | Duraklatma | Devam / Yeniden başla / **Ayarlar** / Bölümlere dön |
| 6 | Güçlendirici arayüzü | Çubuk, satın alma paneli, vinç seçimi (Aşama 5) |
| 7 | Şehir geliştirme | Aşama 8 |
| 8 | Mağaza ve kozmetik | Aşama 8 |
| 9 | Ayarlar | **Yeni**: ses, müzik, titreşim, hareketi azalt, dil (Türkçe/English), ilerlemeyi sıfırla (onaylı), hakkında. Oyun içinden de açılır (dil ve sıfırlama hariç) |

Gezinme: Ana menü → Oyna → Harita → Bölüm → (sonuç) → sonraki bölüm veya
harita. Android geri tuşu: ayarlar/harita → bir önceki ekran, ana menü →
çıkış, oyun → duraklat.

## Ekran oranları ve güvenli alan
Oyun ekranı yerleşimi `GameLayout.compute` ile hesaplanır ve birim testiyle
7 ekran tipi × 5 arsa boyutunda denetlenir (`tests/unit/test_layout.gd`):
16:9, çentikli 19,5:9, 20:9, 21:9, iPad 3:4, iPad Pro 11, görünür durum
çubuklu 16:9. Kurallar:
- İçerik (1920 birim) güvenli alanın içinde dikey ortalanır; tabletlerde
  yatayda ortalanır.
- Üst arayüz çentiğin, çubuk ana ekran çubuğunun dışında kalır (yer varsa).
- Bırakılan en büyük bina (seviye 5) hedef rozetlerinin altında kalır.
- Yer yoksa (16:9 ekranda görünür durum çubuğu) çubuk ekranda kalsın diye
  üst pay feda edilir. iOS'ta durum çubuğu oyunda gizlenecek (Aşama 10'da
  dışa aktarma ayarı olarak doğrulanacak).

Ekran görüntüleri: `tools/screenshots.sh` (9:16, 9:19,5 çentik benzetimi,
tablet; Türkçe ve İngilizce).

## Erişilebilirlik
- Kontrast ve en küçük boyutlar testlerle denetlenir; ayrıca tüm ekranlarda
  görünen her düğmenin ≥ `TOUCH`, her yazının ≥ `T_CAPTION` olduğu bir
  arayüz testi var.
- Simge düğmelerinde ve anahtarlarda ekran okuyucu adı (`accessibility_name`)
  ve ipucu metni verilir. Ekran okuyucuyla gerçek cihazda **test edilmedi**.
- Hareketi azalt: kayan yazılar ve halkalar sadeleşir, vinç vurgusu yanıp sönmez.

## Bilinen eksikler
- Ses/müzik henüz yok (Aşama 7); ayarları kaydediliyor.
- Ekran geçiş animasyonları Aşama 7'de.
- Yazı boyutunu büyütme ayarı yok (dinamik yazı boyutu desteği ileride).
