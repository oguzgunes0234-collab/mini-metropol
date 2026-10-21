# Testler

## Komutlar (Linux geliştirme ortamı)

```sh
tools/setup_env.sh        # Godot 4.7.2 ve ekran görüntüsü araçlarını kurar (bir kez)
tools/run_tests.sh        # birim + entegrasyon testleri (~7 sn)
tools/run_tests.sh merge  # adında "merge" geçen testler
tools/run_sim.sh 5000     # iki botla 2×5000 bırakmalık stres simülasyonu (~1,5 dk)
tools/lint.sh             # tüm GDScript dosyalarının sözdizimi/tür denetimi
tools/screenshots.sh      # farklı ekran oranlarında ekran görüntüleri (reports/shots/)
```

Çıktılar `reports/` klasörüne yazılır (Git'e girmez). Testler `--fixed-fps 60`
ile çalışır: her kare tam 1/60 sn fizik adımıdır ve gerçek zaman beklenmez.

GDScript çalışma hataları testi durdurmadığı için `run_tests.sh` çıktıda
`SCRIPT ERROR` / `ERROR:` arar ve bulursa testleri başarısız sayar.

## Kapsam

| Dosya | Ne doğrulanıyor |
|---|---|
| `tests/unit/test_game_data.gd` | Varsayılan veri geçerli; hatalı veri (sıra, yarıçap, renk, eksik bölüm, ağırlık, son seviye kuralı, dar alan) yakalanıyor; puan ve yarıçap yalnızca veriden geliyor |
| `tests/unit/test_merge_resolver.gd` | Tek çift; iki yönden gelen aynı çift; 3 bina → tek birleşme; hiçbir bina iki kez kullanılmıyor; sonuç girdi sırasından bağımsız; son seviye Anıt / "none" kuralı |
| `tests/unit/test_spawn_queue.gd` | Aynı tohum → aynı sıra; ağırlıklar (20.000 çekiliş); sıfır ağırlık hiç gelmiyor; durum kaydı (JSON dâhil); önizleme |
| `tests/unit/test_score_keeper.gd` | Puan veriden; zincir bonusu; bırakmada zincir sıfırlanır; bonus üst sınırı; Anıt bonusu; durum kaydı |
| `tests/integration/test_board_physics.gd` | Gerçek fizikle: 2 bina → 1 üst seviye ve tek puan; 3 bina → 1 birleşme + 1 artan; 4 bina → seviye 3'e zincir; zincir bonusu; Anıt; "none" kuralı; duvar dibinde birleşme alanda kalır; bırakma noktası duvarlara sıkışır; aşırı hızla fırlatılan 24 bina kaçmaz; yeniden başlatma sonrası hiçbir gövde ve artık düğüm kalmaz |
| `tests/integration/test_session.gd` | Bırakılan binalar sırayı izler, hamle sayılır; bekleme süresi; aynı tohumla yeniden başlatma; alan taşınca oyun biter (bir kez, tehlike süresi dolmadan değil); oyun bitince bırakma yok; dolu bırakma noktası oyunu bitirir; geçici engel bırakmayı bekletir; yeni bırakılan bina ve kısa taşma oyunu bitirmez; anlık görüntü ve JSON üzerinden geri yükleme tam aynı durumu verir |
| `tests/integration/test_stress_short.gd` | Rastgele ve "akıllı" botla 2×250 bırakma, her karede tutarlılık denetimi |

### Tutarlılık denetimi (`tests/support/invariants.gd`)

Her fizik karesinden sonra:

1. **Değer korunumu:** iki seviye-n bina = bir seviye-(n+1); alandaki toplam
   değer + Anıtlar + kayıplar = bırakılanların değeri. Çift ya da kaybolan
   bina bunu bozar.
2. Hiçbir bina iki kez birleşmeye girmez; kaldırılan bina alanda kalmaz.
3. Puan = olay puanlarının toplamı; her olayın puanı veriden hesaplananla aynı.
4. Hiçbir bina alan dışında değil.
5. Sahnedeki gövde sayısı = Board'un listesi (artık nesne yok).

## Son stres simülasyonu sonuçları

`tools/run_sim.sh 5000` — Godot 4.7.2, bulut sunucusu (4 çekirdek), varsayılan veri.

| | Rastgele bot | "Akıllı" bot |
|---|---|---|
| Bırakma | 5.000 | 5.000 |
| Fizik karesi (her biri denetimli) | 169.630 | 170.849 |
| Biten oyun (her biri temiz yeniden başlatma) | 43 | 36 |
| Birleşme | 3.703 | 4.285 |
| **Tutarlılık ihlali** | **0** | **0** |
| **Yeniden başlatma sonrası kalan nesne** | **0** | **0** |
| Oyun başına bırakma (ortanca / en az / en çok) | 112 / 81 / 178 | 141 / 72 / 201 |
| Ulaşılan en yüksek seviye (oyun sayısı) | 6: 6, 7: 29, 8: 8 | 7: 14, 8: 17, 9: 5 |
| En çok bina | 38 | 27 |
| Kare süresi ort. / %99 / en kötü (ms) | 0,43 / 1,17 / 25,5 | 0,36 / 1,09 / 33,3 |
| Duran binada >%25 gömülme (kare) | 6 | 3 |

Notlar:
- Kare süresi fizik + oyun betikleridir, çizim hariç; **telefonda ölçülmedi**.
  En kötü değerler, iki simülasyon aynı anda ve başka işlerle birlikte
  çalışırken ölçüldü; işletim sistemi kaynaklı olabilir, doğrulanmadı.
- Gömülme: 170.000 karede 3–6 karede, duran bir bina komşusunun/duvarın
  içine yarıçapının %25'inden fazla girdi. Oyunu bozmuyor (ihlal yok) ama
  görsel bir kusur olarak izleniyor. Fizik 120 Hz'de çalıştırılınca 0'a
  iniyor (bkz. DECISIONS.md, karar 3).

## Sınırlar

- Fizik motoru farklı makinelerde birebir aynı sonucu vermez. Simülasyon
  sonuçları kanıt değil, istatistiksel güvencedir.
- Bot oranları gerçek oyuncu davranışını temsil etmez; yalnızca karşılaştırma içindir.
- Gerçek telefon performansı, dokunma hissi ve titreşim **henüz test edilmedi**
  (Android/iOS derlemesi sonraki aşamalarda).
