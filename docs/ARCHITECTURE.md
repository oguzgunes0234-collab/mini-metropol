# Mimari

Godot 4.7 + GDScript. Dikey ekran, 1080×1920 tasarım çözünürlüğü,
"Compatibility" (OpenGL ES 3) çizim modu.

## Katmanlar

```
scenes/main.tscn
└── App (scripts/ui/app.gd)                Ekran geçişleri, katalog, oyuncu profili ve kaydı
    ├── LevelMap (ui/level_map.gd)         Bölge haritası: bölümler, yıldızlar, kilitler, para
    └── GameScreen (game/game.gd)          Oyun ekranı: girdi, yerleşim, paneller, efektler
        ├── Board (board.gd)               Fizik dünyası: duvarlar, engeller, binalar, birleşme, tehlike
        │   ├── Walls (StaticBody2D)       Duvarlar + güvenlik tavanı + bölüm engelleri
        │   ├── Buildings/ Building×n      (building.gd, RigidBody2D)
        │   ├── Dropper (dropper.gd)       Nişan ve bırakılacak binanın çizimi
        │   └── Effects (effects.gd)       Birleşme halkası, puan yazısı
        ├── Session (game_session.gd)      Oturum kuralları: sıra, hamle, puan, hedef, sonuç, anlık görüntü
        └── Hud (hud.gd, CanvasLayer)      Hamle, puan, sıradaki, hedef rozetleri, giriş/duraklatma/sonuç

scripts/core/   Ekrandan bağımsız, birim testli kurallar
    game_data.gd       JSON verilerini yükler ve doğrular
    level_catalog.gd   Bölümleri doğrular; bölüme özel kurallarla GameData üretir
    level_goals.gd     Hedef ilerlemesi ve yıldız hesabı
    merge_resolver.gd  Hangi çiftler birleşir? (tek merkez, deterministik)
    spawn_queue.gd     Tohumlu bina sırası (+ öğretici sabit başlangıç), durum kaydı
    score_keeper.gd    Puan ve zincir bonusu
    progress.gd        En iyi yıldız/puan, tamamlanma, başarısızlık sayacı
    wallet.gd          Madeni para ve elmas; negatif bakiye olmaz, işlem kaydı
    economy_data.gd    Ekonomi ayarları (data/economy.json) ve doğrulaması
    player_profile.gd  İlerleme + cüzdan + ayarlar; bölüm sonu ödülleri tek yerden
    save_store.gd      Yerel kayıt: atomik yazma, yedek, sağlama, bozulmaya dayanıklı okuma

scripts/ui/ui_kit.gd   Ortak arayüz parçaları (düğme, panel, yıldız, hedef rozeti)
```

Testler ve simülasyon `GameSession` + `Board` ikilisini arayüz olmadan kullanır;
oyun ekranı da aynı ikiliyi kullanır. Böylece test edilen kural, oynanan kuraldır.

### Oturum durumları

```
PLAYING ──(son hamle)──> SETTLING ──(binalar durdu, hedef yok)──> LOST "out_of_moves"
   │                        │
   │                        └──(hedefler tamamlandı)──> WON
   ├──(hedefler tamamlandı)──────────────────────────> WON
   └──(tehlike süresi / bırakma noktası dolu)────────> LOST "danger" / "no_room"
```

### İstenen bileşenlerle eşleşme

| İstenen | Karşılığı | Durum |
|---|---|---|
| GameManager | `GameSession` (kurallar) + `GameScreen`/`App` (akış) | Var |
| MergeManager | `MergeResolver` (karar) + `Board._resolve_merges` (uygulama) | Var |
| Building | `Building` | Var |
| SpawnController | `SpawnQueue` (sıra) + `Dropper` (nişan) | Var |
| ScoreManager | `ScoreKeeper` | Var |
| LevelManager | `LevelCatalog` (veri) + `LevelGoals` (hedef/yıldız) + `GameSession.start_level` | Var |
| UIController | `App`, `LevelMap`, `GameScreen`, `Hud`, `UiKit` | Var |
| SaveManager | `SaveStore` + `PlayerProfile` | Var |
| EconomyManager | `Wallet` + `EconomyData` + `PlayerProfile.apply_result` | Ödüller var; harcama Aşama 5 |
| BoosterManager | — | Aşama 5 |
| ShopController, PurchaseService | — | Aşama 8–9 |

## Birleşme akışı

1. Her fizik karesinde `Board`, birbirine değen aynı seviyedeki çiftleri
   toplar. Her iki binanın temas listesine bakılır (biri uyuyor olsa bile
   kaçırılmaz).
2. `MergeResolver` çiftleri kimlik numarasına göre sıralar ve her binayı en
   fazla bir birleşmeye sokar. Sonuç, adayların sırasından bağımsızdır.
3. İki eski gövde aynı karede sahneden çıkarılır. Yeni bina iki eskinin
   ortasında, duvar/zemine girmeyecek şekilde konumlanır ve %55 boyuttan
   0,14 sn'de büyüyerek komşularını yumuşakça iter.
4. `Board.merged` sinyali → `GameSession` puanı bir kez ekler.

