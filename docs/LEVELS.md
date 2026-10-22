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
