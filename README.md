# Mini Metropol (geçici ad)

Fizik tabanlı "bırak ve birleştir" bulmaca oyunu. Aynı seviyedeki iki bina
çarpıştığında birleşir ve bir üst seviye bina oluşur. iOS ve Android için
Godot 4 ile geliştiriliyor.

> **Durum:** Erken geliştirme. Görseller geçicidir (bkz. `docs/ASSETS.md`).

## Mac'te oyunu deneme

1. Godot **4.7.2**'yi indir: <https://godotengine.org/download/archive/>
   → 4.7.2 → macOS → **Standard** (".NET" olmayan). Sürüm 4.7.x olmalı.
2. Projeyi indir. GitHub'da geliştirme dalını seç ve **Code → Download ZIP**
   ile indir, ardından ZIP'i aç.
3. Godot'yu aç → **Import** → açtığın klasördeki `project.godot` dosyasını seç
   → **Import & Edit**.
4. Sağ üstteki **▶ (Run Project)** düğmesine bas (kısayol: `Cmd+B`).

### Kontroller

| Girdi | Ne yapar |
|---|---|
| Fareyle sürükle, bırak | Nişan al ve binayı bırak (telefonda parmakla) |
| `Boşluk` | Nişan alınan yere bırak |
| `R` | Yeniden başlat |
| `F3` | Geliştirici göstergesi (FPS, bina sayısı, fizik süresi) |
| `B` | Bina şeklini değiştir: daire ↔ yuvarlatılmış kare (deneysel) |

## Klasör yapısı

| Klasör | İçerik |
|---|---|
| `data/` | Bina tanımları ve oyun kuralları (JSON). Değerler buradan değiştirilir. |
| `scripts/core/` | Ekrandan bağımsız oyun kuralları (birleşme, puan, sıradaki bina). |
| `scripts/game/` | Oyun sahnesi: bina, oyun alanı, bırakıcı, arayüz. |
| `scenes/` | Godot sahneleri. |
| `i18n/` | Türkçe ve İngilizce metinler. |
| `tests/` | Otomatik testler, tutarlılık denetimi, test botu. |
| `tools/` | Kurulum, test, simülasyon, lint ve ekran görüntüsü betikleri. |
| `docs/` | [Mimari](docs/ARCHITECTURE.md), [kararlar](docs/DECISIONS.md), [testler](docs/TESTING.md), [görsel lisansları](docs/ASSETS.md). |

## Geliştirici komutları (Linux)

```sh
tools/setup_env.sh      # Godot 4.7.2 kurulumu (Nix ile)
tools/run_tests.sh      # birim + entegrasyon testleri
tools/run_sim.sh 5000   # stres simülasyonu
tools/lint.sh           # GDScript denetimi
tools/screenshots.sh    # ekran görüntüleri
```