**Son seviye (9 — İkonik Kule):** iki ikonik kule değince "Anıt tamamlandı":
ikisi de kaldırılır, sabit bonus (`rules.final_level.bonus_score`) verilir,
alan rahatlar. `rule: "none"` yapılırsa birleşmezler (test edildi).

## Oyun sonu

- **Tehlike çizgisi:** Arsanın ağzındaki kesikli çizgi. Bir binanın üstü
  çizginin üstünde kaldıkça sayaç dolar (`danger_time_sec`, 2,5 sn); çizgi
  kırmızılaşır. Kısa taşmalar sayılmaz (sayaç geri iner). Yeni bırakılan bina
  ilk 1,2 sn sayılmaz.
- **Bırakma noktası dolu:** Yerleşmiş binalar bırakma noktasına kadar
  yükseldiyse yeni bina başka binanın içinde doğardı; bu durumda arsa dolmuş
  sayılır. Noktada yalnızca hâlâ düşen bir bina varsa bırakma bekletilir.

## Güvenlik ağları

- Toplam hız ve yukarı doğru hız sınırı (`max_speed`, `max_up_speed`).
- Bırakma noktasının çok üstünde görünmez tavan; binalar alandan kaçamaz.
- Fizik 120 Hz, 32 çözücü yinelemesi, dengeli kütleler: ağır yığınlarda küçük
  binaların ezilmesini önler (karar 3 ve 16).
- Son çare kurtarma: merkezi duvar/zemin çizgisini geçen bina sınıra geri
  konur (`stats.rescues`). Sınır denetimi oyun bittikten sonra da çalışır.
- Yine de alan dışına çıkan bina olursa kaydedilir ve kaldırılır
  (`stats.out_of_bounds`); testler bu sayının 0 kaldığını doğrular.

## Anlık görüntü (geri al altyapısı)

`GameSession.capture_snapshot()` alanın (her binanın seviyesi, konumu, açısı,
hızları, büyüme durumu), puanın, hamle sayısının ve bina sırasının (rastgele
sayı üreteci durumu dâhil) tam kopyasını alır. `restore_snapshot()` alanı
temizleyip bu kopyadan yeniden kurar. JSON'a çevrilip geri yüklenebilir
(test edildi). Geri al güçlendiricisi (Aşama 5) bunun üzerine kurulacak.

## Veriler

| Dosya | İçerik |
|---|---|
| `data/buildings.json` | 9 seviye: yarıçap, kütle, birleşme puanı, renkler, ad anahtarı |
| `data/rules.json` | Alan boyutu, fizik, bırakma, birleşme, son seviye, oyun sonu ayarları |
| `data/levels.json` | Bölümler (bkz. [LEVELS.md](LEVELS.md)) |
| `i18n/strings.csv` | Türkçe ve İngilizce metinler |

Veri hatalıysa oyun başlamaz ve hatayı ekranda gösterir. Tüm alanlar
`GameData` içinde doğrulanır.

## Koordinatlar ve yerleşim

`Board` içinde (0,0) arsanın sol üst köşesi, y aşağı doğru artar. Arsa
varsayılan 900×1280; bölümler daraltıp alçaltabilir. İçerik 1920 yüksekliğe göre dizilir; daha uzun telefonlarda dikey,
tabletlerde yatay ortalanır. Mobilde üst güvenli alan (çentik) payı bırakılır.

## Kayıt

`user://save.json` (Godot'nun kullanıcı klasörü; Mac'te
`~/Library/Application Support/Godot/app_userdata/Mini Metropol/`).

- **Ne kaydedilir:** bölüm ilerlemesi (en iyi yıldız/puan, tamamlanma,
  başarısızlık sayacı), serbest oyun rekoru, cüzdan (bakiye + son 50 işlem),
  ayarlar (ses, müzik, titreşim, hareket azaltma), alınmış yıldız ödülleri.
- **Ne zaman:** ilk açılışta, her bölüm sonunda, uygulama arka plana alınınca
  ve kapatılırken.
- **Bozulmaya dayanıklılık:** önce `.tmp` dosyasına yazılır, eski kayıt `.bak`
  olur, sonra `.tmp` yerine taşınır. Okurken sürüm ve SHA-256 sağlaması
  denetlenir; asıl dosya bozuksa yedek, o da bozuksa temiz başlangıç.
  Tek tek alanlar da doğrulanır (ör. yıldız 0–3, bakiye ≥ 0); bozuk alan
  varsayılana döner. Oyun hiçbir kayıt durumunda çökmez (testli).
- Ağ bağlantısı, hesap veya kişisel veri yoktur.

## Bölgeler ve kilitler

`data/regions.json`: Başlangıç Mahallesi, Sahil Bölgesi, Çarşı Bölgesi ve
"Yakında" olarak görünen üç bölge. Bölüm açılması = bölgesi açık **ve** bir
önceki bölüm tamamlanmış. Bölge açılması = belirtilen bölüm tamamlanmış **ve**
toplam yıldız eşiği aşılmış (`LevelCatalog.is_region_unlocked`).
