# Kararlar

Her karar: ne, neden, nasıl geri alınır.

## 1. Godot 4.7.2 + GDScript, "Compatibility" çizim modu
2D için en geniş cihaz desteği ve en küçük paket. Sürüm sabit: Mac'teki
editör ve dışa aktarma şablonları **aynı 4.7.x sürümü** olmalı. Reklam/satın
alma eklentilerinin bu sürümü desteklediği Aşama 9'dan önce doğrulanacak.

## 2. Bina şekli: daire varsayılan, yuvarlatılmış kare deneysel
`rules.physics.shape_mode`. Oyunda geliştirici tuşu **B** ile değiştirilebilir.
1.500 bırakmalık ölçüm (60 Hz, duran binada >%25 gömülen kare sayısı):

| Şekil | Rastgele bot | Akıllı bot |
|---|---|---|
| Daire | 3 | 0 |
| Yuvarlatılmış kare | 2.907 | 128 |
| Yuvarlatılmış kare, 120 Hz | 156 | 37 |

Kare daha "şehir bloğu" görünüyor ama kalabalık yığında köşeler komşulara ve
duvarlara gömülüyor. Seçilirse ek fizik çalışması gerekir.
**Karar senin:** oynayıp karşılaştırdıktan sonra.

## 3. Fizik 120 Hz (Aşama 3'te 60 Hz'den yükseltildi)
Aşama 2'de 60 Hz yeterli görünüyordu. Aşama 3'teki dar/alçak arsalarda ağır
yığınlar küçük binaları duvara ve zemine ezdi (karar 16). En kötü durumu
üreten ölçümde (akıllı bot, 3000 bırakma):

| Seçenek | İhlal | Kurtarma | Duran binada >%25 gömülme |
|---|---|---|---|
| 60 Hz | 18 | 71 | 50 kare |
| 60 Hz, dengeli kütleler | 0 | 24 | 8 kare |
| **120 Hz** | **0** | **2** | **0 kare** |

Ancak 120 Hz de tek başına yetmedi: 1-07'de (alçak arsa + kayalar) sağ alt
köşede ezilen kulübe hâlâ zemine gömülüyordu. Aynı bölümde 40 denemelik ölçüm:

| Kütleler | Kurtarma | İhlal |
|---|---|---|
| İlk değerler (1 → 10,5) | açık | 26 (kurtarma döngüsü) |
| İlk değerler | kapalı | 2 (bir bina kayboldu) |
| **Dengeli (1 → 5)** | **açık** | **0** |
| Dengeli | kapalı | 0 |

