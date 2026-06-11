# MarangozAI — Kullanılabilirlik Raporu

## 1. Hedef Kullanıcı Profili

- Yaş ağırlığı 35-60; bilgisayar okuryazarlığı düşük-orta. WhatsApp'ı iyi, masaüstü yazılımı az kullanır.
- Atölye ortamı: tozlu eller, parlak/loş ışık, gürültü (sesli komut için gürültü filtresi önemli).
- Okuma alışkanlığı düşük → metin değil **görsel + büyük buton + ses** ile iletişim.
- Mevcut alternatifi: kareli deftere kroki, hesap makinesi, kesimciye telefonla liste okuma. Uygulama bu üçünü değiştirmeli, daha karmaşık olmamalı.

## 2. Tasarım İlkeleri

1. **Tek ekran = tek soru.** Sihirbaz akışı; asla çok sekmeli CAD arayüzü değil.
2. **Görsel seçim.** "Membran mı High Gloss mu?" sorusu metinle değil, dokunulabilir büyük görsel kartlarla sorulur. Renkler gerçek plaka kartelası görselleriyle (Kastamonu, Yıldız, Çamsan, AGT desen kodlarıyla) gösterilir.
3. **Büyük hedefler.** Min. buton 56×56 px, yazı min. 18 pt, yüksek kontrast. (Atölyede uzaktan bakılır.)
4. **Geri alınabilirlik.** Her adımda büyük "← Geri" ; hiçbir işlem geri dönüşsüz değil. Otomatik kayıt — "kaydet" butonu yok, kaybolma korkusu yok.
5. **Türkçe usta dili.** "Panel optimizasyonu" değil **"Kesim Planı"**; "edge banding" değil **"Bantlama"**; "render" değil **"Tasarım Görseli"**; "konfigürasyon" değil **"Ayarlar"**.
6. **Ses her yerde.** Mikrofon butonu kalıcı; revizyonda birincil yöntem. Yazı yazmak hep ikincil seçenek.
7. **Hata = yol gösterme.** "Geçersiz değer" yerine: "Bu ölçü 30 cm'den küçük görünüyor, kontrol eder misin?"
8. **Çevrimdışı sürer.** İnternet yokken kesim listesi ve maliyet (son fiyatlarla) çalışır; yalnız AI tasarım "internet gerekli" der.

## 3. Ana Ekran Akışı

```
ANA EKRAN
  [ + YENİ PROJE ]   (ekranın yarısı kadar büyük buton)
  Devam eden projeler (foto kartları, müşteri adı, durum rozeti:
  "Tasarım bekliyor" / "Müşteri onayında" / "Kesime hazır")

YENİ PROJE → 6 adımlı sihirbaz (üstte ilerleme noktaları):
  1) Müşteri adı + telefon (rehberden seç)
  2) FOTOĞRAF ÇEK/YÜKLE — telefondan QR ile gönderme köprüsü*
  3) KROKİ YÜKLE → AI ölçüleri okur → "Ölçüler doğru mu?" onay ekranı
     (her ölçü büyük kutuda, dokunup düzeltilebilir)
  4) MALZEME & RENK (görsel kartlar)
  5) DETAYLAR (çekmece, cam, kulp — görsel)
  6) [ TASARIMI OLUŞTUR ] → bekleme animasyonu (~30-60 sn) → RENDER

RENDER EKRANI
  Büyük görsel + 4 büyük buton:
  [ 🎤 DEĞİŞİKLİK SÖYLE ]  [ 📤 MÜŞTERİYE GÖNDER (WhatsApp) ]
  [ ✅ ONAYLANDI → KESİME GEÇ ]  [ 🔁 BAŞKA ÖNERİ ]

KESİM EKRANI
  Plaka şemaları + özet ("4 plaka 18mm Beyaz, fire %7")
  [ PDF İNDİR ] [ EXCEL İNDİR ] [ WHATSAPP'TAN GÖNDER ]

MALİYET EKRANI
  Kalem listesi + TOPLAM (çok büyük punto)
  Kâr marjı sürgüsü (%) → MÜŞTERİ FİYATI
  [ TEKLİF PDF OLUŞTUR ] [ WHATSAPP'TAN GÖNDER ]
```
\* Masaüstünde foto yükleme sorununu çözmek için: ekranda QR kod → usta telefonla okutur → telefon tarayıcısından foto direkt projeye düşer. (Mobil sürüm çıkana kadar köprü.)

## 4. Sesli Revizyon Deneyimi

- Usta butona basar, konuşur: "Üst dolapların hepsini camlı yap, evyenin yanına çekmeceli koy."
- Sistem komutu **metin olarak geri gösterir** + planda nereyi değiştireceğini görsel üzerinde işaretler → "Doğru anladıysam ONAYLA."
- Anlaşılmayan komutta seçenek sunar: "Camlı kapağı hangi dolaplara isteriz? [Hepsi] [Sadece sağ] [Göster]".
- Onaydan sonra hem plan hem görsel güncellenir; eski sürüm "Önceki tasarımlar" şeridinde durur (karşılaştırma + geri dönüş).

## 5. Kullanılabilirlik Test Planı

- **Pilot:** 5-10 usta (İstanbul/Ankara Siteler tarzı atölye yoğun bölge), görev bazlı test: "Şu krokiyle baştan teklife kadar git." Hedefler: ilk projeyi **yardımsız ≤15 dk**, kroki onay ekranında düzeltme oranı ölçümü, sesli komut ilk denemede anlaşılma ≥%80.
- Ölçüm: görev tamamlama oranı, hata noktaları ekran kaydı, SUS anketi (hedef ≥75).
- İterasyon: pilotta en çok takılan 3 ekran yeniden tasarlanır, ikinci tur test.

## 6. Erişilebilirlik / Saha Koşulları

- Yazı boyutu ayarı (Normal/Büyük/Çok Büyük), yüksek kontrast tema.
- Tüm kritik bilgiler renkten bağımsız (renk körlüğü): durum rozetlerinde ikon+metin.
- Klavye gerektirmeyen akış: rakam girişleri büyük sayısal tuş takımıyla.
- Eğitim: uygulama içi 3 dakikalık sesli-videolu "ilk proje" rehberi; ayrıca WhatsApp destek hattı (ustaların doğal kanalı).

## 7. Başarı Kriterleri (Kullanılabilirlik)

| Kriter | Hedef |
|---|---|
| İlk proje tamamlama (eğitimsiz) | ≤ 15 dk |
| Kroki ölçü onayında manuel düzeltme | ≤ %20 ölçü |
| Sesli komutun ilk seferde doğru anlaşılması | ≥ %80 |
| Kesim listesi hata oranı (saha doğrulama) | %0 (deterministik formül) |
| SUS skoru | ≥ 75 |
| 30 gün sonra aktif kullanım (pilot) | ≥ %60 |
