# MarangozAI — Teknik Rapor
**Mutfak/Dolap Tasarım, Kesim Listesi ve Maliyet Uygulaması**
Tarih: Haziran 2026 · Hedef Platform: Windows Masaüstü (sonra Android/iOS)

---

## 1. Yönetici Özeti

Uygulama, teknolojiye uzak marangoz ustalarının müşteri evinde çektiği **alan fotoğrafları** ve **elle çizilmiş ölçü krokisini** girdi alarak üç çıktı üretir:

1. **Fotogerçekçi tasarım görseli** (müşteriye sunum/onay için) — sesli veya yazılı komutla revize edilebilir.
2. **Kesim listesi + bantlama listesi** (PDF/Excel, WhatsApp paylaşımı).
3. **Malzeme metrajı + güncel fiyatlarla toplam maliyet ve teklif raporu.**

**Mimari ilke:** AI görseli "satış katmanı"dır; üretim verisi (kesim, bantlama, maliyet) görselden değil, arka planda kurulan **parametrik modül modelinden** üretilir. Profesyonel yazılımlar da aynı mantıkla çalışır: PolyBoard kesim listesini 3D tasarımdan otomatik üretir, OptiCut kesim yerleşimini optimize eder. Bu ayrım, ölçü doğruluğunu AI'nın görsel yorumuna bırakmamayı sağlar — sektörde AI fotoğraf tasarımlarının "konsept olduğu, üretim çizimi olmadığı" açıkça kabul edilir.

---

## 2. Sistem Mimarisi

