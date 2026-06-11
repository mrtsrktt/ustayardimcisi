/// Module Engine — the heart of MarangozAI.
///
/// Converts Module definitions into cut lists, banding lists, and hardware counts.
/// ALL formulas come from MODUL_FORMULLERI.md — this file just implements them.
/// AI NEVER touches these calculations.
///
/// § references are to MODUL_FORMULLERI.md sections.

import 'project.dart';

// ─── Global defaults (MODUL_FORMULLERI.md §0) ────────────────────────────────

class ModuleDefaults {
  static const double t = 18;          // gövde plaka kalınlığı mm
  static const double ta = 8;          // arkalık kalınlığı mm
  static const double altY = 740;      // alt dolap yükseklik mm
  static const double altD = 560;      // alt dolap derinlik mm
  static const double ustY = 720;      // üst dolap yükseklik mm
  static const double ustD = 320;      // üst dolap derinlik mm
  static const double boyY = 2080;     // boy dolap yükseklik mm
  static const double boyD = 560;      // boy dolap derinlik mm
  static const double bazaH = 100;     // baza yüksekliği mm
  static const double gap = 3;         // kapak arası boşluk mm (§0)
  static const double reveal = 2;      // kapak kenar payı mm (§0)
  static const double rf = 30;         // raf ön geri çekme mm (§0)
  static const double kayitH = 100;    // üst kayıt eni mm (§0)
  static const double rayPayiTeleskopik = 13;
  static const double rayPayiTandem = 12.5;
  static const double korDolgu = 80;   // A7 kör dolgu mm
  static const double korDolguUst = 50; // U5 kör dolgu mm
  static const double firinBosluk = 595; // A5 fırın boşluğu yükseklik mm
  static const double minCekmeceOn = 90; // §0.5/4
  static const double maxModulG = 1200;
  static const double minModulG = 200;

  // Bant kalınlık seçenekleri
  static const double bantInce = 0.4;  // düşüm yapılmaz
  static const double bantOrta = 1.0;  // düşüm yapılır (≥1)
  static const double bantKalin = 2.0; // düşüm yapılır
}

// ─── Hardware rules (§0.4) ───────────────────────────────────────────────────

class HardwareCalc {
  /// Menteşe count by door height (§0.4)
  static int mentese(double kapakBoyMm) {
    if (kapakBoyMm <= 900) return 2;
    if (kapakBoyMm <= 1600) return 3;
    if (kapakBoyMm <= 2000) return 4;
    return 5;
  }

  /// Ray length: D − 60, rounded down to standard sizes
  static int rayBoy(double derinlikMm) {
    final raw = derinlikMm - 60;
    const std = [250, 300, 350, 400, 450, 500, 550];
    return std.where((s) => s <= raw).lastOrNull ?? 250;
  }

  /// Baza foot count per run (§0.4)
  static int bazaAyak(int hatUzunlukMm) {
    // (ΣG/500 rounded up + 1) × 2
    final n = (hatUzunlukMm / 500).ceil() + 1;
    return n * 2;
  }

  /// Kulp: 1 per door/drawer front
  static int kulp(int onSayisi) => onSayisi;

  /// Shelf pins: 4 per shelf
  static int rafPimi(int rafSayisi) => rafSayisi * 4;
}

// ─── Part Builder (immutable) ────────────────────────────────────────────────

class PartBuilder {
  /// Create a single Part with band deduction already computed.
  static Part part({
    required String moduleId,
    required String name,
    required int qty,
    required double netWidth,
    required double netLength,
    required double thickness,
    required String material,
    List<double> banding = const [0, 0, 0, 0],
    bool grainLocked = false,
    String? label,
  }) {
    return Part(
      moduleId: moduleId,
      name: name,
      qty: qty,
      netWidthMm: netWidth,
      netLengthMm: netLength,
      thicknessMm: thickness,
      material: material,
      banding: banding,
      grainLocked: grainLocked,
      label: label,
    );
  }
}

// ─── Kapak / Ön Genel Formülü (§0.1) ─────────────────────────────────────────

/// Full overlay door/drawer front formulas.
class FrontCalc {
  /// Available width for fronts: G − 2×reveal
  static double wKul(double G) => G - 2 * ModuleDefaults.reveal;

