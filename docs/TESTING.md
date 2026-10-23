# Testler

## Komutlar (Linux geliştirme ortamı)

```sh
tools/setup_env.sh        # Godot 4.7.2 ve ekran görüntüsü araçlarını kurar (bir kez)
tools/run_tests.sh        # 169 birim + entegrasyon testi (~16 sn)
tools/run_tests.sh merge  # adında "merge" geçen testler
tools/run_sim.sh 5000     # iki botla 2×5000 bırakmalık stres simülasyonu (~1,5 dk)
tools/validate_levels.sh  # her bölümü 3 bot türüyle oynar (~10 dk), bkz. LEVELS.md
tools/lint.sh             # tüm GDScript dosyalarının sözdizimi/tür denetimi
tools/screenshots.sh      # farklı ekran oranlarında ekran görüntüleri (reports/shots/)
```

Çıktılar `reports/` klasörüne yazılır (Git'e girmez). Testler `--fixed-fps 120`
ile çalışır: her kare tam bir fizik adımıdır (1/120 sn) ve gerçek zaman beklenmez.
Testlerdeki süreler 60 Hz kare cinsinden yazılır (`physics_frames(60)` = 1 sn).

GDScript çalışma hataları testi durdurmadığı için `run_tests.sh` çıktıda
`SCRIPT ERROR` / `ERROR:` arar ve bulursa testleri başarısız sayar.

## Kapsam

| Dosya | Ne doğrulanıyor |
|---|---|
| `tests/unit/test_game_data.gd` | Varsayılan veri geçerli; hatalı veri (sıra, yarıçap, renk, eksik bölüm, ağırlık, son seviye kuralı, dar alan) yakalanıyor; puan ve yarıçap yalnızca veriden geliyor |
| `tests/unit/test_merge_resolver.gd` | Tek çift; iki yönden gelen aynı çift; 3 bina → tek birleşme; hiçbir bina iki kez kullanılmıyor; sonuç girdi sırasından bağımsız; son seviye Anıt / "none" kuralı |
| `tests/unit/test_spawn_queue.gd` | Aynı tohum → aynı sıra; ağırlıklar (20.000 çekiliş); sıfır ağırlık hiç gelmiyor; durum kaydı (JSON dâhil); önizleme |
| `tests/unit/test_score_keeper.gd` | Puan veriden; zincir bonusu; bırakmada zincir sıfırlanır; bonus üst sınırı; Anıt bonusu; durum kaydı |
| `tests/integration/test_board_physics.gd` | Gerçek fizikle: duvar/zemin çizgisini geçen bina kurtarılır (kaybolmaz); sınırın içi doluysa kurtarılan bina yukarıdaki boş yere konur (döngü yok); sığ gömülme fiziğe bırakılır; oyun bittikten sonra da sınır denetimi; 2 bina → 1 üst seviye ve tek puan; 3 bina → 1 birleşme + 1 artan; 4 bina → seviye 3'e zincir; zincir bonusu; Anıt; "none" kuralı; duvar dibinde birleşme alanda kalır; bırakma noktası duvarlara sıkışır; aşırı hızla fırlatılan 24 bina kaçmaz; yeniden başlatma sonrası hiçbir gövde ve artık düğüm kalmaz |
| `tests/integration/test_session.gd` | Bırakılan binalar sırayı izler, hamle sayılır; bekleme süresi; aynı tohumla yeniden başlatma; alan taşınca oyun biter (bir kez, tehlike süresi dolmadan değil); oyun bitince bırakma yok; dolu bırakma noktası oyunu bitirir; geçici engel bırakmayı bekletir; yeni bırakılan bina ve kısa taşma oyunu bitirmez; anlık görüntü ve JSON üzerinden geri yükleme tam aynı durumu verir |
| `tests/unit/test_level_catalog.gd` | Varsayılan bölümler ve bölgeler geçerli; bölge kilidi hem bölüm hem yıldız ister; "yakında" bölgeleri açılmaz; bilinmeyen bölge/açılma bölümü yakalanır; her ad/ipucu TR ve EN çevrilmiş; bölüm kuralları genel kuralı bozmadan geçersiz kılar; hatalı bölüm verileri (tekrarlı kimlik, bilinmeyen kural, aralık dışı hedef, seviye 1 hedefi, yıldız sırası, hamle sınırını aşan yıldız, geçersiz açılma, alan dışı/değen başlangıç binası, bırakma alanındaki engel, geçersiz sıra) yakalanıyor |
| `tests/unit/test_level_goals.gd` | Üretim hedefi yalnızca tam seviyeyi sayar; puan/zincir en iyi değeri kullanır; tüm hedefler gerekir; ilerleme hedefte sınırlanır; durum kaydı; yıldız hesabı |
| `tests/unit/test_save_store.gd` | Kayıt gidiş-dönüş; dosya yoksa temiz başlangıç; asıl dosya bozuksa yedekten yükleme; sağlaması tutmayan (kurcalanmış) kayıt reddedilir; yarıda kesilmiş dosya; desteklenmeyen sürüm; iki dosya da bozuksa temiz başlangıç; nesne olmayan veri; yarım kalmış .tmp dosyası; tüm dosyaları silme |
| `tests/unit/test_wallet_profile.gd` | Cüzdan: harcama, yetersiz bakiye, geçersiz miktar, bozuk durumun temizlenmesi, işlem kaydı sınırı; ekonomi verisi doğrulaması (güçlendirici kimliği, para birimi, fiyat, sınır, etki aralığı, envanter sınırı); güçlendiricilerin açılma bölümleri var; yeni oyuncu başlangıç parası; ilk tamamlama + yeni yıldız ödülü; tekrar ödülü küçük, yıldız iyileşince bonus; kaybetmede ödül yok; kilometre taşı bir kez; **açılış hediyesi bir kez (kayıttan sonra da)**; eski kayda hediye; geliştirici kilidi hediye vermez; bölüm güçlendirici ödülü yalnızca ilk tamamlamada; eşikte elmas ve güçlendirici bir kez; **satın alma: kilitli/bilinmeyen/yetersiz bakiye/envanter dolu durumlarında hiçbir şey değişmez**; profil JSON gidiş-dönüş; bozuk profil ve envanter verisi güvenli değerlere döner |
| `tests/unit/test_progress.gd` | En iyi sonuç korunur; kilitler tamamlanmayla açılır; başarısızlık sayacı; toplam yıldız; JSON üzerinden durum kaydı |
| `tests/integration/test_levels.gd` | Gerçek fizikle: bölüm kurulumu (dar alan, başlangıç binaları, engeller, hamle); öğretici sabit sıra; engeller binaları tutar; hedefe ulaşınca kazanma ve yıldızlar; son hamlenin birleşmesi sayılır; binalar durunca "hamleler bitti"; bölümde alan taşması; yeniden deneme temiz (engeller tekrar eklenmez); anlık görüntü hedef ilerlemesini içerir; 10 bölümün hepsi hatasız başlar |
| `tests/integration/test_ui_flow.gd` | Harita ve kilitler; yeni oyuncuya başlangıç parası ve kayıt dosyası; **ilerleme ve para uygulama yeniden açılınca korunur**; **bozuk kayıtla açılış çökmez**; giriş paneli bırakmayı engeller; oynayıp kazanma → sonraki bölüm açılır ve oynanır; duraklat/devam/listeye dön; yeniden deneme girişi atlar ve sıfırlar; ipucu yalnızca 2. başarısızlıktan sonra; serbest oyun; güçlendirici çubuğu ilk bölümde ve serbest oyunda yok; yeni güçlendirici bir kez tanıtılır; envanter boşken satın al ve kullan (para düşer, hemen kaydedilir); bakiye yetmezse satın alma düğmesi yok; kullanılamayan güçlendiricide neden yazılır; vinçte binaya dokunarak seçme ve hamlesiz yeniden bırakma |
| `tests/integration/test_stress_short.gd` | Rastgele ve "akıllı" botla 2×250 bırakma, her karede tutarlılık denetimi |
| `tests/integration/test_boosters.gd` | Gerçek fizikle her güçlendirici: geri al son bırakmadan önceki duruma tam döner, tek adımdır, son hamleden sonra oyunu sürdürür; değiştir sırayı değiştirir, aynı seviyede kullanılamaz, geri almayı siler; ek hamle sonuç gelmeden oyunu sürdürür ve geri al ile kaybolmaz; temizle yalnızca küçük binaları kaldırır, puan vermez, değer korunur; vinç binayı alır, yeniden bırakmak hamle harcamaz, seviye sınırı ve "elde bina" kuralı; geri al binayı ele geri verir. Kötüye kullanım: **bölüm bitince hiçbiri kullanılamaz (çift ödül yok)**; etki yoksa harcanmaz; bölüm sınırı yalnızca yeni denemede sıfırlanır; serbest oyunda ve kilitliyken yok; rastgele bot + rastgele güçlendiricilerle her karede tutarlılık ve "harcanan = başarılı kullanım" |

### Tutarlılık denetimi (`tests/support/invariants.gd`)

Her fizik karesinden sonra:

1. **Değer korunumu:** iki seviye-n bina = bir seviye-(n+1); alandaki toplam
   değer + Anıtlar + kayıplar + güçlendiriciyle kaldırılan/alınan binalar =
   bırakılanların değeri. Çift ya da kaybolan bina bunu bozar. Geri al olay
   kaydını kısalttığında denetim kaydı baştan okur.
2. Hiçbir bina iki kez birleşmeye girmez; kaldırılan bina alanda kalmaz.
3. Puan = olay puanlarının toplamı; her olayın puanı veriden hesaplananla aynı.
4. Hiçbir bina alan dışında değil.
5. Sahnedeki gövde sayısı = Board'un listesi (artık nesne yok).

## Son stres simülasyonu sonuçları

`tools/run_sim.sh 5000` — Godot 4.7.2, bulut sunucusu (4 çekirdek), 120 Hz fizik,
32 çözücü yinelemesi, dengeli kütleler, son çare kurtarma açık.

| | Rastgele bot | "Akıllı" bot |
|---|---|---|
| Bırakma | 5.000 | 5.000 |
| Fizik adımı (her biri denetimli) | 329.563 | 331.970 |
| Biten oyun (her biri temiz yeniden başlatma) | 44 | 35 |
| **Tutarlılık ihlali** | **0** | **0** |
| **Yeniden başlatma sonrası kalan nesne** | **0** | **0** |
| **Son çare kurtarma** | **0** | **0** |
| Duran binada >%25 gömülme (adım) | 0 | 0 |
| Oyun başına bırakma (ortanca / en az / en çok) | 113 / 77 / 166 | 136 / 69 / 209 |
| Ulaşılan en yüksek seviye (oyun sayısı) | 6: 8, 7: 22, 8: 14 | 6: 1, 7: 7, 8: 22, 9: 5 |
| Adım süresi ort. / %99 / en kötü (ms) | 0,32 / 1,27 / 9,4 | 0,27 / 1,14 / 11,6 |

Notlar:
- Adım süresi fizik + oyun betikleridir, çizim hariç; **telefonda ölçülmedi**.
  120 Hz'de saniyede 120 adım çalışır. Ölçüm 5 süreç aynı anda çalışırken
  yapıldı; en kötü değerlerin nedeni doğrulanmadı.
- 30 bölümün doğrulaması (her biri 66 deneme): 0 ihlal, 0 kurtarma. Bkz.
  [LEVELS.md](LEVELS.md).

## Sınırlar

- Fizik motoru farklı makinelerde birebir aynı sonucu vermez. Simülasyon
  sonuçları kanıt değil, istatistiksel güvencedir.
- Bot oranları gerçek oyuncu davranışını temsil etmez; yalnızca karşılaştırma içindir.
- Gerçek telefon performansı, dokunma hissi ve titreşim **henüz test edilmedi**
  (Android/iOS derlemesi sonraki aşamalarda).
