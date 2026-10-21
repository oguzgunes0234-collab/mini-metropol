# Mimari

Godot 4.7 + GDScript. Dikey ekran, 1080×1920 tasarım çözünürlüğü,
"Compatibility" (OpenGL ES 3) çizim modu.

## Katmanlar

```
scenes/main.tscn
└── Game (scripts/game/game.gd)          Ekran: dokunma girdisi, yerleşim, arayüz, efektler
    ├── Board (board.gd)                  Fizik dünyası: duvarlar, binalar, birleşme, tehlike çizgisi
    │   ├── Walls (StaticBody2D)
    │   ├── Buildings/ Building×n (building.gd, RigidBody2D)
    │   ├── Dropper (dropper.gd)          Nişan ve bırakılacak binanın çizimi
    │   └── Effects (effects.gd)          Birleşme halkası, puan yazısı
    ├── Session (game_session.gd)         Oturum kuralları: sıra, hamle, puan, oyun sonu, anlık görüntü
    └── Hud (hud.gd, CanvasLayer)         Puan, sıradaki bina, paneller

scripts/core/   Ekrandan bağımsız, birim testli kurallar
    game_data.gd       JSON verilerini yükler ve doğrular
    merge_resolver.gd  Hangi çiftler birleşir? (tek merkez, deterministik)
    spawn_queue.gd     Tohumlu bina sırası, durum kaydı
    score_keeper.gd    Puan ve zincir bonusu
```

Testler ve simülasyon `GameSession` + `Board` ikilisini arayüz olmadan kullanır;
oyun ekranı da aynı ikiliyi kullanır. Böylece test edilen kural, oynanan kuraldır.

### İstenen bileşenlerle eşleşme

| İstenen | Karşılığı | Durum |
|---|---|---|
| GameManager | `GameSession` (kurallar) + `game.gd` (ekran akışı) | Var |
| MergeManager | `MergeResolver` (karar) + `Board._resolve_merges` (uygulama) | Var |
| Building | `Building` | Var |
| SpawnController | `SpawnQueue` (sıra) + `Dropper` (nişan) | Var |
| ScoreManager | `ScoreKeeper` | Var |
| LevelManager | — | Aşama 3 |
| SaveManager | — (anlık görüntü altyapısı hazır, JSON'a dönüşebilir) | Aşama 4 |
| EconomyManager, BoosterManager | — | Aşama 5 |
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
| `i18n/strings.csv` | Türkçe ve İngilizce metinler |

Veri hatalıysa oyun başlamaz ve hatayı ekranda gösterir. Tüm alanlar
`GameData` içinde doğrulanır.

## Koordinatlar ve yerleşim

`Board` içinde (0,0) arsanın sol üst köşesi, y aşağı doğru artar. Arsa
900×1280. İçerik 1920 yüksekliğe göre dizilir; daha uzun telefonlarda dikey,
tabletlerde yatay ortalanır. Mobilde üst güvenli alan (çentik) payı bırakılır.
