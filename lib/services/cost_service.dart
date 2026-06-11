/// Cost calculation and price management for MarangozAI.
///
/// Calculates total cost from parts, sheets, banding, and hardware.
/// Supports default prices (offline) and remote price DB sync (online).
/// All prices in TL. VAT separate line item per CLAUDE.md.

import '../models/project.dart';
import '../modules/cut_optimizer.dart';
import '../services/report_service.dart';

// ─── Price Entry ─────────────────────────────────────────────────────────────

class PriceItem {
  final String sku;
  final String category;
  final String name;
  final String unit;       // adet, m, mtul, m2, plaka, cift, set
  final double price;
  final DateTime updatedAt;

  PriceItem({
    required this.sku,
    required this.category,
    required this.name,
    required this.unit,
    required this.price,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

// ─── Default Price Database ──────────────────────────────────────────────────

/// Default prices (TR market ~2026). Updated via remote sync.
/// All prices include standard markup but exclude VAT.
class DefaultPrices {
  // Plates (per sheet, 2100×2800 unless specified)
  static const Map<String, double> plates = {
    'MDFlam 18mm Beyaz': 1850,
    'MDFlam 18mm Antrasit': 2100,
    'MDFlam 18mm Krem': 1950,
    'MDFlam 18mm Gri': 2000,
    'MDFlam 18mm Mese': 2050,
    'MDFlam 18mm Ceviz': 2200,
    'Suntalam 18mm Beyaz': 1350,
    'Suntalam 18mm Antrasit': 1500,
    'High Gloss 18mm Beyaz': 3200,
    'High Gloss 18mm Antrasit': 3500,
    'High Gloss 18mm Krem': 3300,
    'Membran 18mm Beyaz': 2800,
    'Membran 18mm Krem': 2900,
    'Membran 18mm Antrasit': 3000,
    'Akrilik 18mm Beyaz': 3800,
    'Akrilik 18mm Antrasit': 4000,
    'MDF 18mm (boya)': 2200,
    'Arkalik 8mm': 650,
    'Arkalik 3mm': 350,
    '183×366 18mm MDFlam Beyaz': 3100,
    '183×366 18mm Suntalam Beyaz': 2300,
    // 1220×2800 plates (High Gloss / Akrilik) — TODO: gercek piyasa fiyati
    '122×280 18mm High Gloss Beyaz': 2100,
    '122×280 18mm High Gloss Antrasit': 2300,
    '122×280 18mm Akrilik Beyaz': 2500,
    '122×280 18mm Akrilik Antrasit': 2700,
  };

  // Edge banding (per meter)
  static const Map<String, double> banding = {
    '0.4mm PVC': 12,
    '1mm PVC': 22,
    '2mm PVC': 35,
  };

  // Hardware
  static const Map<String, double> hardware = {
    'Mentese (frenli)': 85,
    'Mentese (frensiz)': 45,
    'Mentese (genis aci 175°)': 120,
    'Mentese (amortisorlu)': 150,
    'Cam mentesesi': 130,
    'Ray 250mm (cift)': 180,
    'Ray 300mm (cift)': 200,
    'Ray 350mm (cift)': 220,
    'Ray 400mm (cift)': 240,
    'Ray 450mm (cift)': 260,
    'Ray 500mm (cift)': 280,
    'Kulp modern': 65,
    'Kulp klasik': 80,
    'Kulp profilsiz': 120,
    'Baza ayagi (cift)': 25,
    'Aski takimi': 45,
    'Vida/kavela/minifix set': 35,
    'Raf pimi (4 adet)': 15,
  };

  // Countertops (per mtul)
  static const Map<String, double> countertops = {
    'Tezgah laminant': 550,
    'Tezgah akrilik': 1200,
    'Tezgah granit': 1800,
    'Tezgah kompakt': 950,
    'Tezgah Corian': 2500,
    'Supurgelik laminant': 120,
    'Supurgelik akrilik': 250,
  };

  // Glass
  static const double camM2 = 750;       // cam m²
  static const double camProfilMtul = 180; // aluminyum profil mtül

  // Labor (optional, per module)
  static const double montajIscilikModul = 250;
  static const double kesimIscilikSaat = 500;
  static const double cutPricePerPlate = 100; // Kesim ucreti plaka basi

  /// Normalize Turkish characters for matching.
  static String _norm(String s) =>
      s.replaceAll('ı', 'i').replaceAll('I', 'i').replaceAll('s', 's').replaceAll('S', 'S');

  /// Normalize hardware name from module_engine to cost_service price key.
  static String _normalizeHwName(String engineName) {
    // Map common engine names to price DB keys
    final map = {
      'Menteşe': 'Mentese (frenli)',
      'Menteşe (geniş açı)': 'Mentese (genis aci 175°)',
      'Menteşe (amortisörlü)': 'Mentese (amortisorlu)',
      'Cam menteşesi': 'Cam mentesesi',
      'Kulp': 'Kulp modern',
      'Askı': 'Aski takimi',
      'Ray (çift)': 'Ray 500mm (cift)',
    };
    return map[engineName] ?? engineName;
  }

  /// Find plate price from full material name (e.g. "MDFlam 18mm Beyaz").
  static double findPlatePrice(String fullName) {
    // Direct match
    if (DefaultPrices.plates.containsKey(fullName)) return DefaultPrices.plates[fullName]!;

    // Normalize and try matching
    final norm = _norm(fullName);
    for (final k in DefaultPrices.plates.keys) {
      if (_norm(k) == norm) return DefaultPrices.plates[k]!;
    }

    // Partial match: check if the key contains the material type
    for (final k in DefaultPrices.plates.keys) {
      if (_norm(k).contains(_norm(fullName).substring(0, fullName.length.clamp(0, 10)).trim())) {
        return DefaultPrices.plates[k]!;
      }
    }

    // Fallback
    print('WARNING: No price found for plate "$fullName", using fallback');
    return DefaultPrices.plates['MDFlam 18mm Beyaz']!;
  }

  /// Look up plate price by description.
  static double getPlatePrice(String material, String color, double thickness) {
    final key = '$material ${thickness.toInt()}mm $color';
    if (plates.containsKey(key)) return plates[key]!;

    // Try normalized version
    final normKey = _norm(key);
    for (final k in plates.keys) {
      if (_norm(k) == normKey) return plates[k]!;
    }

    // Fallback with warning
    print('WARNING: No price found for plate "$key", using MDFlam 18mm Beyaz fallback');
    return plates['MDFlam 18mm Beyaz']!;
  }

  /// Look up banding price per meter.
  static double getBandingPrice(double thicknessMm) {
    if (thicknessMm <= 0.5) return banding['0.4mm PVC']!;
    if (thicknessMm <= 1.0) return banding['1mm PVC']!;
    return banding['2mm PVC']!;
  }
}

// ─── Cost Line ───────────────────────────────────────────────────────────────

class CostLine {
  final String item;
  final double qty;
  final String unit;
  final double unitPrice;
  final double total;

  const CostLine({
    required this.item,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    required this.total,
  });
}

class CostReport {
  final List<CostLine> lines;
  final double subtotal;
  final double vatRate;       // 0.20 = 20%
  final double vat;
  final double total;
  final double marginPct;
  final double customerPrice;

  const CostReport({
    this.lines = const [],
    this.subtotal = 0,
    this.vatRate = 0.20,
    this.vat = 0,
    this.total = 0,
    this.marginPct = 0,
    this.customerPrice = 0,
  });

  /// Create with profit margin applied.
  CostReport withMargin(double marginPercent) {
    final margin = customerPrice > 0
        ? customerPrice
        : subtotal * (1 + marginPercent / 100);
    final newVat = margin * vatRate;
    return CostReport(
      lines: lines,
      subtotal: subtotal,
      vatRate: vatRate,
      vat: newVat,
      total: margin + newVat,
      marginPct: marginPercent,
      customerPrice: margin,
    );
  }

  String get formattedCustomerPrice =>
      customerPrice > 0 ? '${customerPrice.toStringAsFixed(0)} TL' : '—';

  String get formattedTotal =>
      '${total.toStringAsFixed(0)} TL (KDV dahil)';
}

// ─── Cost Calculator ─────────────────────────────────────────────────────────

class CostCalculator {
  final double vatRate;
  final double defaultMarginPct;

  const CostCalculator({
    this.vatRate = 0.20,
    this.defaultMarginPct = 25,
  });

  /// Calculate full cost from project parts, sheets, and hardware.
  CostReport calculate({
    required List<Part> allParts,
    required List<SheetLayout> sheets,
    required Map<String, int> hardware,
    required String bodyMaterial,
    required String bodyColor,
    required String doorMaterial,
    required String doorColor,
    double edgeBandThickness = 2,
    String countertopType = 'Tezgah laminant',
    double countertopLengthMtul = 3.0,
    bool hasGlassCabinet = false,
    int glassDoorCount = 0,
    double glassDoorWidth = 500,
    double glassDoorHeight = 700,
    double wallLengthMtul = 3.0,
  }) {
    final lines = <CostLine>[];

    // 1. Plates (from cut sheets)
    final plateCounts = MaterialCalculator.plateCounts(sheets);
    for (final entry in plateCounts.entries) {
      final fullName = entry.key; // e.g. "MDFlam 18mm Beyaz" or "Arkalik 8mm"
      double price = DefaultPrices.findPlatePrice(fullName);
      lines.add(CostLine(
        item: '$fullName plaka',
        qty: entry.value.toDouble(),
        unit: 'plaka',
        unitPrice: price,
        total: price * entry.value,
      ));
    }

    // 2. Edge banding
    final bandingMetraj = BandingCalculator.calculateMetraj(allParts);
    for (final entry in bandingMetraj.entries) {
      final thickness = double.tryParse(
          entry.key.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 2;
      final price = DefaultPrices.getBandingPrice(thickness);
      final metraj = entry.value;
      lines.add(CostLine(
        item: 'Kenar bandı ${entry.key}',
        qty: metraj,
        unit: 'm',
        unitPrice: price,
        total: price * metraj,
      ));
    }

    // 3. Hardware — normalize names for price matching
    final hwPrices = <String, double>{};
    for (final entry in hardware.entries) {
      final normName = DefaultPrices._normalizeHwName(entry.key);
      double price = DefaultPrices.hardware[normName] ??
          DefaultPrices.hardware[entry.key] ?? 50;

      // Try fuzzy match
      if (price == 50 && !DefaultPrices.hardware.containsKey(entry.key)) {
        for (final hwKey in DefaultPrices.hardware.keys) {
          final shortKey = DefaultPrices._norm(entry.key);
          final search = shortKey.length > 3 ? shortKey.substring(0, shortKey.length.clamp(0, 8)) : shortKey;
          if (DefaultPrices._norm(hwKey).contains(search)) {
            price = DefaultPrices.hardware[hwKey]!;
            break;
          }
        }
      }

      lines.add(CostLine(
        item: normName,
        qty: entry.value.toDouble(),
        unit: entry.key.contains('Ray') ? 'cift' : 'adet',
        unitPrice: price,
        total: price * entry.value,
      ));
    }

    // 4. Countertop
    lines.add(CostLine(
      item: countertopType,
      qty: countertopLengthMtul,
      unit: 'mtul',
      unitPrice: DefaultPrices.countertops[countertopType] ?? 550,
      total: (DefaultPrices.countertops[countertopType] ?? 550) * countertopLengthMtul,
    ));

    // 5. Glass (if any)
    if (hasGlassCabinet && glassDoorCount > 0) {
      final camArea = (glassDoorWidth * glassDoorHeight / 1000000) * glassDoorCount; // mm² → m²
      lines.add(CostLine(
        item: 'Cam (kapak)',
        qty: camArea,
        unit: 'm²',
        unitPrice: DefaultPrices.camM2,
        total: DefaultPrices.camM2 * camArea,
      ));
      lines.add(CostLine(
        item: 'Aluminyum cerceve',
        qty: glassDoorCount * 4 * glassDoorHeight / 1000.0,
        unit: 'mtul',
        unitPrice: DefaultPrices.camProfilMtul,
        total: DefaultPrices.camProfilMtul * glassDoorCount * 4 * glassDoorHeight / 1000,
      ));
    }

    // 6. Bantlama isciligi (malzemeden AYRI)
    for (final entry in bandingMetraj.entries) {
      final thickness = double.tryParse(
          entry.key.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1;
      final iscilikPrice = thickness <= 0.5 ? 10.0 : thickness <= 1.0 ? 20.0 : 40.0;
      lines.add(CostLine(
        item: 'Bantlama isciligi (${entry.key})',
        qty: entry.value,
        unit: 'm',
        unitPrice: iscilikPrice,
        total: iscilikPrice * entry.value,
      ));
    }

    // 7. Kesim ucreti (plaka basi)
    lines.add(CostLine(
      item: 'Kesim ucreti',
      qty: sheets.length.toDouble(),
      unit: 'plaka',
      unitPrice: DefaultPrices.cutPricePerPlate,
      total: DefaultPrices.cutPricePerPlate * sheets.length,
    ));

    // 8. Labor
    final modulCount = allParts.map((p) => p.moduleId).toSet().length;
    lines.add(CostLine(
      item: 'Montaj iscilik',
      qty: modulCount.toDouble(),
      unit: 'modul',
      unitPrice: DefaultPrices.montajIscilikModul,
      total: DefaultPrices.montajIscilikModul * modulCount,
    ));

    // Calculate subtotal
    final subtotal = lines.fold<double>(0, (sum, l) => sum + l.total);
    final vat = subtotal * vatRate;
    final total = subtotal + vat;
    // Customer price = subtotal (usta kendi girecek, varsayilan: —)
    return CostReport(
      lines: lines,
      subtotal: subtotal,
      vatRate: vatRate,
      vat: vat,
      total: total,
      marginPct: 0,        // usta girene kadar 0
      customerPrice: 0,    // usta girene kadar 0 (—)
    );
  }
}

// ─── Hardware calculator helper (from module_engine) ─────────────────────────

class HardwareCalc {
  static int mentese(double kapakBoyMm) {
    if (kapakBoyMm <= 900) return 2;
    if (kapakBoyMm <= 1600) return 3;
    if (kapakBoyMm <= 2000) return 4;
    return 5;
  }

  static int rayBoy(double derinlikMm) {
    final raw = derinlikMm - 60;
    const std = [250, 300, 350, 400, 450, 500, 550];
    return std.where((s) => s <= raw).lastOrNull ?? 250;
  }
}

// ─── Price Sync ──────────────────────────────────────────────────────────────

/// Handles price database synchronization from remote server.
class PriceSyncService {
  final List<PriceItem> _cache;

  PriceSyncService() : _cache = [];

  /// Initialize with default prices.
  List<PriceItem> getDefaults() {
    final items = <PriceItem>[];
    for (final e in DefaultPrices.plates.entries) {
      items.add(PriceItem(
        sku: 'PLATE_${e.key.hashCode}',
        category: 'plaka',
        name: e.key,
        unit: 'plaka',
        price: e.value,
      ));
    }
    for (final e in DefaultPrices.banding.entries) {
      items.add(PriceItem(
        sku: 'BAND_${e.key.hashCode}',
        category: 'bant',
        name: e.key,
        unit: 'm',
        price: e.value,
      ));
    }
    for (final e in DefaultPrices.hardware.entries) {
      items.add(PriceItem(
        sku: 'HW_${e.key.hashCode}',
        category: _hwCategory(e.key),
        name: e.key,
        unit: e.key.contains('Ray') ? 'cift' : 'adet',
        price: e.value,
      ));
    }
    return items;
  }

  String _hwCategory(String name) {
    if (name.startsWith('Mentese')) return 'mentese';
    if (name.startsWith('Ray')) return 'ray';
    if (name.startsWith('Kulp')) return 'kulp';
    return 'aksesuar';
  }

  /// Check if remote prices are available.
  Future<bool> isRemoteAvailable() async {
    // TODO: Check remote price server
    return false;
  }

  /// Sync prices from remote server.
  Future<void> syncFromRemote() async {
    // TODO: Fetch from remote API, update DB
  }

  /// Get last sync date.
  DateTime? lastSync() {
    if (_cache.isEmpty) return null;
    return _cache.map((p) => p.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }
}