  /// Single row front height: Y − 2×reveal
  static double hOn(double Y) => Y - 2 * ModuleDefaults.reveal;

  /// n fronts side by side, each width
  static double frontWidth(double G, int n) {
    final w = wKul(G);
    return (w - (n - 1) * ModuleDefaults.gap) / n;
  }

  /// m fronts stacked, each height
  static double frontHeight(double Y, int m) {
    final h = hOn(Y);
    return (h - (m - 1) * ModuleDefaults.gap) / m;
  }

  /// Set front dimensions (common case: 1×1, 2×1, 1×n)
  static ({double w, double h}) frontDims(double G, double Y, {int across = 1, int stacked = 1}) {
    return (w: frontWidth(G, across), h: frontHeight(Y, stacked));
  }
}

// ─── Arkalık (§0, satır 6/6') ────────────────────────────────────────────────

class ArkalikCalc {
  /// Çakma (surface-mounted) back panel
  static Part cakma(String modId, double G, double Y) {
    return PartBuilder.part(
      moduleId: modId,
      name: 'Arkalık',
      qty: 1,
      netWidth: G - 4,
      netLength: Y - 4,
      thickness: ModuleDefaults.ta,
      material: 'Arkalık',
      banding: [0, 0, 0, 0],
    );
  }

  /// Kanal (groove-mounted) back panel
  static Part kanal(String modId, double G, double Y, {double k = 8}) {
    return PartBuilder.part(
      moduleId: modId,
      name: 'Arkalık',
      qty: 1,
      netWidth: G - 2 * ModuleDefaults.t + 2 * k,
      netLength: Y - 2 * ModuleDefaults.t + 2 * k,
      thickness: ModuleDefaults.ta,
      material: 'Arkalık',
      banding: [0, 0, 0, 0],
    );
  }
}

// ─── Modül Motoru (Ana Sınıf) ────────────────────────────────────────────────

class ModuleEngine {
  final AppSettings settings;

  const ModuleEngine({this.settings = const AppSettings()});

  /// Generate full part list for a single module.
  List<Part> generateParts(Module mod, MaterialSpec mat) {
    return switch (mod.code) {
      ModuleCode.a1 => _buildA1(mod, mat),
      ModuleCode.a2 => _buildA2(mod, mat),
      ModuleCode.a3 => _buildA3(mod, mat),
      ModuleCode.a4 => _buildA4(mod, mat),
      ModuleCode.a5 => _buildA5(mod, mat),
      ModuleCode.a6 => _buildA6(mod, mat),
      ModuleCode.a7 => _buildA7(mod, mat),
      ModuleCode.u1 => _buildU1(mod, mat),
      ModuleCode.u2 => _buildU2(mod, mat),
      ModuleCode.u3 => _buildU3(mod, mat),
      ModuleCode.u4 => _buildU4(mod, mat),
      ModuleCode.u5 => _buildU5(mod, mat),
      ModuleCode.b1 => _buildB1(mod, mat),
      ModuleCode.b2 => _buildB2(mod, mat),
    };
  }

  // ─── A1 — Alt Tek Kapak (§1, G ≤ 600) ─────────────────────────────────