Son karar: **120 Hz + dengeli kütleler + kurtarma (yedek)**. Kazanma
oranları değişmedi. Bedeli: işlemci yükü ~2,5 kat (sunucuda saniyede ~30 ms).
**Telefonda ölçülmedi.** Düşük güçlü cihazlarda sorun çıkarsa 60 Hz + dengeli
kütleler denenecek (60 Hz'de 3000 bırakmada 0 ihlal, 24 kurtarma).
Ayarlar: `project.godot` → `physics/common/physics_ticks_per_second`,
`data/buildings.json` → `mass`.

## 4. Bina boyutları %25 büyütüldü
Simülasyonla 5 varyant karşılaştırıldı (oyun başına ortanca bırakma):

| Varyant | Rastgele bot | Akıllı bot |
|---|---|---|
| İlk değerler | 237 | 269 |
| Binalar %15 büyük | 150 | 187 |
| **Binalar %25 büyük (seçilen)** | **113** | **143** |
| %20 büyük + 5 tür bırakılır | 74 | 100 |

İlk değerlerde rastgele oynayan bot bile kaybetmiyordu. Seçilen ayarda alan
Suika benzeri oyunlara yakın yoğunlukta, strateji fark yaratıyor ve binalar
telefonda daha okunaklı. Bölümler (Aşama 3) kendi kısıtlarıyla zorluğu
ayrıca belirleyecek. **Bunlar varsayımdır; gerçek oyuncu verisi yoktur.**

## 5. Bırakma noktası dolu kuralı
Yığın bırakma noktasına kadar yükselince yeni bina başka binanın içinde
doğuyor ve fizik motoru onu duvara gömüyordu (simülasyonda bulundu). Artık:
yerleşmiş binalar bırakma noktasını dolduruyorsa oyun "arsa doldu" ile biter;
yalnızca düşmekte olan bina varsa bırakma bekletilir.

## 6. Hız sınırları ve güvenlik tavanı
Aşırı hızla fırlatılan bina üstü açık alandan kaçabiliyordu (testte bulundu).
Yukarı doğru ayrı hız sınırı ve bırakma noktasının çok üstünde görünmez bir
tavan eklendi.

## 7. Dairesel binaların çizimi hep dik
Fizikte yuvarlanma korunuyor (doğal yerleşme), ama bina çizimi döndürülmüyor.

## 8. Son seviye: Anıt
İki İkonik Kule birleşince ikisi de kaldırılır ve bonus verilir. Oyun
kilitlenmez, ustalık ödüllendirilir. Alternatif ("none") veride hazır.

## 9. Kendi küçük test altyapımız
GUT gibi eklentiler GitHub'dan indirilemiyor (bu ortamda kapalı) ve dış
bağımlılık eklememek tercih edildi. ~100 satırlık çalıştırıcı yeterli.

## 10. Git'e eklenen üretilmiş dosyalar
Godot 4.4+ `.uid` dosyaları ve çeviri `.translation` dosyaları Git'te tutuluyor:
proje ilk açılışta uyarısız çalışsın diye. `.godot/` önbelleği Git'e girmez.

## 11. Dal düzeni
`main` yalnızca onaylanmış aşamaları içerir. Her aşama ayrı dalda geliştirilir
(şu an: `asama-1-2-cekirdek`); onayınla `main`'e birleştirilir.

## 12. Bölüm zorluğu: hamle verimliliği + alan baskısı
Botlarla ölçüldü (bkz. LEVELS.md). Hamle sınırı olmadan, "bir apartman üret"
gibi küçük hedeflerde rastgele oynayan bot neredeyse akıllı bot kadar hızlıydı:
kısa vadede birleşmeler fizik sayesinde kendiliğinden oluyor. Beceri farkı
asıl olarak **hamle verimliliğinde** ve **dar/alçak arsada büyük hedeflerde**
çıkıyor. Bu yüzden:
- Hamle sınırı, akıllı botun hedefe ulaştığı hamle dağılımına göre seçilir.
- Orta ve ileri bölümler dar/alçak arsa, engel ve büyük hedef kullanır.
- Zorluk rastgeleliği artırarak değil, alanı ve hamleyi kısıtlayarak artar.
  Her bölümün bina sırası sabittir: tekrar denemede aynı sıra gelir, oyuncu
  öğrenebilir.

## 13. Kazanma anında bitiş, son hamlede bekleme
Hedefler tamamlandığı anda bölüm kazanılır. Son hamleden sonra binalar
durana kadar beklenir; bu sırada oluşan birleşmeler de sayılır (oyuncunun
son hamlesi "boşa" gitmez).

## 14. İlerleme şimdilik bellekte
Bölüm kilitleri ve yıldızlar oturum boyunca tutulur, uygulama kapanınca
sıfırlanır. Kalıcı kayıt (bozuk dosyaya dayanıklı) Aşama 4'te eklenecek;
durum yapısı (`Progress.get_state/set_state`) buna hazır ve JSON testi var.

## 15. Başarısızlık sonrası yalnızca ipucu
Art arda 2. başarısızlıktan itibaren sonuç ekranında strateji ipucu çıkar.
Satın alma, reklam veya "ek hamle al" önerisi gösterilmez.

## 16. Ezilen binayı kurtarma, sınır denetimi hep açık
Bölüm doğrulamasında (1-07, alçak arsa + kayalar) ağır yığının altındaki bir
kulübe zemine itilip alanın dışına çıktı ve güvenlik ağı onu kaldırdı:
oyuncunun binası kayboldu. İki değişiklik:
- Duvara/zemine yarıçapının %30'undan fazla gömülen bina her fizik adımında
  alana geri itilir, duvara doğru hızı sıfırlanır (`Board._rescue_deep_penetrations`,
  `stats.rescues` ile sayılır). Bina kaybolmaz; nadiren küçük bir sıçrama görülebilir.
- Sınır denetimi oyun bittikten sonra da çalışır (önceden duruyordu; sonuç
  ekranının arkasında binalar alandan düşebiliyordu).
Kalıcı çözüm adayı: Rapier 2D fizik eklentisi (yığınlarda daha kararlı).
Ancak mobil derleme karmaşıklığı nedeniyle ancak gerçek cihaz testinde sorun
görülürse değerlendirilecek.
