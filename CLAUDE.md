# CLAUDE.md — MarangozAI Proje Tanımı

> Bu dosya Claude Code için ana referanstır. Tüm geliştirme kararları bu dosyaya uygun yapılır.
> Detaylar: `TEKNIK_RAPOR.md` ve `KULLANILABILIRLIK_RAPORU.md`.
> **Kesim/bantlama/donanım formüllerinin tek doğruluk kaynağı: `MODUL_FORMULLERI.md`** —
> motor kodu yalnız oradaki formülleri uygular; bant düşümü (§0.2) ve güvenlik kontrolleri (§0.5) zorunludur.
> AI prompt şablonları: `AI_RENDER_PROMPT.md`.

## Ürün Özeti

Marangoz ustaları için Windows masaüstü uygulaması (sonra Android/iOS). Akış:
**Alan fotoğrafı + el krokisi → AI ölçü okuma (usta onaylı) → malzeme/renk sihirbazı → parametrik modül planı → AI fotogerçekçi render → sesli/yazılı revizyon → müşteri onayı (WhatsApp) → kesim + bantlama listesi (PDF/Excel/WhatsApp) → güncel fiyatlarla maliyet + teklif PDF.**

## Altın Kurallar (asla ihlal etme)

1. **Kesim listesi, bantlama ve maliyet ASLA AI görselinden türetilmez.** Tek doğruluk kaynağı parametrik modül planıdır (`CabinetPlan`). AI render yalnızca sunum içindir.
2. **Revizyonlar önce planı değiştirir, görsel plandan yeniden üretilir.** Plan ↔ görsel asla ayrışamaz.
3. **AI'nın okuduğu her ölçü usta onayından geçer.** Onaylanmamış ölçüyle plan kurulamaz.
4. **Hedef kullanıcı teknolojiye uzaktır.** Her UI kararı: tek ekran tek soru, min buton 56px, min yazı 18pt, usta Türkçesi ("Kesim Planı", "Bantlama", "Tasarım Görseli"). CAD benzeri arayüz YASAK.
5. **Çevrimdışı çalışma:** modül motoru, kesim optimizasyonu, raporlar ve (önbellek fiyatlarla) maliyet internetsiz çalışır. Yalnız AI servisleri ve fiyat senkronu internet ister.
6. Tüm ölçüler dahili olarak **mm**, UI'da **cm** gösterilir. Para birimi TL, KDV ayrı satır.

## Teknoloji Yığını

- **UI/Uygulama:** Flutter (Windows hedefi; mobil geçiş için kod paylaşımı). State: Riverpod.
- **Yerel DB:** SQLite (drift). Tablolar: customers, projects, photos, measurements, plans, plan_versions, renders, price_cache, settings.
- **Kesim optimizasyonu:** Dart isolate'ta giyotin 2D bin-packing (FFD + strip placement + yerel iyileştirme). 300 parça < 2 sn. Parametreler: kerf (vars. 4.8 mm), traş payı, damar yönü kilidi, min şerit, artan parça stoğu.
- **AI görsel:** Gemini Flash Image API (Nano Banana sınıfı), soyutlama arayüzü `ImageGenService` (model değiştirilebilir olmalı). Girdi: alan fotoğrafları + plan özeti + malzeme/renk prompt'u.
- **Kroki okuma:** Vision LLM → `{walls:[{len_mm}], openings:[{type,pos,size}], ceiling_h}` JSON. Confidence < eşik → ilgili ölçü onay ekranında kırmızı işaretli.
- **STT:** Whisper/Google STT (tr-TR). **Komut yorumlama:** LLM function calling → `RevisionCommand{target_module, change}`.
- **Raporlar:** PDF (kesim şemaları vektörel çizim + listeler), Excel (xlsx). WhatsApp: `wa.me` paylaşım + dosya paylaşım menüsü.
- **Backend (ince):** Fiyat DB + admin panel (basit web), lisans/aktivasyon, AI proxy (API anahtarları istemcide tutulmaz).

## Veri Modeli (çekirdek)

