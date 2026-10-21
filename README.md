# Mini Metropol (geçici ad)

Fizik tabanlı "bırak ve birleştir" bulmaca oyunu. Aynı seviyedeki iki bina
çarpıştığında birleşir ve bir üst seviye bina oluşur. iOS ve Android için
Godot 4 ile geliştiriliyor.

> **Durum:** Erken geliştirme. Görseller geçicidir (bkz. `docs/ASSETS.md`).

## Mac'te oyunu deneme

1. Godot **4.7.2** sürümünü indir: <https://godotengine.org/download/archive/>
   (macOS, "Standard" sürüm — .NET değil). Sürüm 4.7.x olmalı.
2. Bu depoyu indir: GitHub sayfasında **Code → Download ZIP**, ardından ZIP'i aç.
3. Godot'yu aç → **Import** → açtığın klasördeki `project.godot` dosyasını seç.
4. Proje açılınca sağ üstteki **▶ (Run Project)** düğmesine bas.

Fareyle sürükle, bırakınca bina düşer. `R` tuşu yeniden başlatır,
`F3` geliştirici göstergesini açar/kapatır.

## Klasör yapısı

| Klasör | İçerik |
|---|---|
| `data/` | Bina tanımları ve oyun kuralları (JSON). Değerler buradan değiştirilir. |
| `scripts/core/` | Ekrandan bağımsız oyun kuralları (birleşme, puan, sıradaki bina). |
| `scripts/game/` | Oyun sahnesi: bina, oyun alanı, bırakıcı, arayüz. |
| `scenes/` | Godot sahneleri. |
| `tests/` | Otomatik testler ve stres simülasyonu. |
| `tools/` | Kurulum ve test betikleri. |
| `docs/` | Mimari, kararlar, test ve görsel lisans notları. |

## Testleri çalıştırma (geliştirici)

```sh
tools/run_tests.sh          # birim + entegrasyon testleri
tools/run_sim.sh            # stres simülasyonu
```
