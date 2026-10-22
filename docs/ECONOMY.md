# Ekonomi (başlangıç varsayımları)

> **Tüm değerler varsayımdır.** Gerçek oyuncu verisi olmadan ekonominin
> dengeli olduğu ya da belirli bir gelir üreteceği iddia edilmez.
> Değerler `data/economy.json` ve `data/levels.json` (`rewards`) içindedir;
> kod değiştirmeden ayarlanır.

## Kaynaklar

| Kaynak | Nasıl kazanılır (şu an) | Ne için kullanılacak |
|---|---|---|
| Madeni para | Bölüm tamamlama, yeni yıldız, yıldız kilometre taşları, başlangıç bakiyesi | Güçlendiriciler (Aşama 5), şehir geliştirme (Aşama 8) |
| Elmas | Henüz yok (bakiye 0) | Kozmetik ve isteğe bağlı kolaylıklar (Aşama 5 ve 8) |

Enerji sayacı, bekleme süresi veya üretim zinciri **yoktur**.

## Ödül kuralları

| Olay | Ödül | Not |
|---|---|---|
| İlk açılış | 100 madeni para | `start.coins` |
| Bölümü ilk kez tamamlama | 20–120 (bölüme göre artar) | `rewards.coins_first` |
| Bölümü tekrar tamamlama | 5–10 | `rewards.coins_repeat`; tekrar oynamayı zorunlu kılmayacak kadar küçük |
| Bir bölümde yeni yıldız | yıldız başına 10 | Yalnızca daha önce alınmamış yıldızlar |
| Toplam yıldız eşiği | 10★: 50 · 20★: 100 · 30★: 150 · 45★: 250 · 60★: 400 · 75★: 600 · 90★: 1000 | Her eşik bir kez |
| Kaybetme | 0 | Başarısızlıkta satın alma önerisi yok, ipucu var |

Ödüller tek bir yerden verilir (`PlayerProfile.apply_result`); aynı sonuç için
iki kez ödül verilemez. Testler ilk/tekrar/yeni yıldız/eşik kurallarını ve
eşiklerin bir kez verildiğini doğrular.

## Beklenen birikim (varsayım: oyuncu her bölümü bir kez, ortalama 2 yıldızla geçer)

| Bölge | İlk tamamlama | Yıldız bonusu | Kilometre taşı | Bölge sonu toplam (başlangıç dâhil) |
|---|---|---|---|---|
| Başlangıç Mahallesi (10 bölüm) | 375 | 200 | 150 (10★, 20★) | ~825 |
| Sahil Bölgesi (10 bölüm) | 520 | 200 | 400 (30★, 45★… 40★'a kadar 30★) | ~1.500–1.950 |
| Çarşı Bölgesi (10 bölüm) | 720 | 200 | 400 (60★) | ~3.000–3.300 |

Güçlendirici fiyatları (Aşama 5) bu birikime göre belirlenecek: hedef, ücretsiz
oynayan bir oyuncunun zor bölümlerde ara sıra güçlendirici kullanabilmesi,
ama güçlendiricisiz de ilerleyebilmesi.

## Bölge kilitleri

| Bölge | Koşul |
|---|---|
| Başlangıç Mahallesi | Açık |
| Sahil Bölgesi | 1-10 tamamlandı **ve** toplam 12★ (bölüm başına ortalama 1,2★) |
| Çarşı Bölgesi | 2-10 tamamlandı **ve** toplam 30★ (bölüm başına ortalama 1,5★) |

Yıldız koşulları, her bölümü yalnızca tamamlayan (1★) bir oyuncunun birkaç
bölümde 2★ almasıyla sağlanabilecek düzeydedir; aynı bölümü defalarca
oynamayı zorunlu kılmamalıdır. Gerçek oyuncu verisiyle doğrulanacak.
