# Ekonomi ve güçlendiriciler (başlangıç varsayımları)

> **Tüm değerler varsayımdır.** Gerçek oyuncu verisi olmadan ekonominin
> dengeli olduğu ya da belirli bir gelir üreteceği iddia edilmez.
> Değerler `data/economy.json` ve `data/levels.json` (`rewards`) içindedir;
> kod değiştirmeden ayarlanır. Dosya her açılışta doğrulanır, hatalıysa oyun
> başlamaz ve hatayı gösterir.

## Kaynaklar

| Kaynak | Nasıl kazanılır | Ne için kullanılır |
|---|---|---|
| Madeni para | Başlangıç bakiyesi, bölüm tamamlama, yeni yıldız, yıldız eşikleri | Güçlendirici satın alma; ileride şehir geliştirme (Aşama 8) |
| Elmas | Yalnızca bazı yıldız eşikleri (30★: 5, 60★: 10, 90★: 20) | **Henüz harcanmıyor.** Haritada bakiye görünür; dokununca "yakında şehrini geliştirmek için" yazar. Kullanım alanı bir karar konusu (aşağıda) |
| Güçlendirici | Açılış hediyesi, bazı bölümlerin ilk tamamlanması, bazı yıldız eşikleri, madeni parayla satın alma | Bölüm içinde zorluğu azaltmak |

Enerji, can, bekleme süresi veya üretim zinciri **yoktur**. Gerçek parayla
satın alma, reklam veya mağaza bu aşamada **yoktur** (Aşama 9).

## Ödül kuralları

| Olay | Ödül | Not |
|---|---|---|
| İlk açılış | 100 madeni para | `start.coins` |
| Bölümü ilk kez tamamlama | 20–120 madeni para (bölüme göre artar) | `rewards.coins_first` |
| Bazı bölümleri ilk kez tamamlama | Güçlendirici (aşağıdaki tablo) | `rewards.boosters`; tekrar oynamada verilmez |
| Bölümü tekrar tamamlama | 5–10 madeni para | `rewards.coins_repeat`; tekrar oynamayı zorunlu kılmayacak kadar küçük |
| Bir bölümde yeni yıldız | yıldız başına 10 | Yalnızca daha önce alınmamış yıldızlar |
| Toplam yıldız eşiği | aşağıdaki tablo | Her eşik bir kez |
| Güçlendirici açılması | Hediye adet (aşağıdaki tablo) | Bir kez; eski kayıtlarda da açılışta verilir |
| Kaybetme | 0 | Başarısızlıkta satın alma önerisi yok, ipucu var |

Yıldız eşikleri:

| Eşik | Madeni para | Ek |
|---|---|---|
| 10★ | 50 | — |
| 20★ | 100 | Ek Hamle ×1 |
| 30★ | 150 | 5 elmas |
| 45★ | 250 | Vinç ×1, Temizle ×1 |
| 60★ | 400 | 10 elmas |
| 75★ | 600 | Ek Hamle ×2 |
| 90★ | 1000 | 20 elmas |

Bölüm güçlendirici ödülleri (yalnızca ilk tamamlamada): 1-10: Geri Al ×2 +
Ek Hamle ×1 · 2-05: Vinç ×1 · 2-10: Temizle ×1 + Geri Al ×2 · 3-05:
Değiştir ×2 + Vinç ×1 · 3-10: Ek Hamle ×2.

Ödüller tek bir yerden verilir (`PlayerProfile.apply_result`); aynı sonuç için
iki kez ödül verilemez. Testler ilk/tekrar/yeni yıldız/eşik/hediye kurallarını
ve her birinin bir kez verildiğini doğrular.

## Güçlendiriciler

| Güçlendirici | Etki | Fiyat | Bölümde en fazla | Açılır | Hediye |
|---|---|---|---|---|---|
| Geri Al | Son bırakmayı ve sonrasını geri alır, hamle iade edilir | 50 | 3 | 1-02 sonrası | 3 |
| Değiştir | Şimdiki ve sıradaki binanın yerini değiştirir | 30 | 3 | 1-03 sonrası | 2 |
| Ek Hamle | +5 hamle; son hamleden sonra da kullanılabilir | 120 | 2 | 1-05 sonrası | 2 |
| Vinç | Bir binayı (en fazla seviye 6) alıp yeniden bırakma; yeniden bırakmak hamle harcamaz | 80 | 2 | 1-07 sonrası | 2 |
| Temizle | Seviye 1–2 binaların hepsini kaldırır, puan vermez | 100 | 1 | 1-09 sonrası | 1 |

Envanter sınırı: her güçlendiriciden en fazla 99 adet.

**Kurallar**
- Yalnızca bölüm kipinde ve bölüm sürerken kullanılır; serbest oyunda yoktur
  (en iyi puan karşılaştırması adil kalsın diye).
