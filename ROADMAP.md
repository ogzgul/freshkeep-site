# FreshTrack — Buzdolabı & Son Kullanma Takipçisi
### iOS App Store Yol Haritası

---

## Neden Bu Uygulama?

| Kriter | Durum |
|--------|-------|
| Rakip sayısı | Yok (en iyi rakip 2019'da güncellenmiş) |
| App Store arama hacmi | "food expiry tracker", "fridge tracker" — yüksek, ama sonuç yok |
| Ortalama rakip puanı | 2.8 – 3.2 yıldız |
| Hedef kullanıcı | Tüm yaş grupları, herkesin buzdolabı var |
| Ölçülebilir fayda | Hane başına yılda $1,500 israf önlenir |
| Teknik zorluk | Düşük (solo geliştirici, 4–6 hafta) |
| Monetizasyon | $1.99 tek seferlik satın alma |
| Potansiyel yıllık gelir | $100,000 – $300,000 |

---

## Uygulama Konsepti

**Tek cümle:** Barkod veya elle gir, son kullanma tarihini kaydet, uygulama süresi dolmadan önce bildir.

**Temel acı noktası:** Buzdolabında ne olduğunu bilmiyoruz, ne zaman bozulacağını bilmiyoruz, açtığımızda çöp olmuş buluyoruz.

**Benzersiz değer önerisi:**
- Rakiplerden farklı olarak **sadece bunu yapar** — meal planner değil, tarif önerisi yok
- Sade, temiz, hızlı — tek ürün eklemek 5 saniyeden az sürer
- "Bu ay $47 israf önledin" — duygusal bağ yaratan istatistik

---

## Temel Özellikler (MVP — V1)

### Zorunlu
- [ ] Barkod tarama (AVFoundation — iOS native, ücretsiz)
- [ ] Manuel ürün ekleme (isim + kategori + son kullanma tarihi)
- [ ] Ürün listesi (tarihe göre sıralanmış — en yakın üstte)
- [ ] Push bildirim: "X ürününün son kullanma tarihi 2 gün sonra"
- [ ] Kategoriler: Süt Ürünleri, Et, Sebze/Meyve, İçecek, Diğer
- [ ] Renk kodlama: Yeşil (>7 gün) / Sarı (2–7 gün) / Kırmızı (<2 gün)

### V1.5 (İlk güncellemede)
- [ ] Aylık tasarruf istatistiği ("Bu ay X ürünü zamanında kullandın = $Y tasarruf")
- [ ] Widget desteği (iOS home screen)
- [ ] Fotoğraf ekleme (ürün fotoğrafı)
- [ ] iCloud sync (aynı hanede paylaşım)

### V2 (Premium özellikleri)
- [ ] Alışveriş listesi entegrasyonu (biten ürünler otomatik listeye)
- [ ] Ortak kullanım (aile üyeleri aynı buzdolabını takip eder)
- [ ] Türk & dünya markası barkod veritabanı genişletme

---

## Teknik Stack (iOS Native)

```
Dil:          Swift 5.9+
UI Framework: SwiftUI
Veritabanı:   Core Data (yerel) + CloudKit (iCloud sync — V1.5)
Bildirimler:  UserNotifications framework
Barkod:       AVFoundation (iOS native — ücretsiz, hızlı)
Ürün veritabanı: Open Food Facts API (ücretsiz, 3M+ ürün, Türkiye dahil)
Grafik:       Swift Charts (iOS 16+ native)
Backend:      YOK — tamamen offline çalışır (V1)
```

**Neden backend yok?**
- Maliyet sıfır
- Privacy açısından güçlü bir satış noktası ("Verileriniz sadece cihazınızda")
- App Store onayı daha hızlı
- V1 için yeterli

---

## Monetizasyon Stratejisi

### Model: $1.99 Tek Seferlik Satın Alma

| Seçenek | Neden |
|---------|-------|
| Subscription YOK | 2025-2026 trendine göre kullanıcılar subscription'dan kaçıyor (+6% one-time purchase artışı) |
| $1.99 fiyat noktası | Impuls satın alma eşiği altında, "bunu denemeyeyim mi?" dedirten fiyat |
| Freemium değil | 3 ürün limiti gibi kısıtlamalar yorucu; ya tam ücretsiz ya $1.99 — net |

### Gelir Projeksiyonu (Gerçekçi)

```
Ay 1–3   (launch + ASO):   50 satış/gün × $1.40 (Apple %30 sonrası) × 90 gün = $6,300
Ay 4–6   (organik büyüme): 120 satış/gün × $1.40 × 90 gün = $15,120
Ay 7–12  (olgunluk):       200 satış/gün × $1.40 × 180 gün = $50,400
─────────────────────────────────────────────────────────────
İlk yıl toplam:            ~$71,820
```

> Not: AutoSleep ($4.99, benzer utility) yıllarca Top 10 Paid Health app oldu.
> Bizim hedefimiz Top 20 Food & Drink veya Utilities.

---

## App Store Optimizasyonu (ASO)

### Uygulama Adı
`FreshTrack — Fridge Expiry Tracker`

### Anahtar Kelimeler (105 karakter limiti)
```
food expiry,fridge tracker,best before,expiration,pantry,grocery,waste,
food waste,kitchen,barcode
```

### Açıklama Hook'u (ilk 2 satır — en önemli)
```
Stop throwing away money. FreshTrack tells you exactly what's expiring
in your fridge — before it's too late.
```

### Kategori
- **Primer:** Food & Drink
- **Sekonder:** Utilities

### Hedef Rating: 4.5+
**Nasıl?**
1. İlk hafta: 5-star review isteği — sadece ürün kaydedildikten sonra sor
2. Kullanıcı "tasarruf anı"nda (bildirim gelip zamanında kullandığında) sor
3. Hiçbir zaman ana ekranda sormak = kötü deneyim

---

## Geliştirme Takvimi

### Hafta 1–2: Temel Yapı
- [ ] Xcode proje kurulumu
- [ ] Core Data modeli (Product entity: name, category, expiryDate, addedDate, photo?)
- [ ] Ana liste ekranı (SwiftUI List, renk kodlamalı)
- [ ] Ürün ekleme ekranı

### Hafta 3: Barkod & Bildirimler
- [ ] AVFoundation barkod tarayıcı
- [ ] Open Food Facts API entegrasyonu (ürün adı otomatik doldur)
- [ ] UserNotifications kurulumu
- [ ] Bildirim zamanlama logic'i (expiry - 2 gün ve - 1 gün)

### Hafta 4: UI Polish & Test
- [ ] Renk sistemi ve tipografi
- [ ] Dark mode desteği
- [ ] Onboarding ekranı (3 slide max)
- [ ] App icon tasarımı (SwiftUI Canvas veya Figma)
- [ ] TestFlight beta

### Hafta 5: App Store Hazırlığı
- [ ] Screenshots (6.7" iPhone için en az 5 adet)
- [ ] App Store açıklaması (EN + TR)
- [ ] Privacy Policy sayfası (gerekli — ücretsiz: privacypolicygenerator.info)
- [ ] Review isteme logic'i
- [ ] App Store Connect kaydı

### Hafta 6: Launch & ASO
- [ ] App Store submission
- [ ] ASO keyword araştırması finalize
- [ ] Launch post: Reddit r/foodwaste, r/zerowaste, r/mealprep
- [ ] ProductHunt launch
- [ ] Twitter/X & Instagram: "Ben bu uygulamayı yazdım" indie dev story

---

## Pazarlama (Ücretsiz Kanallar)

| Kanal | İçerik | Potansiyel |
|-------|--------|------------|
| Reddit r/zerowaste (1.2M üye) | "Yemek israfını azaltmak için uygulama yaptım" | Yüksek viral |
| Reddit r/mealprep (4.3M üye) | Fridge organization post | Orta |
| TikTok "buzdolabı organize" | Ürün kullanım videosu | Yüksek |
| Instagram Reels | Before/after buzdolabı | Orta |
| ProductHunt | Launch günü | App Store trafik spike |
| Indie Hacker story | Geliştirme süreci | Geliştirici topluluğu |

---

## Riskler & Çözümler

| Risk | Olasılık | Çözüm |
|------|----------|-------|
| Barkod veritabanı Türkiye'de eksik | Orta | Open Food Facts + manuel giriş fallback |
| Kullanıcı alışkanlık oluşturamaması | Orta | Onboarding'de "ilk 5 ürünü ekle" zorla yürüyüş |
| App Store reddi | Düşük | Privacy policy ekle, veri toplamıyorsun zaten |
| Rakip kopyalaması | Düşük | Hız + review birikimi = savunma kalesi |

---

## Alternatif Uygulama Fikirleri (Araştırmadan Gelen Diğer Seçenekler)

Eğer bu fikir beğenilmezse, aynı pazar araştırması şu alternatifleri de gösterdi:

1. **Parking Timer** — En düşük teknik zorluk (2-3 hafta), evrensel ihtiyaç, mevcut uygulamalar 3 yıldız. $1.99 one-time.
2. **Relationship Reminder** — "47 gündür arkadaşınla konuşmadın" bildirimi. Duygusal değer yüksek, Reddit'te sürekli isteniyor. $2.99 one-time.
3. **ADHD Görsel Planlayıcı** — En yüksek gelir potansiyeli ($500K+/yıl), subscription model, ama 6-8 hafta geliştirme.
4. **Garanti & Fiş Takipçisi** — Barkod + OCR ile fiş tarama, garanti bildirimleri. $2.99 one-time.

---

## Hızlı Başlangıç Kontrol Listesi

- [ ] Apple Developer hesabı aç ($99/yıl)
- [ ] Xcode indir (Mac zorunlu)
- [ ] App icon için Figma veya Canva
- [ ] Open Food Facts API dökümantasyonunu oku (ücretsiz, kayıt gerektirmez)
- [ ] privacypolicygenerator.info adresinde privacy policy hazırla
- [ ] TestFlight için 5-10 beta test kullanıcısı bul

---

*Araştırma tarihi: Mart 2026*
*Kaynak: RevenueCat State of Subscription Apps 2025, Adapty Benchmark Report, App Store analytics, Reddit r/AppIdeas*
