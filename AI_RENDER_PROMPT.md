# AI_RENDER_PROMPT.md — Tasarım Görseli Üretim Şablonları

> Görsel üretim modeli (Gemini Flash Image sınıfı) İngilizce prompt'larda daha tutarlı sonuç verir.
> Uygulama, ustanın Türkçe seçimlerini aşağıdaki şablona otomatik yerleştirir. Usta prompt görmez.

## 1. İlk Render Prompt Şablonu

**Girdi görselleri (sırayla):** [1..n] alan fotoğrafları (en geniş açılı = referans kamera), [n+1] seçilen kapak rengi/deseni karteladan doku görseli (varsa).

```
You are rendering a photorealistic kitchen cabinet installation proposal for a carpenter.

REFERENCE: Image 1 shows the customer's actual empty/old kitchen. Keep the EXACT same
camera angle, room geometry, walls, ceiling, floor, window and door positions, and
natural lighting as Image 1. Do not move or resize any architectural element.

TASK: Replace/install fitted kitchen cabinets according to this plan:
- Lower cabinet run: {alt_hat_uzunluğu_cm} cm long, counter height ~90 cm, along {duvar_tarifi}.
  Modules left to right: {modül_listesi: ör. "60cm sink cabinet with double doors, 60cm
  3-drawer unit, 60cm built-in oven unit, 60cm dishwasher gap"}.
- Upper cabinet run: {üst_hat} cm, depth ~32 cm, mounted ~55 cm above counter.
  Modules: {üst_modül_listesi: ör. "two 60cm double-door units, 60cm glass-door unit,
  60cm hood unit above the cooktop"}.
- Tall units: {boy_modüller / "none"}.

MATERIALS & COLORS:
- Door fronts: {malzeme: "high-gloss acrylic" | "matte membrane (vacuum-pressed MDF)" |
  "melamine-faced chipboard" | "melamine-faced MDF"} in {kapak_rengi_açıklaması, RAL/desen adı};
  use Image {k} as the exact texture reference for the fronts.
- Carcass/visible sides: {gövde_rengi}.
- Countertop: {tezgah}. Handles: {kulp_tipi}. Plinth: {baza_rengi}, 10 cm.

CONSTRAINTS:
- Proportions must match the stated centimeter dimensions relative to the room.
- Realistic materials: correct gloss/matte reflectance, visible door gaps (~3 mm),
  edge-banded panel edges. No people, no text, no watermark logos, no brand names.
- Keep existing appliances visible only where the plan specifies gaps for them.
Output: one photorealistic image, same resolution/aspect as Image 1.
```

## 2. Revizyon Prompt Şablonu (sesli/yazılı komut sonrası)

Komut LLM tarafından yapılandırılır → plan güncellenir → görsel şu şablonla yeniden üretilir
(önceki render + güncel plan birlikte verilir, **tutarlılık için**):

```
Image 1 is the previously approved kitchen render. Apply ONLY the following changes and
keep everything else pixel-consistent (camera, lighting, untouched cabinets, room):

CHANGES:
{değişiklik_listesi: ör.
- "Replace the doors of both upper double-door units with aluminum-framed frosted glass doors."
- "Change all lower drawer fronts to {yeni_renk}, texture as in Image 2."}

Do not alter dimensions, module positions, countertop, or any element not listed above.
```

## 3. Komut Yorumlama (STT → RevisionCommand) Sistem Prompt'u

```
Görev: Marangozun Türkçe sesli/yazılı komutunu aşağıdaki JSON şemasına çevir.
Şema: { "actions": [ { "target": "<modül kodu|konum tarifi: 'sağdan 2. üst dolap'>",
        "field": "tip|kapak_rengi|malzeme|çekmece_sayısı|cam|kulp|genişlik",
        "value": "<yeni değer>" } ], "belirsiz": ["anlaşılmayan kısımlar"] }
Kurallar: Konum tariflerini plana göre modül ID'sine çöz (plan JSON ektedir).
Emin olmadığın hedefi 'belirsiz' listesine yaz — ASLA tahminle modül değiştirme.
Ölçü değişikliklerinde değeri mm'ye çevir. Türkçe şive/ağız varyasyonlarına toleranslı ol
("kapağ", "çekmece" / "çekmeci", "camlı" / "camekanlı").
```
Uygulama `belirsiz` doluysa ustaya görsel üzerinde seçenek butonları gösterir (bkz. Kullanılabilirlik Raporu §4).

## 4. Kroki Ölçü Okuma Prompt'u

```
Görev: El çizimi mutfak krokisi fotoğrafından ölçüleri çıkar.
Çıktı JSON: { "walls": [{"label":"A","length_mm":0}], "openings":
[{"type":"window|door|column","wall":"A","from_left_mm":0,"width_mm":0,"height_mm":0,
"sill_mm":0}], "ceiling_mm":0, "confidence": {"<alan>": 0.0-1.0} }
Kurallar: Rakam okunamıyorsa null + confidence<0.5. cm yazılmış değerleri mm'ye çevir
(ör. "240" mutfak bağlamında 2400 mm kabul et; 3 haneli ve >100 ise cm varsay).
ASLA ölçü uydurma. Ok yönlerini ve köşe ilişkilerini duvar sırasına yansıt.
```
Confidence < 0.8 alanlar onay ekranında kırmızı işaretlenir; usta onaylamadan plan kurulamaz (Altın Kural 3).

## 5. Kalite Notları
- Aynı projede tüm renderlarda **aynı referans fotoğraf + aynı seed/önceki render** kullanılır → stil kayması engellenir.
- Render üzerine uygulama tarafında "Temsili görseldir — üretim ölçüleri kesim listesindedir" filigranı basılır.
- Müşteriye giden görselde marka logosu ve fiyat YOKTUR (teklif PDF'i ayrıdır).