```
Project { id, customer, status: draft|designed|approved|cut_ready|quoted, photos[], sketch, measurements }
CabinetPlan { id, project_id, version, wall_segments[], modules[] }
Module { code(A1..B2), x_pos, width, height, depth, params{shelves, drawers, glass, ...} }
MaterialSpec { body_material, body_color, door_material, door_color, edge_band{thk,color}, panel_size(2100x2800|1830x3660), thickness }
Part { module_id, name, qty, w, l, material, banding[N,S,E,W], grain_locked }
CutLayout { sheets[ { material, parts_placed[], waste_pct } ] }
CostReport { lines[{item, qty, unit, unit_price, total}], subtotal, margin_pct, customer_price }
PriceDB { items[{sku, category, name, unit, price, updated_at}] } // aylık senkron
```

## Modül Kütüphanesi (MVP: 14 modül)

A1 alt-tek kapak · A2 alt-çift kapak · A3 alt-çekmeceli(2/3/4) · A4 evye · A5 ankastre fırın · A6 bulaşık mak. boşluğu · A7 alt köşe-L · U1 üst-tek · U2 üst-çift · U3 üst-camlı · U4 davlumbaz · U5 üst köşe · B1 boy/kiler · B2 buzdolabı boşluğu.

**Varsayılan ölçüler (TR pratiği):** alt gövde Y=740, D=560, baza 100, tezgah payı 30-40; üst D=320, Y=720 (veya tavana göre), tezgah-üst dolap arası 550-600; boy dolap 2000-2200. Genişlik adımları 300-1200. Davlumbaz/fırın 600, bulaşık 450/600, buzdolabı boşluğu 700-900. Delik düzeni System 32 (5mm delik, 32mm aralık, ön kenardan 37mm); modül yükseklikleri mümkünse 32'nin katına yuvarlanır.

**Parça formülü örneği (A2):** Yan×2 = D×Y (bant: 1 uzun) · Alt = (G−2t)×D (1 uzun) · Kayıt×2 = (G−2t)×100 · Raf = (G−2t−2)×(D−30) (1 uzun) · Arkalık 8mm (kanal, bantsız) · Kapak×2 = ((G−9)/2)×(Y−3) (4 kenar) · Baza önü = G×100. Donanım: kapak Y≤900→2 menteşe, 900-1600→3; çekmece başına 1 çift ray; kapak/çekmece başına 1 kulp. **Her modül formülü birim testli olmalı** (`test/modules/`).

## Geliştirme Fazları

- [ ] **F0:** Flutter Windows iskeleti, SQLite şema, modül motoru çekirdeği + 14 modülün formül testleri.
- [ ] **F1:** Müşteri/proje CRUD, foto + kroki yükleme (QR ile telefondan aktarım köprüsü), kroki→ölçü okuma + onay ekranı, malzeme/renk sihirbazı.
- [ ] **F2:** Otomatik modül yerleşimi (duvar uzunluğu → modül dizilimi; evye/ocak/buzdolabı konumları kullanıcı işaretli), AI render entegrasyonu, sesli+yazılı revizyon döngüsü, sürüm geçmişi, WhatsApp paylaşım.
- [ ] **F3:** Kesim optimizasyon motoru, bantlama metrajı, PDF/Excel raporlar (etiketli plaka şemaları).
- [ ] **F4:** Fiyat DB + web admin + senkron, maliyet raporu, kâr marjı, müşteri teklif PDF'i.
- [ ] **F5:** Lisans/abonelik, MSIX kurulum paketi, ayarlar (kerf, arkalık tipi, varsayılan ölçüler), pilot geri bildirim düzeltmeleri.

## Kabul Kriterleri

1. Kroki onayından teklif PDF'ine eğitimsiz usta ≤15 dk'da ulaşır.
2. Kesim listesi formül testleri %100 geçer; örnek 3 referans mutfakta elle hesapla birebir.
3. Optimizasyon: fire ≤ %12 (tipik mutfak, 2100×2800 plaka), kerf ve damar kilidi doğru uygulanır.
4. Revizyon sonrası kesim listesi son render'la senkron (plan sürümü = render sürümü).
5. İnternetsiz: kayıtlı projede kesim+maliyet üretimi tam çalışır.
6. PDF'ler A4'te okunaklı; Excel kesimciye gönderilebilir sade format.

## Yapma / Yapılmayacaklar

- 3D CAD görünümü, katman paneli, kompleks menüler YAPMA.
- MVP'de CNC GKod çıkışı YOK (F6+ aday). Banyo/yatak odası modülleri F6+ aday.
- AI'dan gelen hiçbir sayıyı onaysız plana yazma.
- İngilizce/teknik jargon UI metni yazma.
