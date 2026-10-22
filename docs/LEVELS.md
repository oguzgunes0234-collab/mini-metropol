# Bölümler

Bölümler `data/levels.json` dosyasındadır; kod değiştirmeden düzenlenebilir.
Oyun açılırken ve testlerde her alan doğrulanır (`scripts/core/level_catalog.gd`).

## Alanlar

| Alan | Zorunlu | Açıklama |
|---|---|---|
| `id` | evet | Benzersiz kimlik, ör. `1-04` (bölge-sıra) |
| `name_key`, `hint_key` | evet | Ad ve ipucu metninin çeviri anahtarı (`i18n/strings.csv`) |
| `region` | evet | Bölge (Aşama 4'te harita) |
| `difficulty` | evet | 1–5 |
| `mechanic` | evet | Öğretilen/kullanılan mekanik (merge, preview, chain, narrow, obstacle…) |
| `unlock.after` | hayır | Bu bölüm tamamlanınca açılır; yoksa baştan açık |
| `seed` | evet | Bina sırasının tohumu: her denemede aynı sıra gelir (adil ve öğrenilebilir) |
| `moves` | evet | Hamle sınırı |
| `goals` | evet | Hedefler; hepsi tamamlanınca bölüm kazanılır (aşağıda) |
| `stars` | evet | 3 yıldız ölçütü; ilki her zaman `complete` |
| `rewards` | evet | `coins_first`, `coins_repeat` (Aşama 5'te etkinleşecek) |
| `spawn_sequence` | hayır | Öğretici bölümlerde ilk binaların sabit sırası |
| `rules` | hayır | Genel kuralların bölüme özel değerleri (ör. `board.width`, `drop.spawn_levels`) |
| `layout` | hayır | Başlangıçta alanda duran binalar `{level, x, y}` |
| `obstacles` | hayır | Engeller: `{shape: circle, x, y, r}` veya `{shape: rect, x, y, w, h, rot}` |

### Hedef türleri

| Tür | Alanlar | Anlamı |
|---|---|---|
| `build` | `level`, `count` | Birleşmeyle tam bu seviyede `count` bina üret (seviye 2–9) |
| `score` | `value` | En az bu puana ulaş |
| `chain` | `value` | Tek bırakışta en az bu uzunlukta zincir yap |
| `landmark` | `count` | İki İkonik Kule'yi birleştirip Anıt tamamla |

### Yıldız ölçütleri

`complete` (zorunlu ilk yıldız), `moves_used_max` (en fazla bu kadar hamle),
`score` (en az bu puan), `chain` (en az bu uzunlukta zincir). Yıldızlar
bağımsızdır: 2. ve 3. yıldız ayrı ayrı kazanılabilir.

### Kazanma ve kaybetme

- **Kazanma:** Tüm hedefler tamamlandığı anda.
- **Hamleler bitti:** Son bırakmadan sonra binalar durana kadar beklenir;
  bu sırada oluşan birleşmeler de sayılır. Hedef hâlâ tamamlanmadıysa kaybedilir.
- **Arsa doldu:** Tehlike çizgisi süresi doldu ya da bırakma noktası doldu.
- Kaybedince hedeflerin durumu gösterilir. Art arda 2. başarısızlıktan itibaren
  ipucu çıkar (önce bölümün kendi ipucu, sonra genel stratejiler).
  **Satın alma veya reklam önerisi gösterilmez.**

## Doğrulama aracı

```sh
tools/validate_levels.sh                       # tüm bölümler, 3 bot türü
tools/validate_levels.sh --moves_override=200  # hamle sınırı olmadan doğal dağılım
```

Botlar:
- **Rastgele:** stratejisiz oyuncu.
- **Akıllı (greedy):** aynı seviyedeki en yüksek binanın üstüne bırakır.
- **Planlayıcı:** her hamlede ~10 bırakma noktasını kısa süre simüle eder ve
  en iyisini seçer.

Bir botun bir bölümü en az bir kez kazanması, bölümün **bu makinede**
çözülebilir olduğunu gösterir. Fizik farklı cihazlarda birebir aynı sonucu
vermediği için kesin kanıt değildir; zorluk aralıkları bir varsayımdır.

## Ayar yöntemi ve hedef bantlar (varsayım)

Hamle sınırları gerçek sınırla, bot başına 40 denemeyle ölçülerek seçildi
(sınırsız ölçüm yanıltıcıdır; bkz. `tools/validate_levels.gd`).
40 denemede hata payı yaklaşık ±8 puandır.

| Zorluk | Akıllı bot | Rastgele bot |
|---|---|---|
| 1 (öğretici) | ≥%95 | ≥%80 |
| 2 | ≥%85 | %45–75 |
| 3 | %65–85 | %20–50 |
| 4 | %45–75 | ≤%35 (planlayıcı ≥%60) |

Yıldızlar: 2. yıldız ≈ akıllı botun en iyi %25'lik hamle değeri;
3. yıldız ≈ başarılı oyunların üst çeyreğindeki puan veya zincir.

## İlk 10 bölüm — doğrulama sonuçları

120 Hz fizik, dengeli kütleler. Rastgele/akıllı 40, planlayıcı 8 deneme.

| Bölüm | Zorluk | Hamle | Hedef | 2./3. yıldız | Rastgele kazanma | Akıllı kazanma | Planlayıcı kazanma | Akıllı bot yıldız 0/1/2/3 |
|---|---|---|---|---|---|---|---|---|
| 1-01 | 1 | 12 | Seviye 3 ×1 | ≤7 hamle / x2 zincir | %100 (40/40) | %100 (40/40) | %100 (8/8) | 0/0/0/40 |
| 1-02 | 1 | 12 | Seviye 3 ×2 | ≤8 hamle / ≥66 puan | %100 (40/40) | %100 (40/40) | %100 (8/8) | 0/1/39/0 |
| 1-03 | 2 | 8 | Seviye 4 ×1 | ≤7 hamle / ≥91 puan | %78 (31/40) | %100 (40/40) | %100 (8/8) | 0/25/9/6 |
| 1-04 | 2 | 8 | x2 zincir, Seviye 4 ×1 | ≤5 hamle / x3 zincir | %70 (28/40) | %100 (40/40) | %100 (8/8) | 0/29/11/0 |
| 1-05 | 2 | 26 | 500 puan | ≤23 hamle / ≥550 puan | %73 (29/40) | %90 (36/40) | %88 (7/8) | 4/16/20/0 |
| 1-06 | 3 | 16 | Seviye 5 ×1 | ≤14 hamle / ≥455 puan | %35 (14/40) | %50 (20/40) | %100 (8/8) | 20/11/9/0 |
| 1-07 | 3 | 35 | Seviye 6 ×1 | ≤27 hamle / ≥1300 puan | %33 (13/40) | %90 (36/40) | %75 (6/8) | 4/21/15/0 |
| 1-08 | 3 | 22 | Seviye 5 ×2 | ≤20 hamle / ≥650 puan | %53 (21/40) | %75 (30/40) | %100 (8/8) | 10/13/15/2 |
| 1-09 | 4 | 25 | Seviye 6 ×1, x2 zincir | ≤23 hamle / ≥1100 puan | %55 (22/40) | %80 (32/40) | %75 (6/8) | 8/16/16/0 |
| 1-10 | 4 | 47 | Seviye 7 ×1 | ≤38 hamle / ≥2500 puan | %30 (12/40) | %73 (29/40) | %75 (6/8) | 11/5/24/0 |

Tutarlılık ihlali: 0. Godot: 4.7.2-stable (nixpkgs).

Notlar:
- **Her bölüm en az bir bot tarafından kazanıldı** → bu makinede çözülebilir.
- 1-06 bandın biraz zor tarafında (akıllı bot %50, planlayıcı %100). Gerçek oyuncu testinde izlenecek.
- 1-01 ve 1-02 bilerek kolay: öğretici bölümler.
- Gerçek oyuncu verisi olmadan bu oranlar yalnızca karşılaştırma içindir.
