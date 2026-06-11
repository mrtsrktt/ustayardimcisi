# MarangozAI — Yapılan İşler

> **Proje:** Usta Yardımcısı — Marangozlar için mutfak/dolap tasarım, kesim listesi ve maliyet uygulaması
> **GitHub:** https://github.com/mrtsrktt/ustayardimcisi
> **Son Güncelleme:** 12 Haziran 2026
> **Test:** 66/66 passing · **Analyze:** 0 error

---

## 1. Proje İskeleti (F0)

### 1.1 Flutter Projesi
- Flutter 3.44.1 (stable) ile Windows hedefli proje oluşturuldu
- Riverpod state yönetimi entegre edildi
- Tema: büyük yazı (min 18pt), büyük buton (min 56px), usta Türkçesi

### 1.2 Veri Modelleri (`lib/models/project.dart` — 400+ satır)
- `Project`, `Customer`, `Measurement`, `WallSegment`, `Opening`
- `CabinetPlan`, `Module`, `ModuleParams`
- `MaterialSpec`, `EdgeBandSpec`
- `Part` — `material` (gerçek ad), `role` (govde/kapak/arkalik), `banding` [Ö,A,S,Sğ]
- `CutLayout`, `SheetLayout`, `PlacedPartData`
- `CostReport`, `CostLine`, `PriceEntry`
- `AppSettings` — kerf, trim, plaka ebadı, arkalık tipi

### 1.3 SQLite Veritabanı (`lib/database/database.dart` — 400+ satır)
- Raw SQLite3 ile 10 tablo: customers, projects, photos, wall_measurements, openings, cabinet_plans, plan_modules, material_specs, renders, price_cache, app_settings
- CRUD operasyonları, ayar okuma/yazma
- Varsayılan ayarlar otomatik oluşturulur

---

## 2. Modül Motoru (F0)

### 2.1 14 Modül Formülü (`lib/modules/module_engine.dart` — 1000+ satır)
Tüm modüller MODUL_FORMULLERI.md'deki formüllere birebir uygun:

| Kod | Modül | Özellik |
|-----|------|---------|
| A1 | Alt tek kapak | G≤600, raf, kapak×1 |
| A2 | Alt çift kapak | 600<G≤1200, raf, kapak×2, ops. orta dikme |
| A3 | Alt çekmeceli | 2/3/4 çekmece, ray, kutu parçaları |
| A4 | Evye dolabı | Arkalık yok, su koruması bant |
| A5 | Ankastre fırın | Fırın boşluğu 595mm, üst çekmece/panel |
| A6 | Bulaşık makinesi | Yapısal parçalar, görünür yan opsiyonu |
| A7 | Alt köşe L | 900×900, kör dolgu, geniş açı menteşe |
| U1 | Üst tek kapak | G≤600, alt+üst tabla, askı |
| U2 | Üst çift kapak | Çift kapak, askı |
| U3 | Üst camlı | Cam kapak (alüminyum/MDF çerçeve ops.) |
| U4 | Davlumbaz | Alt+arkalık yok, ön panel |
| U5 | Üst köşe | 600×600, kör dolgu |
| B1 | Kiler/boy | 2080mm, alt+üst kapak, ara tabla, arkalık bölme |
| B2 | Buzdolabı boşluğu | Yan panel + üst kutu |

### 2.2 Bant Düşümü ve Güvenlik Kontrolleri (§0.2, §0.5)
- Bant kalınlığı ≥1mm → kesim ölçüsüne düşüm uygulanır
- Parça plaka ebadını aşamaz
- Modül genişliği 200-1200mm aralığında olmalı
- Çekmece önü ≥90mm (ray sığar)
- Damar yönlü malzemede kapak döndürülemez

### 2.3 Donanım Kuralları (§0.4)
- Menteşe: ≤900→2, 901-1600→3, 1601-2000→4, >2000→5
- Ray boyu = D−60 → standart yuvarlama (250/300/350/400/450/500)
- Kulp: ön yüz başına 1
- Baza ayağı: hat bazında hesaplanır
- Askı: üst modül başına 2