  List<Part> _buildA1(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final nRaf = mod.params.rafSayisi;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // 1. Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // 2. Alt tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // 3. Ön üst kayıt
    parts.add(PartBuilder.part(moduleId: modId, name: 'Ön üst kayıt', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [1, 0, 0, 0]));

    // 4. Arka üst kayıt
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arka üst kayıt', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [0, 0, 0, 0]));

    // 5. Raf
    for (var i = 0; i < nRaf; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Raf', qty: 1,
          netWidth: G - 2 * t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }

    // 6. Arkalık
    final arkalik = settings.arkalikTip == ArkalikTip.kanal
        ? ArkalikCalc.kanal(modId, G, Y)
        : ArkalikCalc.cakma(modId, G, Y);
    parts.add(arkalik);

    // 7. Kapak ×1 (tek kapak)
    final f = FrontCalc.frontDims(G, Y, across: 1);
    parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
        netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
        banding: [2, 2, 2, 2], grainLocked: true));

    // Görünür yan panel opsiyonu
    if (mod.params.gorunurYan) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Görünür yan', qty: 1,
          netWidth: D, netLength: Y, thickness: t, material: 'Kapak',
          banding: [1, 0, 1, 1]));
    }

    return _labelParts(parts, mod.code.name.toUpperCase());
  }

  // ─── A2 — Alt Çift Kapak (§1, 600 < G ≤ 1200) ───────────────────────

  List<Part> _buildA2(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final nRaf = mod.params.rafSayisi;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Gövde: A1 satır 1–6 (aynı)
    parts.addAll(_altGovde(modId, G, Y, D, t, nRaf));

    // 7. Kapak ×2
    final f = FrontCalc.frontDims(G, Y, across: 2);
    for (var i = 0; i < 2; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
          netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
          banding: [2, 2, 2, 2], grainLocked: true));
    }

    // Orta dikme (opsiyonel, G > 900 önerilir)
    if (mod.params.ortaDikme) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Orta dikme', qty: 1,
          netWidth: Y - t, netLength: D - ModuleDefaults.ta, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }

    if (mod.params.gorunurYan) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Görünür yan', qty: 1,
          netWidth: D, netLength: Y, thickness: t, material: 'Kapak',
          banding: [1, 0, 1, 1]));
    }

    return _labelParts(parts, modId);
  }

  // ─── A3 — Alt Çekmeceli (§1) ─────────────────────────────────────────

  List<Part> _buildA3(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final nCek = mod.params.cekmeceSayisi.clamp(2, 4);
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Gövde (raf yok)
    parts.addAll(_altGovde(modId, G, Y, D, t, 0));

    // Çekmece önleri
    final f = FrontCalc.frontDims(G, Y, across: 1, stacked: nCek);
    for (var i = 0; i < nCek; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Çekmece önü', qty: 1,
          netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
          banding: [2, 2, 2, 2], grainLocked: true));
    }

    // Çekmece kutuları
    final rayPayi = ModuleDefaults.rayPayiTeleskopik;
    final boxDisEn = G - 2 * t - 2 * rayPayi;
    final rayBoy = HardwareCalc.rayBoy(D);
    final hKutu = ((f.h - 30).clamp(ModuleDefaults.minCekmeceOn, 180));

    for (var i = 0; i < nCek; i++) {
      // Kutu yanı ×2
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kutu yanı', qty: 2,
          netWidth: rayBoy.toDouble(), netLength: hKutu.toDouble(),
          thickness: t, material: 'Gövde', banding: [0.4, 0, 0, 0]));

      // Kutu ön/arka ×2
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kutu ön/arka', qty: 2,
          netWidth: boxDisEn - 2 * t, netLength: hKutu.toDouble(),
          thickness: t, material: 'Gövde', banding: [0.4, 0, 0, 0]));

      // Kutu dibi
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kutu dibi', qty: 1,
          netWidth: boxDisEn, netLength: rayBoy.toDouble(),
          thickness: ModuleDefaults.ta, material: 'Arkalık',
          banding: [0, 0, 0, 0]));
    }

    return _labelParts(parts, modId);
  }

  // ─── A4 — Evye Dolabı (§1) ───────────────────────────────────────────

  List<Part> _buildA4(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla (4 kenar bant: su koruması)
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 1, 1, 1]));

    // Ön üst kayıt
    parts.add(PartBuilder.part(moduleId: modId, name: 'Ön üst kayıt', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [1, 0, 0, 0]));

    // Arka bağlantı kaydı (arkalık YOK, tesisat)
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arka bağ. kaydı', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [0, 0, 0, 0]));

    // Raf default 0 (sifon)
    if (mod.params.rafSayisi > 0) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Raf', qty: 1,
          netWidth: G - 2 * t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }

    // Kapak ×2 (çift kapak)
    final f = FrontCalc.frontDims(G, Y, across: 2);
    for (var i = 0; i < 2; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
          netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
          banding: [2, 2, 2, 2], grainLocked: true));
    }

    return _labelParts(parts, modId);
  }

  // ─── A5 — Ankastre Fırın (§1, G=600) ─────────────────────────────────

  List<Part> _buildA5(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final fb = ModuleDefaults.firinBosluk;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Fırın üstü tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Fırın üstü tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Arka üst kayıt
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arka üst kayıt', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [0, 0, 0, 0]));

    // Arkalık (sadece üst bölge)
    final arkaBoy = Y - fb - t - 4;
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık', qty: 1,
        netWidth: G - 4, netLength: arkaBoy.clamp(0, arkaBoy),
        thickness: ModuleDefaults.ta, material: 'Arkalık',
        banding: [0, 0, 0, 0]));

    // Üst ön (çekmece veya sabit panel)
    final ustOnBoy = Y - fb - t - 2 * ModuleDefaults.reveal;
    final isCekmece = ustOnBoy >= 110 && !mod.params.sabitRaf;
    parts.add(PartBuilder.part(moduleId: modId,
        name: isCekmece ? 'Üst çekmece önü' : 'Üst panel', qty: 1,
        netWidth: G - 2 * ModuleDefaults.reveal, netLength: ustOnBoy,
        thickness: t, material: 'Kapak',
        banding: [2, 2, 2, 2], grainLocked: true));

    if (isCekmece) {
      final rayPayi = ModuleDefaults.rayPayiTeleskopik;
      final boxDisEn = G - 2 * t - 2 * rayPayi;
      final rayBoy = HardwareCalc.rayBoy(D);
      final hKutu = (ustOnBoy - 30).clamp(ModuleDefaults.minCekmeceOn, 180);
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kutu yanı', qty: 2,
          netWidth: rayBoy.toDouble(), netLength: hKutu.toDouble(),
          thickness: t, material: 'Gövde', banding: [0.4, 0, 0, 0]));
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kutu ön/arka', qty: 2,
          netWidth: boxDisEn - 2 * t, netLength: hKutu.toDouble(),
          thickness: t, material: 'Gövde', banding: [0.4, 0, 0, 0]));
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kutu dibi', qty: 1,
          netWidth: boxDisEn, netLength: rayBoy.toDouble(),
          thickness: ModuleDefaults.ta, material: 'Arkalık',
          banding: [0, 0, 0, 0]));
    }

    return _labelParts(parts, modId);
  }

  // ─── A6 — Bulaşık Makinesi Boşluğu (§1, G=450/600) ──────────────────

  List<Part> _buildA6(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan panel ×0–2 (komşu modüllerle paylaşılır)
    // Eğer hat sonundaysa görünür yan eklenir
    if (mod.params.gorunurYan) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Görünür yan', qty: 1,
          netWidth: D, netLength: Y, thickness: t, material: 'Kapak',
          banding: [1, 0, 1, 1]));
    }

    // Üst bağlantı kaydı
    final komsuYanSayisi = 2; // varsayılan: iki yanda komşu var
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst bağ. kaydı', qty: 1,
        netWidth: G - komsuYanSayisi * t, netLength: ModuleDefaults.kayitH,
        thickness: t, material: 'Gövde', banding: [1, 0, 0, 0]));

    return _labelParts(parts, modId);
  }

  // ─── A7 — Alt Köşe L (§1, vars. 900×900) ─────────────────────────────

  List<Part> _buildA7(Module mod, MaterialSpec mat) {
    final G1 = mod.widthMm, G2 = mod.depthMm; // köşe: width=G1, depth yerine G2
    final Y = mod.heightMm, D = ModuleDefaults.altD;
    final t = mat.thicknessMm;
    final kd = ModuleDefaults.korDolgu;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan (duvar tarafı) ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla parça-1
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla P1', qty: 1,
        netWidth: G1 - t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla parça-2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla P2', qty: 1,
        netWidth: G2 - D - t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Ön üst kayıt ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Ön üst kayıt', qty: 2,
        netWidth: G1 - t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [1, 0, 0, 0]));

    // Kör dolgu paneli
    parts.add(PartBuilder.part(moduleId: modId, name: 'Kör dolgu', qty: 1,
        netWidth: kd, netLength: Y, thickness: t, material: 'Kapak',
        banding: [1, 0, 0, 0]));

    // Arkalık ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık P1', qty: 1,
        netWidth: G1 - 4, netLength: Y - 4, thickness: ModuleDefaults.ta,
        material: 'Arkalık', banding: [0, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık P2', qty: 1,
        netWidth: G2 - D - 4, netLength: Y - 4, thickness: ModuleDefaults.ta,
        material: 'Arkalık', banding: [0, 0, 0, 0]));

    // Kapak ×1
    final kapakEn = G1 - D - kd - 2 * ModuleDefaults.reveal;
    parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
        netWidth: kapakEn, netLength: Y - 2 * ModuleDefaults.reveal,
        thickness: t, material: 'Kapak',
        banding: [2, 2, 2, 2], grainLocked: true));

    // Raf: L-raf yerine 2 düz raf
    parts.add(PartBuilder.part(moduleId: modId, name: 'Raf P1', qty: 1,
        netWidth: G1 - t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
        material: 'Gövde', banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Raf P2', qty: 1,
        netWidth: G2 - D - t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
        material: 'Gövde', banding: [1, 0, 0, 0]));

    return _labelParts(parts, modId);
  }

  // ─── U1 — Üst Tek Kapak (§2, D=320, G ≤ 600) ────────────────────────

  List<Part> _buildU1(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final nRaf = mod.params.rafSayisi.clamp(0, 6); // default 2
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Üst tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Raf
    for (var i = 0; i < nRaf; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Raf', qty: 1,
          netWidth: G - 2 * t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }

    // Arkalık
    final arkalik = settings.arkalikTip == ArkalikTip.kanal
        ? ArkalikCalc.kanal(modId, G, Y)
        : ArkalikCalc.cakma(modId, G, Y);
    parts.add(arkalik);

    // Kapak ×1
    final f = FrontCalc.frontDims(G, Y, across: 1);
    parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
        netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
        banding: [2, 2, 2, 2], grainLocked: true));

    if (mod.params.gorunurYan) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Görünür yan', qty: 1,
          netWidth: D, netLength: Y, thickness: t, material: 'Kapak',
          banding: [1, 0, 1, 1]));
    }

    return _labelParts(parts, modId);
  }

  // ─── U2 — Üst Çift Kapak ─────────────────────────────────────────────

  List<Part> _buildU2(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final nRaf = mod.params.rafSayisi.clamp(0, 6);
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // U1 gövdesi (kapak hariç)
    parts.addAll(_ustGovde(modId, G, Y, D, t, nRaf));

    // Kapak ×2
    final f = FrontCalc.frontDims(G, Y, across: 2);
    for (var i = 0; i < 2; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
          netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
          banding: [2, 2, 2, 2], grainLocked: true));
    }

    return _labelParts(parts, modId);
  }

  // ─── U3 — Üst Camlı Kapak (§2) ───────────────────────────────────────

  List<Part> _buildU3(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final nRaf = mod.params.rafSayisi.clamp(0, 4);
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // U1/U2 gövdesi
    parts.addAll(_ustGovde(modId, G, Y, D, t, nRaf));

    // Kapak sayısı: G ≤ 600 → 1, değilse 2
    final kSayisi = G <= 600 ? 1 : 2;

    // Cam kapak → alüminyum profil çerçeveli (satın alma kalemi)
    // NOT: Cam kapak parça olarak eklenmez, m² kalemi olarak maliyete eklenir.
    // Ancak MDF çerçeveli seçeneği için parçalar:
    if (!mod.params.camli) {
      // MDF çerçeveli cam kapak
      final f = FrontCalc.frontDims(G, Y, across: kSayisi);
      for (var i = 0; i < kSayisi; i++) {
        // Çerçeve dikme ×2
        parts.add(PartBuilder.part(moduleId: modId, name: 'Cam kapak dikme', qty: 2,
            netWidth: 60, netLength: f.h, thickness: t, material: 'Kapak',
            banding: [2, 2, 2, 2], grainLocked: true));
        // Çerçeve başlık ×2
        parts.add(PartBuilder.part(moduleId: modId, name: 'Cam kapak başlık', qty: 2,
            netWidth: 60, netLength: f.w - 120, thickness: t, material: 'Kapak',
            banding: [2, 2, 2, 2], grainLocked: true));
      }
    }

    return _labelParts(parts, modId);
  }

  // ─── U4 — Davlumbaz (§2, G=600, Y=350–400) ──────────────────────────

  List<Part> _buildU4(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Üst tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Ön panel/kapak
    final f = FrontCalc.frontDims(G, Y, across: 1);
    parts.add(PartBuilder.part(moduleId: modId, name: 'Ön panel', qty: 1,
        netWidth: f.w, netLength: f.h, thickness: t, material: 'Kapak',
        banding: [2, 2, 2, 2], grainLocked: true));

    // Alt tabla ve arkalık YOK (baca/cihaz)

    return _labelParts(parts, modId);
  }

  // ─── U5 — Üst Köşe (§2, 600×600) ────────────────────────────────────

  List<Part> _buildU5(Module mod, MaterialSpec mat) {
    final G1 = mod.widthMm, G2 = mod.depthMm;
    final Y = mod.heightMm, D = ModuleDefaults.ustD;
    final t = mat.thicknessMm;
    final kd = ModuleDefaults.korDolguUst;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla P1', qty: 1,
        netWidth: G1 - t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla P2', qty: 1,
        netWidth: G2 - D - t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Üst tabla ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst tabla P1', qty: 1,
        netWidth: G1 - t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst tabla P2', qty: 1,
        netWidth: G2 - D - t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Kör dolgu
    parts.add(PartBuilder.part(moduleId: modId, name: 'Kör dolgu', qty: 1,
        netWidth: kd, netLength: Y, thickness: t, material: 'Kapak',
        banding: [1, 0, 0, 0]));

    // Arkalık ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık P1', qty: 1,
        netWidth: G1 - 4, netLength: Y - 4, thickness: ModuleDefaults.ta,
        material: 'Arkalık', banding: [0, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık P2', qty: 1,
        netWidth: G2 - D - 4, netLength: Y - 4, thickness: ModuleDefaults.ta,
        material: 'Arkalık', banding: [0, 0, 0, 0]));

    // Kapak ×1
    final kapakEn = G1 - D - kd - 2 * ModuleDefaults.reveal;
    parts.add(PartBuilder.part(moduleId: modId, name: 'Kapak', qty: 1,
        netWidth: kapakEn, netLength: Y - 2 * ModuleDefaults.reveal,
        thickness: t, material: 'Kapak',
        banding: [2, 2, 2, 2], grainLocked: true));

    return _labelParts(parts, modId);
  }

  // ─── B1 — Kiler/Boy Dolap (§3, G=600, Y=2080, D=560) ────────────────

  List<Part> _buildB1(Module mod, MaterialSpec mat) {
    final G = mod.widthMm, Y = mod.heightMm, D = mod.depthMm;
    final t = mat.thicknessMm;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Yan ×2
    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Alt tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Üst tabla
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Sabit ara tabla (1400 hizasında)
    parts.add(PartBuilder.part(moduleId: modId, name: 'Ara tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));

    // Raflar ×4
    for (var i = 0; i < 4; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Raf', qty: 1,
          netWidth: G - 2 * t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }

    // Arkalık — 2076 > 1830 ise 2 parçaya böl (§0.5/1)
    final arkaBoy = Y - 4;
    if (arkaBoy > 1830) {
      // Split into 2 pieces; ek kayıt arkasında
      parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık alt', qty: 1,
          netWidth: G - 4, netLength: 1400, thickness: ModuleDefaults.ta,
          material: 'Arkalık', banding: [0, 0, 0, 0]));
      parts.add(PartBuilder.part(moduleId: modId, name: 'Arkalık üst', qty: 1,
          netWidth: G - 4, netLength: arkaBoy - 1400, thickness: ModuleDefaults.ta,
          material: 'Arkalık', banding: [0, 0, 0, 0]));
    } else {
      final arkalik = settings.arkalikTip == ArkalikTip.kanal
          ? ArkalikCalc.kanal(modId, G, Y)
          : ArkalikCalc.cakma(modId, G, Y);
      parts.add(arkalik);
    }

    // Kapaklar: alt (1400 hizası) + üst
    final kSayisi = G <= 600 ? 1 : 2;
    final altKapakBoy = 1400 - ModuleDefaults.reveal - ModuleDefaults.gap / 2;
    final ustKapakBoy = Y - 1400 - ModuleDefaults.reveal - ModuleDefaults.gap / 2;
    final kapakEn = FrontCalc.frontWidth(G, kSayisi);

    for (var i = 0; i < kSayisi; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Alt kapak', qty: 1,
          netWidth: kapakEn, netLength: altKapakBoy, thickness: t,
          material: 'Kapak', banding: [2, 2, 2, 2], grainLocked: true));
      parts.add(PartBuilder.part(moduleId: modId, name: 'Üst kapak', qty: 1,
          netWidth: kapakEn, netLength: ustKapakBoy, thickness: t,
          material: 'Kapak', banding: [2, 2, 2, 2], grainLocked: true));
    }

    return _labelParts(parts, modId);
  }

  // ─── B2 — Buzdolabı Boşluğu (§3, G=700–900) ─────────────────────────

  List<Part> _buildB2(Module mod, MaterialSpec mat) {
    final G = mod.widthMm;
    final t = mat.thicknessMm;
    final modId = mod.code.name.toUpperCase();
    final parts = <Part>[];

    // Boy yan panel (görünür → kapak malzemesi)
    parts.add(PartBuilder.part(moduleId: modId, name: 'Boy yan panel', qty: 1,
        netWidth: 600, netLength: 2080, thickness: t, material: 'Kapak',
        banding: [1, 0, 1, 1]));

    // Üst kutu (U1 formülü, Y=350–400)
    final ustMod = Module(
        code: ModuleCode.u1, xPosMm: 0, widthMm: G, heightMm: 380,
        depthMm: ModuleDefaults.ustD, params: const ModuleParams(rafSayisi: 0));
    parts.addAll(_buildU1(ustMod, mat));

    // Üst bağlantı kaydı
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst bağ. kaydı', qty: 1,
        netWidth: G - t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [0, 0, 0, 0]));

    return _labelParts(parts, modId);
  }

  // ─── Yardımcı Metotlar ───────────────────────────────────────────────────

  /// Alt modül gövde parçaları (A1/A2/A3 ortak: satır 1–6)
  List<Part> _altGovde(String modId, double G, double Y, double D, double t, int nRaf) {
    final parts = <Part>[];

    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Ön üst kayıt', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Arka üst kayıt', qty: 1,
        netWidth: G - 2 * t, netLength: ModuleDefaults.kayitH, thickness: t,
        material: 'Gövde', banding: [0, 0, 0, 0]));
    for (var i = 0; i < nRaf; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Raf', qty: 1,
          netWidth: G - 2 * t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }
    final arkalik = settings.arkalikTip == ArkalikTip.kanal
        ? ArkalikCalc.kanal(modId, G, Y)
        : ArkalikCalc.cakma(modId, G, Y);
    parts.add(arkalik);

    return parts;
  }

  /// Üst modül gövde parçaları (U1/U2/U3 ortak)
  List<Part> _ustGovde(String modId, double G, double Y, double D, double t, int nRaf) {
    final parts = <Part>[];

    parts.add(PartBuilder.part(moduleId: modId, name: 'Yan', qty: 2,
        netWidth: D, netLength: Y, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Alt tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    parts.add(PartBuilder.part(moduleId: modId, name: 'Üst tabla', qty: 1,
        netWidth: G - 2 * t, netLength: D, thickness: t, material: 'Gövde',
        banding: [1, 0, 0, 0]));
    for (var i = 0; i < nRaf; i++) {
      parts.add(PartBuilder.part(moduleId: modId, name: 'Raf', qty: 1,
          netWidth: G - 2 * t - 2, netLength: D - ModuleDefaults.rf, thickness: t,
          material: 'Gövde', banding: [1, 0, 0, 0]));
    }
    final arkalik = settings.arkalikTip == ArkalikTip.kanal
        ? ArkalikCalc.kanal(modId, G, Y)
        : ArkalikCalc.cakma(modId, G, Y);
    parts.add(arkalik);

    return parts;
  }

  /// Assign unique labels: P-{MODID}.{index}-{count}
  List<Part> _labelParts(List<Part> parts, String modId) {
    final grouped = <String, int>{}; // name → count
    final labelCounts = <String, int>{};

    for (final p in parts) {
      grouped[p.name] = (grouped[p.name] ?? 0) + 1;
    }

    final current = <String, int>{};
    final result = <Part>[];
    var globalIdx = 0;

    for (final p in parts) {
      current[p.name] = (current[p.name] ?? 0) + 1;
      final count = grouped[p.name]!;
      final idx = current[p.name]!;
      final label = 'P-$modId-${p.name}-$idx/$count';
      globalIdx++;
      result.add(Part(
        moduleId: p.moduleId,
        name: p.name,
        qty: p.qty,
        netWidthMm: p.netWidthMm,
        netLengthMm: p.netLengthMm,
        thicknessMm: p.thicknessMm,
        material: p.material,
        banding: p.banding,
        grainLocked: p.grainLocked,
        label: label,
      ));
    }

    return result;
  }

  // ─── Hardware Summary ──────────────────────────────────────────────────

  /// Generate hardware list for a module.
  Map<String, int> generateHardware(Module mod) {
    final hw = <String, int>{};
    final G = mod.widthMm, Y = mod.heightMm;
    final t = ModuleDefaults.t;

    switch (mod.code) {
      case ModuleCode.a1:
        hw['Menteşe'] = 2;
        hw['Kulp'] = 1;
        break;
      case ModuleCode.a2:
        hw['Menteşe'] = 4;
        hw['Kulp'] = 2;
        break;
      case ModuleCode.a3:
        final n = mod.params.cekmeceSayisi.clamp(2, 4);
        hw['Ray (çift)'] = n;
        hw['Kulp'] = n;
        break;
      case ModuleCode.a4:
        hw['Menteşe'] = 4;
        hw['Kulp'] = 2;
        break;
      case ModuleCode.a5:
        final ustOnBoy = Y - ModuleDefaults.firinBosluk - t - 2 * ModuleDefaults.reveal;
        if (ustOnBoy >= 110 && !mod.params.sabitRaf) {
          hw['Ray (çift)'] = 1;
          hw['Kulp'] = 1;
        } // else: sabit panel, donanım yok
        break;
      case ModuleCode.a6:
        // no hardware (machine uses its own)
        break;
      case ModuleCode.a7:
        hw['Menteşe (geniş açı)'] = 2;
        hw['Kulp'] = 1;
        break;
      case ModuleCode.u1:
        hw['Menteşe'] = HardwareCalc.mentese(Y - 2 * ModuleDefaults.reveal);
        hw['Kulp'] = 1;
        hw['Askı'] = 2;
        break;
      case ModuleCode.u2:
        hw['Menteşe'] = 2 * HardwareCalc.mentese(FrontCalc.frontHeight(Y, 1));
        hw['Kulp'] = 2;
        hw['Askı'] = 2;
        break;
      case ModuleCode.u3:
        final kSayisi = G <= 600 ? 1 : 2;
        hw['Cam menteşesi'] = HardwareCalc.mentese(FrontCalc.frontHeight(Y, 1)) * kSayisi;
        hw['Kulp'] = kSayisi;
        hw['Askı'] = 2;
        break;
      case ModuleCode.u4:
        hw['Menteşe (amortisörlü)'] = 2;
        hw['Askı'] = 2;
        break;
      case ModuleCode.u5:
        hw['Menteşe (geniş açı)'] = 2;
        hw['Kulp'] = 1;
        hw['Askı'] = 2;
        break;
      case ModuleCode.b1:
        final kSayisi = G <= 600 ? 1 : 2;
        final altBoy = 1400 - ModuleDefaults.reveal - ModuleDefaults.gap / 2;
        final ustBoy = Y - 1400 - ModuleDefaults.reveal - ModuleDefaults.gap / 2;
        hw['Menteşe'] = (HardwareCalc.mentese(altBoy) + HardwareCalc.mentese(ustBoy)) * kSayisi;
        hw['Kulp'] = kSayisi * 2; // alt + üst
        break;
      case ModuleCode.b2:
        hw['Askı'] = 2;
        break;
    }

    return hw;
  }
}
