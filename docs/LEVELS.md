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

## Bölgeler

| Bölge | Bölümler | Açılma | Öne çıkan mekanikler |
|---|---|---|---|
| Başlangıç Mahallesi | 1-01 … 1-10 | Baştan açık | Birleşme, önizleme, zincir, puan, dar arsa, kaya, çoklu hedef |
| Sahil Bölgesi | 2-01 … 2-10 | 1-10 + 12★ | Hazır binalarla başlangıç, alçak kayalar, yamaç, çoklu üretim |
| Çarşı Bölgesi | 3-01 … 3-10 | 2-10 + 30★ | Bariyer, arsayı bölen duvar, eğik rampa, kalabalık başlangıç, çok dar pasaj, Gökdelen finali |
| Yeşil Yaşam, Teknoloji, Büyük Metropol | — | "Yakında" | — |

## 30 bölüm — doğrulama sonuçları

120 Hz fizik, 32 çözücü yinelemesi, dengeli kütleler. Rastgele/akıllı 30,
planlayıcı 6 deneme (40'tan az deneme: hata payı ±9 puan civarı).

| Bölüm | Zorluk | Hamle | Hedef | 2./3. yıldız | Rastgele kazanma | Akıllı kazanma | Planlayıcı kazanma | Akıllı bot yıldız 0/1/2/3 |
|---|---|---|---|---|---|---|---|---|
| 1-01 | 1 | 12 | Seviye 3 ×1 | ≤7 hamle / x2 zincir | %100 (30/30) | %100 (30/30) | %100 (6/6) | 0/0/0/30 |
| 1-02 | 1 | 12 | Seviye 3 ×2 | ≤8 hamle / ≥66 puan | %100 (30/30) | %100 (30/30) | %100 (6/6) | 0/0/30/0 |
| 1-03 | 2 | 8 | Seviye 4 ×1 | ≤7 hamle / ≥91 puan | %83 (25/30) | %100 (30/30) | %100 (6/6) | 0/16/8/6 |
| 1-04 | 2 | 8 | x2 zincir, Seviye 4 ×1 | ≤5 hamle / x3 zincir | %67 (20/30) | %100 (30/30) | %100 (6/6) | 0/21/9/0 |
| 1-05 | 2 | 26 | 500 puan | ≤23 hamle / ≥550 puan | %83 (25/30) | %83 (25/30) | %83 (5/6) | 5/13/12/0 |
| 1-06 | 3 | 16 | Seviye 5 ×1 | ≤14 hamle / ≥455 puan | %40 (12/30) | %50 (15/30) | %100 (6/6) | 15/6/9/0 |
| 1-07 | 3 | 35 | Seviye 6 ×1 | ≤27 hamle / ≥1300 puan | %23 (7/30) | %83 (25/30) | %83 (5/6) | 5/11/14/0 |
| 1-08 | 3 | 22 | Seviye 5 ×2 | ≤20 hamle / ≥650 puan | %43 (13/30) | %80 (24/30) | %83 (5/6) | 6/8/14/2 |
| 1-09 | 4 | 25 | Seviye 6 ×1, x2 zincir | ≤23 hamle / ≥1100 puan | %50 (15/30) | %67 (20/30) | %83 (5/6) | 10/11/9/0 |
| 1-10 | 4 | 47 | Seviye 7 ×1 | ≤38 hamle / ≥2500 puan | %40 (12/30) | %70 (21/30) | %100 (6/6) | 9/6/15/0 |
| 2-01 | 2 | 16 | Seviye 5 ×1 | ≤12 hamle / ≥450 puan | %70 (21/30) | %80 (24/30) | %100 (6/6) | 6/10/14/0 |
| 2-02 | 2 | 19 | Seviye 4 ×2 | ≤15 hamle / ≥300 puan | %80 (24/30) | %100 (30/30) | %100 (6/6) | 0/15/15/0 |
| 2-03 | 3 | 13 | Seviye 5 ×1, x2 zincir | ≤10 hamle / ≥300 puan | %60 (18/30) | %63 (19/30) | %83 (5/6) | 11/9/10/0 |
| 2-04 | 3 | 44 | Seviye 6 ×1 | ≤32 hamle / ≥1450 puan | %47 (14/30) | %87 (26/30) | %83 (5/6) | 4/15/11/0 |
| 2-05 | 3 | 12 | Seviye 6 ×1 | ≤10 hamle / ≥750 puan | %73 (22/30) | %90 (27/30) | %100 (6/6) | 3/12/15/0 |
| 2-06 | 3 | 36 | 1500 puan | ≤33 hamle / ≥1800 puan | %50 (15/30) | %93 (28/30) | %100 (6/6) | 2/14/12/2 |
| 2-07 | 4 | 22 | Seviye 6 ×1 | ≤18 hamle / ≥900 puan | %40 (12/30) | %80 (24/30) | %50 (3/6) | 6/3/21/0 |
| 2-08 | 4 | 18 | Seviye 5 ×2, Seviye 4 ×2 | ≤15 hamle / ≥560 puan | %33 (10/30) | %56 (17/30) | %100 (6/6) | 13/5/12/0 |
| 2-09 | 4 | 44 | Seviye 6 ×1, 1500 puan | ≤42 hamle / ≥1800 puan | %13 (4/30) | %60 (18/30) | %50 (3/6) | 12/11/7/0 |
| 2-10 | 4 | 52 | Seviye 7 ×1 | ≤42 hamle / ≥2900 puan | %33 (10/30) | %60 (18/30) | %83 (5/6) | 12/7/9/2 |
| 3-01 | 3 | 30 | Seviye 6 ×1 | ≤24 hamle / ≥1050 puan | %60 (18/30) | %70 (21/30) | %83 (5/6) | 9/3/17/1 |
| 3-02 | 3 | 22 | Seviye 5 ×2 | ≤20 hamle / ≥650 puan | %20 (6/30) | %73 (22/30) | %100 (6/6) | 8/18/4/0 |
| 3-03 | 3 | 20 | Seviye 4 ×4 | ≤18 hamle / ≥600 puan | %47 (14/30) | %90 (27/30) | %100 (6/6) | 3/26/1/0 |
| 3-04 | 4 | 17 | Seviye 6 ×1 | ≤14 hamle / ≥1050 puan | %40 (12/30) | %77 (23/30) | %83 (5/6) | 7/7/16/0 |
| 3-05 | 4 | 24 | Seviye 6 ×1 | ≤20 hamle / ≥900 puan | %20 (6/30) | %47 (14/30) | %0 (0/6) | 16/4/10/0 |
| 3-06 | 4 | 28 | Seviye 6 ×1, x3 zincir | ≤24 hamle / ≥1100 puan | %53 (16/30) | %70 (21/30) | %67 (4/6) | 9/11/10/0 |
| 3-07 | 4 | 20 | Seviye 6 ×1 | ≤17 hamle / ≥950 puan | %40 (12/30) | %56 (17/30) | %33 (2/6) | 13/12/5/0 |
| 3-08 | 5 | 32 | Seviye 6 ×2 | ≤28 hamle / ≥1650 puan | %37 (11/30) | %56 (17/30) | %100 (6/6) | 13/9/8/0 |
| 3-09 | 5 | 64 | Seviye 7 ×1, 3000 puan | ≤56 hamle / ≥3600 puan | %17 (5/30) | %40 (12/30) | %83 (5/6) | 18/8/3/1 |
| 3-10 | 5 | 55 | Seviye 8 ×1 | ≤40 hamle / ≥4500 puan | %27 (8/30) | %53 (16/30) | %50 (3/6) | 14/3/13/0 |

Tutarlılık ihlali: 0. Son çare kurtarma: 0. Godot: 4.7.2-stable (nixpkgs).

Notlar:
- **Her bölüm en az bir bot tarafından kazanıldı** → bu makinede çözülebilir.
- **Beceri farkı küçük** (rastgele ≈ akıllı): 1-05, 2-03, 3-01. Bu bölümlerde
  sonuç büyük ölçüde şansa bağlı olabilir; oyuncu testinden sonra yeniden
  tasarlanmalı.
- 1-06 ve 3-05 bandın zor tarafında; 3-05'te planlayıcı rampayı çözemedi
  (0/6) ama akıllı bot %47 kazandı.
- 1-01 ve 1-02 bilerek kolay: öğretici bölümler.
- Gerçek oyuncu verisi olmadan bu oranlar yalnızca karşılaştırma içindir.