```
┌─────────────────────────── WINDOWS MASAÜSTÜ (Flutter) ───────────────────────────┐
│                                                                                  │
│  UI Katmanı (sihirbaz akışı, büyük butonlar, sesli komut)                        │
│  ├── Proje Yöneticisi (müşteri, proje, fotoğraflar, durum)                       │
│  ├── Parametrik Modül Motoru  ← KALP. Modül → parça listesi formülleri (yerel)   │
│  ├── Kesim Optimizasyon Motoru (2D giyotin bin-packing, yerel, Dart/Rust)        │
│  ├── Rapor Üretici (PDF / Excel) + WhatsApp paylaşımı (wa.me / Web API)          │
│  └── Yerel Veritabanı (SQLite: projeler, modüller, fiyat önbelleği)              │
│                                                                                  │
└───────────────┬──────────────────────────────────────────────────────────────────┘
                │ HTTPS
┌───────────────▼──────────────────── BULUT SERVİSLERİ ───────────────────────────┐
│  AI Görsel Servisi   → Gemini 2.5/3.x Flash Image ("Nano Banana") veya muadili  │
│  Kroki/Ölçü Okuma    → Vision LLM (Claude / Gemini): el yazısı ölçüleri JSON'a   │
│  Ses → Metin         → Whisper API veya Google STT (Türkçe)                      │
│  Doğal Dil → Komut   → LLM: "üst dolapları beyaz yap" → yapılandırılmış revizyon │
│  Fiyat Veritabanı    → Bizim yönettiğimiz merkezi DB + aylık güncelleme + admin  │
│  Lisans/Abonelik     → Aktivasyon, cihaz kilidi, abonelik durumu                 │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**Neden Flutter:** Tek kod tabanı ile Windows + Android + iOS. Mobil geçiş hedefi baştan belli olduğu için Electron/WPF yerine Flutter en düşük toplam maliyeti verir. Kesim optimizasyonu gibi CPU-yoğun işler Dart isolate veya Rust FFI ile yerelde çalışır (internet kesilse bile kesim listesi üretilir; yalnızca AI görsel ve fiyat güncellemesi internet ister).

---

## 3. İş Akışı (Uçtan Uca)

| Aşama | Girdi | İşlem | Çıktı |
|---|---|---|---|
| 1. Proje aç | Müşteri adı, tel | Proje kaydı | Proje dosyası |
| 2. Fotoğraf yükle | Alan fotoğrafları (3-6 adet) | Saklama + AI'ya referans | Görsel arşivi |
| 3. Kroki yükle | Karakalem ölçü krokisi fotoğrafı | Vision LLM ölçüleri okur → usta onaylar/düzeltir | Doğrulanmış ölçü seti (mm) |
| 4. Sihirbaz | Malzeme (MDF/MDFlam/Suntalam/High Gloss/Membran), gövde rengi, kapak rengi, kulp, cam kapak, çekmece sayısı, tezgah | Her ekranda tek soru, görsel seçenekler | Proje parametreleri |
| 5. Otomatik yerleşim | Ölçü + parametreler | Motor duvar uzunluğunu standart modüllere böler (evye, ocak, buzdolabı zorunlu modülleri yerleştirir) | Modül listesi |
| 6. AI görsel | Fotoğraf + modül planı + parametreler | Çok-görselli düzenleme modeli mevcut mutfak fotoğrafının üzerine tasarımı giydirir | Fotogerçekçi render |
| 7. Revizyon döngüsü | Sesli/yazılı komut | STT → LLM → modül planı VE görsel güncellenir (ikisi senkron) | Yeni render + güncel plan |
| 8. Müşteri onayı | WhatsApp paylaşımı | wa.me linki / paylaşım menüsü | Onay |
| 9. Kesim + bantlama | Modül planı | Formüller parça listesi üretir → optimizasyon plakalara yerleştirir → bant metrajı | PDF/Excel listeler |
| 10. Maliyet | Parça listesi + fiyat DB | Plaka adedi, bant metresi, menteşe/ray/kulp adedi × güncel fiyat | Maliyet raporu + müşteri teklifi PDF |

**Kritik kural (7. adım):** Revizyon görseli değil **planı** değiştirir; görsel plandan yeniden üretilir. Böylece kesim listesi her zaman son onaylı tasarımla birebir aynıdır.

---

## 4. Parametrik Modül Sistemi

### 4.1 Standartlar (Türkiye pratiği)

Araştırma bulguları:
- Alt dolap: yükseklik 74 cm gövde (+ baza ~10 cm + tezgah ~3-4 cm ≈ 87-91 cm bitmiş), derinlik 56-60 cm. Sektör kaynakları alt dolap yüksekliğini 74 cm gövde / 85-90 cm bitmiş, derinliği 56-60 cm aralığında verir.
- Üst dolap: derinlik 30-35 cm, yükseklik 60-92 cm, tezgahtan 50-60 cm yukarıda.
- Genişlik adımları: 30 / 40 / 45 / 50 / 60 / 80 / 90 / 100 / 120 cm. Evye dolabı 60-100 cm, davlumbaz/aspiratör modülü 60 cm, ankastre fırın 60 cm, bulaşık makinesi 45/60 cm, buzdolabı boşluğu 70-90 cm.
- Kiler (boy) dolabı: 200-220 cm yükseklik, alt dolap derinliğinde.
- Delik sistemi: **System 32** — 5 mm delikler, 32 mm aralık, ön kenardan 37 mm; donanım (menteşe, ray) endüstri standardı bu sisteme göre üretilir. Modül yüksekliklerini 32'nin katlarına oturtmak CNC/delik şablonu uyumu sağlar.

### 4.2 Modül Kütüphanesi (MVP — 14 modül)

| Kod | Modül | Parametreler |
|---|---|---|
| A1 | Alt dolap, tek kapak | G, Y, D, raf sayısı |
| A2 | Alt dolap, çift kapak | G, Y, D, raf |
| A3 | Alt çekmeceli (2/3/4 çekmece) | G, Y, D, çekmece sayısı |
| A4 | Evye dolabı | G (arka kayıt açık, tabla delikli) |
| A5 | Ankastre fırın modülü | G=60 |
| A6 | Bulaşık makinesi boşluğu | G=45/60 (yalnız yan panel + birleştirme) |
| A7 | Alt köşe dolap (L) | G1, G2 |
| U1 | Üst dolap, tek kapak | G, Y, D |
| U2 | Üst dolap, çift kapak | G, Y, D |
| U3 | Üst cam kapaklı | G, Y, D |
| U4 | Davlumbaz modülü | G=60 |
| U5 | Üst köşe dolap | G1, G2 |
| B1 | Boy (kiler) dolabı | G, Y, D |
| B2 | Buzdolabı boşluğu/çevresi | G |

### 4.3 Parça Formülleri (örnek: A2 — alt dolap çift kapak, 18 mm plaka)

Girdi: G (genişlik), Y (yükseklik=740), D (derinlik=560), t=18, arkalık 8 mm, kapak boşluğu 3 mm.

| Parça | Adet | En (mm) | Boy (mm) | Bant kenarları |
|---|---|---|---|---|
| Yan | 2 | D | Y | 1 uzun (ön) |
| Alt tabla | 1 | G − 2t | D | 1 uzun (ön) |
| Üst kayıt | 2 | G − 2t | 100 | 1 uzun |
| Raf | n | G − 2t − 2 | D − 30 | 1 uzun (ön) |
| Arkalık (8 mm) | 1 | G − 2t + 16* | Y − ... | bantsız (kanal) |
| Kapak | 2 | (G − 3·gap)/2 | Y − gap | 4 kenar |
| Baza önü | 1 | G | 100 | 1 uzun |

\* Arkalık detayı kanal/üstten çakma tercihine göre formüllenir; usta ayarlarından "arkalık tipi" seçilir.
Her modül bu şekilde 10-20 satırlık deterministik formül setidir. **AI bu hesaplara karışmaz.** Donanım kuralları da formüldür: kapak yüksekliği ≤900 → 2 menteşe, 900-1600 → 3; çekmece başına 1 çift ray; kapak/çekmece başına 1 kulp.

---

## 5. Kesim Optimizasyonu

- Problem: 2D guillotine cutting stock (NP-hard). Pratik çözüm: **First-Fit Decreasing + giyotin kısıtı**, strip-based yerleşim, ardından yerel iyileştirme. Türk pazarındaki araçlar da aynı yaklaşımı kullanır: Korutaş'ın aracı giyotin kesim planını boyuna→enine tam boy kesim sırasıyla üretir ve 5 mm bıçak payını (kerf) otomatik hesaba katar.
- Zorunlu parametreler: **testere payı (kerf, vars. 4-5 mm)**, kenar traşlama payı, **damar/desen yönü kilidi** (ahşap desenli plakalarda parça döndürme kapalı), minimum şerit genişliği, artan parça (fire) stoğu.
- Plaka ölçüleri (TR standartları): MDF ve sunta **210×280 cm ve 183×366 cm** standart plakalarda satılır; High Gloss/akrilik paneller tipik 122×244 / 122×280. Kalınlıklar 8/18/30 mm yaygın.
- Çıktı: plaka başına görsel yerleşim şeması (etiketli), plaka adedi, fire %, kesim sırası.
- Hedef performans: 300 parçalık mutfak < 2 sn (yerel hesap).

## 6. Bantlama Listesi

Her parça formülünde hangi kenarların bantlanacağı tanımlı (bkz. 4.3 tablo). Çıktı:
- Parça bazında: hangi kenar, kaç mm bant (0.4 / 1 / 2 mm PVC seçenekleri), renk eşleşmesi (kapak rengi vs gövde rengi).
- Toplam: renk+kalınlık bazında metraj + %8-10 fire payı. PanelOptimizer gibi yerli rakipler de kenar bant metraj/maliyet hesabını standart özellik olarak sunar — pazar beklentisi bu.

---

## 7. AI Katmanı

| Görev | Model/Servis | Not |
|---|---|---|
| Fotoğraftan tasarım render | Gemini Flash Image ailesi (Nano Banana) | Çoklu görsel girişi destekler; ürün/doku referansıyla iç mekân yeniden stillendirme tam bizim senaryomuz. Konuşma tarzı yinelemeli düzenlemede stil kayması olmadan tutarlılık sağlar. Yüksek kalite gerekirse Pro sürümü 4K çıktı verir. |
| Kroki ölçü okuma | Claude / Gemini vision | El yazısı rakamlar → {duvar uzunlukları, pencere/kapı konumları} JSON. **Her zaman usta onay ekranından geçer** (yanlış okuma riskine karşı). |
| Sesli komut | Whisper / Google STT | Türkçe, şive toleransı yüksek. |
| Komut → revizyon | LLM (function calling) | "sağdaki üst dolabı camlı yap" → {modül: U1@x, değişiklik: tip=U3}. |

Maliyet öngörüsü: görsel üretim çağrısı başına ~0.04-0.13 $; proje başına 5-10 render ≈ 0.5-1.5 $. Abonelik fiyatlamasında dikkate alınmalı.

---

## 8. Fiyat Veritabanı ve Maliyet Modülü

- Merkezi DB (bizim sunucu) + basit web admin paneli. Kategoriler: plaka (marka/renk/kalınlık/ebat), kenar bandı (m), menteşe (frenli/frensiz), ray (telekopik/tandem, boy), kulp, baza ayağı, vida/kavela, tezgah (mtül), cam (m²), işçilik kalemleri (opsiyonel).
- Aylık güncelleme: admin panelden toplu Excel içe aktarma. Uygulama açılışta senkronlar, çevrimdışıyken son önbelleği kullanır ve "fiyatlar X tarihli" uyarısı basar.
- Maliyet raporu: kalem kalem adet/metraj × birim fiyat → toplam; üzerine usta kâr marjı % girer → **müşteri teklifi PDF** (logo, müşteri adı, render görseli, toplam fiyat — kesim detayı YOK).

---

## 9. Rakip Analizi ve Konumlandırma

| Ürün | Güç | Zayıflık (bizim fırsat) |
|---|---|---|
| **PolyBoard + OptiCut** | Kesim listesini 3D tasarımdan otomatik üretir, CNC çıkışı | İkisi de ayrı lisans, öğrenme eğrisi yüksek, İng./teknik arayüz |
| **Cabinet Vision** | Tam entegre tasarım+optimizasyon+CNC | ~5.000 $'dan başlayan fiyat — küçük usta için erişilmez |
| **Mozaik** | Üretim odaklı, otomatik kesim listesi + panel optimizasyonu pakette | Yine CAD bilgisi ister |
| **PRO100 (TR'de yaygın)** | 3D tasarım, kesim listesi, maliyetlendirme, panel optimizer raporları tek tıkla | Klasik CAD arayüzü; fotoğraftan tasarım yok, sesli komut yok |
| **CutList Plus fx** | Windows'ta parça listesi → optimize yerleşim + malzeme satın alma raporu | Tasarım yok, sadece liste; İngilizce |
| **KopEksper (TR)** | 10+ yıl, 1500 kullanıcı; testere payı, bant/PVC metraj, maliyet, Excel, GKod, yerli ebatlama makineleriyle entegrasyon | Sadece optimizasyon — tasarım ve teklif yok |
| **PanelOptimizer.pro (TR)** | Web tabanlı, kenar bant metraj/maliyet, kesim süresi, sürükle-bırak manuel düzenleme | Sadece optimizasyon |
| **AI mutfak araçları** (KitchenDesign.io, Rendair, Decory vb.) | Fotoğraf yükle → 60 sn'de fotogerçekçi yeniden tasarım, stil seçenekleri | Konsept üretir, üretim planı değil — kesim listesi/maliyet yok; ev sahibine satılır, ustaya değil |

**Boşluk net:** Piyasada *ya* tasarım var *ya* optimizasyon var; **fotoğraftan AI tasarım + otomatik kesim/bantlama + güncel TL maliyetle teklif** üçünü tek basit Türkçe akışta birleştiren ürün yok. Konumlandırma: "Ustanın cebindeki mühendis."

---

## 10. Güvenlik, Lisans, Riskler

- Lisans: cihaz-bağlı aktivasyon + aylık/yıllık abonelik (AI maliyeti aboneliği zorunlu kılar). Çevrimdışı tolerans: 14 gün.
- Veri: müşteri fotoğrafları kişisel veri → KVKK aydınlatma metni, bulutta şifreli saklama veya yalnız-yerel mod.
- **Risk 1 — AI render ölçü tutarsızlığı:** render "temsilidir" ibaresi + kesinlik daima parametrik plandan. **Risk 2 — kroki okuma hatası:** zorunlu onay ekranı. **Risk 3 — AI API fiyat/politika değişimi:** görsel servis soyutlama katmanı (model değiştirilebilir). **Risk 4 — fiyat verisi bayatlığı:** tarih damgası + uyarı.

## 11. Geliştirme Fazları (Claude Code)

1. **F0 (1 hf):** Proje iskeleti (Flutter Windows), SQLite şema, modül formül motoru çekirdeği + birim testleri.
2. **F1 (2-3 hf):** Proje/müşteri yönetimi, fotoğraf-kroki yükleme, kroki okuma + onay ekranı, sihirbaz.
3. **F2 (3-4 hf):** Otomatik modül yerleşimi, AI render, sesli/yazılı revizyon döngüsü, WhatsApp paylaşımı.
4. **F3 (3-4 hf):** Kesim optimizasyonu, bantlama, PDF/Excel raporlar.
5. **F4 (2 hf):** Fiyat DB + admin panel + maliyet/teklif raporu.
6. **F5 (2 hf):** Lisanslama, kurulum paketi (MSIX/Inno), 5-10 ustayla saha pilotu.

Toplam: ~13-16 hafta tek geliştirici eşdeğeri; Claude Code ile önemli ölçüde kısalır.
