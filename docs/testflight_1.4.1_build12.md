# FreshTrack 1.4.1 (12) TestFlight Notes

## TR - Kisa Surum Notu

Bu surumde barkod tarama ozelligi ozellikle Turk urunleri icin guclendirildi.

- Turk urunleri icin daha genis yerel barkod kapsami
- Bulunan urunlerde icindekiler ve alerjen bilgilerinin daha iyi gelmesi
- Yerel eslesme sonrasi arka planda ek urun detayi getirme
- Bilinmeyen barkodlar manuel eklendiginde sonraki taramalarda hatirlama
- Icindekiler ve alerjen uyarisinda dil destegi
- Build ve acilis kararliligi iyilestirmeleri

## TR - What to Test

- Barkod tarayarak Turk urunlerini bulun. Ozellikle sut urunleri, atistirmaliklar, icecekler ve soslarda eslesme kalitesini kontrol edin.
- Barkoddan sonra gelen urun adi, marka ve kategori bilgilerinin dogru olup olmadigini kontrol edin.
- Uygun urunlerde icindekiler ve alerjen uyarisinin gorunup gorunmedigini kontrol edin.
- Bir barkod ilk taramada bulunmazsa urunu manuel ekleyin, sonra ayni barkodu tekrar tarayip uygulamanin urunu hatirlayip hatirlamadigini kontrol edin.
- Cihazin dilini degistirerek icindekiler, alerjen uyarisı ve barkod bilgi mesajlarinin cevirilerini kontrol edin.
- Genel akista urun ekleme, duzenleme ve silme islemlerinde sorun olup olmadigini kontrol edin.

## EN - Release Notes

This build improves barcode scanning, especially for Turkish products.

- Expanded local Turkish barcode coverage
- Better ingredient and allergen details for recognized products
- Background product-detail enrichment after local barcode matches
- Learned barcode memory for manually added products
- Localization support for ingredients and allergen warnings
- Stability and build fixes

## EN - What to Test

- Scan Turkish product barcodes and check match quality, especially for dairy, snacks, beverages, and condiments.
- Verify that product name, brand, and category are filled correctly after scanning.
- Check whether ingredients and allergen warnings appear for supported products.
- If a barcode is not found on first scan, add the product manually and scan the same barcode again to confirm the app remembers it.
- Change the device language and verify the ingredients, allergen warning, and barcode status messages are localized.
- Run a quick smoke test for add, edit, and delete product flows.