- Bölüm bittikten sonra hiçbiri kullanılamaz: geri al ile ödül iki kez alınamaz.
- Bir güçlendirici yalnızca etkisi gerçekten uygulandıysa envanterden düşer
  (örnek: geri alınacak bırakma yoksa harcanmaz, neden ekranda yazılır).
- Bölüm başı sınır yeniden denemede sıfırlanır; geri al bu sayacı geri getirmez.
- Yıldız ölçütü "en fazla N hamle", kullanılan hamleyi sayar; ek hamle bu
  yıldızı kolaylaştırmaz.

**Satın alma akışı (adil para kuralları)**
- Satın alma paneli yalnızca oyuncu, envanterinde kalmamış bir güçlendiriciye
  dokunduğunda açılır; kendiliğinden açılan teklif yoktur.
- Panel fiyatı, bakiyeyi ve bölüm sınırını açıkça yazar; "Satın al ve kullan"
  ve "Vazgeç" düğmeleri vardır. Oyun panel açıkken durur.
- Bakiye yetmiyorsa yalnızca bilgi ("bölümleri tamamlayarak kazanabilirsin")
  ve "Tamam" düğmesi vardır; başka bir satın alma yolu önerilmez.
- Tek adet satın alınır. İndirim, geri sayım, "son fırsat", paket baskısı yoktur.
- Satın alma hemen kaydedilir.
- Kaybetme ekranında güçlendirici veya ek hamle teklifi yoktur (karar 15).

## Beklenen birikim (varsayım: oyuncu her bölümü bir kez, ortalama 2 yıldızla geçer, hiç harcamaz)

| Bölge sonu | İlk tamamlama | Yıldız bonusu | Eşikler | Toplam madeni para (başlangıç dâhil) | Ücretsiz güçlendirici (toplam) | Elmas |
|---|---|---|---|---|---|---|
| Başlangıç Mahallesi (20★) | 375 | 200 | 150 | ~825 | 14 | 0 |
| Sahil Bölgesi (40★) | 520 | 200 | 150 | ~1.695 | 18 | 5 |
| Çarşı Bölgesi (60★) | 720 | 200 | 650 | ~3.265 | 25 | 15 |

Ölçek fikri: bir bölümün ilk tamamlanması (~40–60 madeni para) kabaca bir
Değiştir ya da bir Geri Al eder; Ek Hamle (120) iki-üç bölümlük kazanca denk.
Tekrar oynama ödülü (5–10) ile Ek Hamle almak için 12–24 tekrar gerekir; yani
"para kasmak" mümkün ama gerekli ya da cazip değildir. Hedef: ücretsiz oynayan
oyuncu zor bölümlerde ara sıra güçlendirici kullanabilsin, ama güçlendiricisiz
de ilerleyebilsin (bölümler güçlendiricisiz botlarla ayarlandı, bkz.
[LEVELS.md](LEVELS.md)).

Madeni paranın şimdilik tek harcama yeri güçlendiricilerdir; uzun vadede
birikir. Şehir geliştirme (Aşama 8) ikinci harcama yeri olacak. Bu değerler
gerçek oyuncu verisiyle (kaç güçlendirici alındı, nerede takılındı) yeniden
ayarlanmalıdır.

## Güçlendiricilerin zorluğa etkisi (bot ölçümü)

Bkz. [LEVELS.md](LEVELS.md), "Güçlendiricilerle". Botlar yalnızca Ek Hamle'yi
(hamleler bitince) ve Temizle'yi (tehlike çizgisi dolmaya başlayınca) kullandı.
Özet (30 bölüm, her bot 900 deneme): rastgele bot %51 → %83, akıllı bot
%76 → %94; deneme başına ortalama 1,13 / 0,66 güçlendirici. Kısa bölümlerde
Ek Hamle çok güçlü; oyuncu testinden sonra yeniden ayarlanmalı.

## Bölge kilitleri

| Bölge | Koşul |
|---|---|
| Başlangıç Mahallesi | Açık |
| Sahil Bölgesi | 1-10 tamamlandı **ve** toplam 12★ (bölüm başına ortalama 1,2★) |
| Çarşı Bölgesi | 2-10 tamamlandı **ve** toplam 30★ (bölüm başına ortalama 1,5★) |

Yıldız koşulları, her bölümü yalnızca tamamlayan (1★) bir oyuncunun birkaç
bölümde 2★ almasıyla sağlanabilecek düzeydedir; aynı bölümü defalarca
oynamayı zorunlu kılmamalıdır. Gerçek oyuncu verisiyle doğrulanacak.

## Açık karar: elmas ne için kullanılacak?

Öneri: elmas, şehir geliştirmede (Aşama 8) kozmetik/süs öğeleri için
kullanılsın; ileride gerçek parayla satılırsa (Aşama 9) yalnızca kolaylık ve
süs alınabilsin, bölüm zorluğunu doğrudan aşmanın tek yolu olmasın.
Güçlendiriciler madeni parayla kalsın. Bu, sahibinin onayını bekleyen bir
karardır.