### 2.4 Hat Seviyesi Parçalar (`lib/modules/run_engine.dart` — 240 satır)
- D1: Dolgu çıtası (duvar − Σmodül genişliği ≥10mm ise)
- D2: Baza önü (2400mm'den uzunsa bölünür)
- D3-D5: Tezgah, süpürgelik, kornij (satın alma kalemleri)

---

## 3. Kesim Optimizasyonu (F3)

### 3.1 CutOptimizer (`lib/modules/cut_optimizer.dart` — 300+ satır)
- 2D guillotine shelf-based bin-packing
- Malzeme+kalınlık bazında gruplama (farklı malzeme → farklı plaka)
- Shelf (raf) tabanlı yerleşim, soldan sağa
- Best-fit gap filling: shelf içi boşluklara küçük parçalar
- Rotasyon desteği (damar kilitli değilse)
- Kerf (4.8mm), traş payı, overlap validasyonu
- Sonuç: SheetLayout listesi (plaka başına parça yerleşimi)

### 3.2 CutConfig
- Plaka ebadı, kerf, trim, min şerit genişliği
- `PlateSize`: standart ebatlar (2100×2800, 1830×3660, 1220×2800)
- `materialSizes`: malzeme rolüne göre farklı plaka ebadı
- AppSettings'ten okuma: `CutConfig.fromSettings()`

---

## 4. Raporlama (F3)

### 4.1 Kesimci Sipariş Formu (`lib/services/siparis_formu.dart` — 300 satır)
- **Furkan Orman Ürünleri** sipariş formu referans alındı
- **Ölçüler cm** (tek ondalık: 56.4), mm değil
- Aynı ölçü+bant kombinasyonu **konsolide tek satır**
- Bant gösterimi: **B|B|E|E** 4 sabit kutucuk (X=bantlı, ·=bantsız)
- Malzeme başına **ayrı PDF sayfası / Excel sheet**
- Sıralama: büyük parçadan küçüğe (alan)
- **Bant Özeti** sayfa altında (eski 80 satırlık liste kaldırıldı)
- Plaka şeması sayfaları korundu

### 4.2 PDF Plaka Şeması
- Her plaka için etiketli vektörel çizim
- Malzeme adı, ebat, parça adedi, fire % gösterilir
- Sayfa sınırına sığacak şekilde otomatik ölçeklenir

### 4.3 Excel Çıktısı
- Malzeme başına ayrı sheet
- Sipariş formu formatında (NO, BOY cm, EN cm, ADET, BANT, RENK)

---

## 5. Maliyet ve Fiyat (F4)

### 5.1 Fiyat Veritabanı (`lib/services/cost_service.dart` — 400 satır)
- **DefaultPrices**: TR 2026 piyasa fiyatları
  - Plaka: MDFlam 1850 TL, High Gloss 3200 TL, Akrilik 3800 TL, Suntalam 1350 TL
  - Bant: 0.4mm=12 TL/m, 1mm=22 TL/m, 2mm=35 TL/m
  - Donanım: menteşe 45-150 TL, ray 180-280 TL/çift, kulp 65-120 TL
  - Kesim ücreti: 100 TL/plaka (ayarlardan değiştirilebilir)
  - Bantlama işçiliği: 0.4mm=10 TL/m, 1mm=20 TL/m, 2mm=40 TL/m (malzemeden ayrı)

### 5.2 Maliyet Hesaplama
- Plaka × plaka adedi (malzeme bazında ayrı fiyat)
- Bant × metraj (malzeme + işçilik ayrı satırlar)
- Donanım × adet (normalize isimlerle eşleştirme)
- Kesim ücreti (plaka başı)
- Montaj işçilik (modül başı)
- KDV ayrı satır (%20)
- `findPlatePrice()`: tam isim eşleşmesi + fallback loglama

### 5.3 Teklif
- Varsayılan: **"—"** (usta girene kadar boş)
- Sonuç ekranında kar marjı (%) veya teklif tutarı giriş alanı
- KDV dahil teklif hesaplanır

### 5.4 PriceSyncService
- Varsayılan fiyat listesi oluşturma
- Remote senkron altyapısı (TODO)

---

## 6. UI ve Kullanıcı Deneyimi

### 6.1 Ana Ekran (`lib/screens/home_screen.dart`)
- Proje listesi (müşteri adı, durum rozeti, tarih)
- Büyük "+ YENİ PROJE" butonu
- Ayarlar butonu (sağ üst)

### 6.2 Müşteri Formu (`lib/screens/customer_form_screen.dart`)
- Ad, telefon, adres, not
- İlerleme noktaları (6 adım)

### 6.3 Sihirbaz (`lib/screens/wizard_screen.dart` — 900+ satır)
5 adımlı sihirbaz akışı:

| Adım | İçerik |
|------|--------|
| **1. Fotoğraf** | Çoklu fotoğraf yükleme, grid önizleme, silme |
| **2. Kroki** | Kroki görseli + duvar uzunluğu girişi (cm) |
| **3. Malzeme/Renk** | Gövde · Alt kapak · Üst kapak — ayrı malzeme+renk seçimi |
| **4. Detay** | Çekmece sayısı · Camlı · Arkalık kalınlığı · Bant kalınlığı · Cihaz konumları |
| **5. Tasarım** | **2D önizleme** + metin özeti + boşluk/taşma uyarısı |

### 6.4 2D Duvar Önizleme (CustomPaint)
- Alt/üst modüller önden görünüş
- Çekmeceli → yatay bölme çizgileri, çift kapak → dikey çizgi
- Camlı modül → mavi ton dolgu
- Tezgah + baza çizgisi
- Duvar toplam uzunluğu etiketi
- Kalan boşluk/taşma cm uyarısı (kırmızı/portakal)
- **Modüllere tıklanabilir** → düzenleme paneli açılır

### 6.5 Modül Düzenleme Paneli
- Genişlik slider (30-120cm, 5cm adım)
- Tip değiştir (A1↔A2↔A3↔A4 / U1↔U2↔U3)
- Modül sil / araya ekle
- Değişiklikler anında önizlemeye yansır

### 6.6 Cihaz Konumu İşaretleme
- Evye, ocak/fırın, buzdolabı — soldan cm girişi
- WallAnchors → PlacementEngine'e aktarılır
- Evye → A4, Ocak → A5+U4, Buzdolabı → B2 otomatik yerleşir

### 6.7 Plaka Ebat Seçimi (ZORUNLU dialog)
- "Tasarımı Oluştur" butonu → önce ebat dialog'u
- Her malzeme grubu için ayrı radyo seçenek
- HG/Akrilik → varsayılan 1220×2800
- Atlanamaz (barrierDismissible: false)

### 6.8 Sonuç Ekranı (`lib/screens/result_screen.dart` — 700+ satır)
3 sekmeli:

| Sekme | İçerik |
|-------|--------|
| **Plaka Şeması** | Renk kodlu parça yerleşimi (Mavi=kapak, Yeşil=gövde, Turuncu=arkalık), lejant |
| **Malzeme Listesi** | Gruplu kesim listesi (m²), plakalar (birim fiyatlı), bant (malzeme+işçilik ayrı), donanım, kesim ücreti, TOPLAM, TEKLİF girişi |
| **İndir** | PDF/Excel butonları, "Farklı Ebatla Tekrar Hesapla", önceki sonuç özeti |

### 6.9 Ayarlar Ekranı (`lib/screens/settings_screen.dart`)
- Kesim: kerf, traş, plaka en/boy
- Alt/üst/boy dolap varsayılan ölçüleri
- Kapak boşluğu, kenar payı, raf çekme
- Arkalık tipi (çakma/kanal), bant düşümü

---

## 7. Yerleşim Motoru (F2)

### 7.1 PlacementEngine (`lib/modules/placement_engine.dart`)
- Duvar uzunluğu → standart modül dizilimi
- Zorunlu modüller: evye, ocak, buzdolabı, bulaşık mak.
- Alt/üst hat ayrımı
- Dolgu çıtası hesabı
- Çok duvarlı L/U mutfak desteği (`generateKitchen()`)
- WallAnchors ile kullanıcı işaretli konum desteği

---

## 8. Servisler ve Altyapı

### 8.1 AI Servisleri (`lib/services/ai_services.dart`)
- Soyut arayüzler: `ImageGenService`, `SketchReaderService`, `RevisionInterpreter`
- Gemini API implementasyonları (Flash Image, Vision, function calling)
- Stub implementasyonlar (API anahtarı olmadan ç wake)
- RenderPromptBuilder: AI_RENDER_PROMPT.md şablonlarını kullanır

### 8.2 WhatsApp Paylaşım (`lib/services/sharing_service.dart`)
- wa.me linkleri ile WhatsApp paylaşımı
- Sistem share sheet fallback
- Hazır mesaj şablonları (onay, kesim, teklif)

### 8.3 Lisans Sistemi (`lib/services/license_service.dart`)
- 16 haneli lisans anahtarı (SHA256 checksum)
- 30 gün deneme, 14 gün çevrimdışı tolerans

### 8.4 Sürüm Geçmişi
- Plan versiyon takibi (DB: cabinet_plans)
- Render takibi (DB: renders)
- ResultScreen'te "Plan v1/v2/v3..." gösterimi
- Her "Farklı Ebatla Tekrar Hesapla"da versiyon artar

---

## 9. Testler (66 adet)

| Test Dosyası | Test Sayısı | Kapsam |
|-------------|------------|--------|
| `all_modules_test.dart` | 17 | 14 modül + bant düşümü + donanım |
| `module_engine_test.dart` | 9 | Modül motoru detay testleri |
| `cut_optimizer_test.dart` | 8 | Optimizer + bant hesaplama |
| `cost_service_test.dart` | 5 | Maliyet hesaplama + fiyat |
| `fixture_test.dart` | 3 | Referans proje fixtures |
| `placement_engine_test.dart` | 6 | Yerleşim motoru |
| `mixed_material_test.dart` | 5 | Karışık malzeme senaryoları |
| `settings_flow_test.dart` | 17 | Ayarlar akışı + arkalık + ebat + bant işçilik + kesim ücreti |
| `plan_sync_test.dart` | 3 | Plan→kesim senkron testleri |
| `widget_test.dart` | 1 | Ana ekran smoke test |
| **Toplam** | **66** | |

---

## 10. Mimari Kararlar ve Prensipler

1. **Kesim listesi ASLA AI görselinden türetilmez** — tek kaynak `CabinetPlan`
2. **Revizyon önce planı değiştirir** — görsel plandan yeniden üretilir
3. **AI ölçüleri usta onayından geçer** — confidence<0.8 → kırmızı işaret
4. **Usta Türkçesi** — "Kesim Planı", "Bantlama", "Tasarım Görseli"
5. **Tek ekran tek soru** — min 56px buton, min 18pt yazı
6. **Çevrimdışı çalışma** — modül motoru + kesim + maliyet internetsiz
7. **Ölçüler mm** (dahili), **cm** (UI ve sipariş formu)
8. **Para TL**, KDV ayrı satır

---

## 11. Bilinen Eksikler

- **AI render entegrasyonu:** Gemini implementasyonu yazıldı, API anahtarı yönetimi ve UI bağlantısı eksik
- **Sesli/yazılı revizyon döngüsü:** STT + LLM function calling altyapısı yazıldı, UI ve akış bağlantısı eksik
- **Alt/üst/baza yükseklik ayarları:** ModuleDefaults statik, AppSettings'ten okunmuyor
- **PriceSyncService remote senkron:** TODO
- **CNC GKod çıkışı:** F6+ aday
- **Banyo/yatak odası modülleri:** F6+ aday
- **Windows Developer Mode** gerekli (Flutter symlink desteği)
