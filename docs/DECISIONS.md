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

## 3. Fizik 60 Hz
Daire modunda 60 Hz yeterli (yukarıdaki tablo). 120 Hz gömülmeyi sıfırlıyor
ama işlemci yükünü iki katına çıkarıyor. Telefonda ölçüm yapılınca yeniden
değerlendirilecek (`project.godot` → `physics/common/physics_ticks_per_second`).

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
