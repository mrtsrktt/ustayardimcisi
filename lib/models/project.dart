/// Core data models for MarangozAI — the single source of truth.
///
/// All measurements internally in **mm**, displayed in **cm** in UI.
/// Currency in TL, VAT as separate line item.

import 'dart:convert';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum ProjectStatus { draft, designed, approved, cutReady, quoted }

enum ModuleCode {
  a1, a2, a3, a4, a5, a6, a7,
  u1, u2, u3, u4, u5,
  b1, b2,
}

enum ArkalikTip { cakma, kanal }

enum PanelSize { p2100x2800, p1830x3660 }

enum MalzemeTip { mdf, mdflam, suntalam, highGloss, membran, akrilik }

// ─── Project ─────────────────────────────────────────────────────────────────

class Project {
  final int? id;
  final int customerId;
  final ProjectStatus status;
  final List<String> photos;        // file paths
  final String? sketchPath;         // hand-drawn sketch image
  final String? measurementsJson;   // raw AI output JSON
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    this.id,
    required this.customerId,
    this.status = ProjectStatus.draft,
    this.photos = const [],
    this.sketchPath,
    this.measurementsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Project copyWith({
    int? id,
    int? customerId,
    ProjectStatus? status,
    List<String>? photos,
    String? sketchPath,
    String? measurementsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Project(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        status: status ?? this.status,
        photos: photos ?? this.photos,
        sketchPath: sketchPath ?? this.sketchPath,
        measurementsJson: measurementsJson ?? this.measurementsJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'status': status.name,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

// ─── Customer ────────────────────────────────────────────────────────────────

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ─── Wall & Measurements ─────────────────────────────────────────────────────

class Measurement {
  final int? id;
  final int projectId;
  final List<WallSegment> walls;
  final List<Opening> openings;
  final double? ceilingHeightMm;
  final Map<String, double> confidence; // field → 0.0–1.0
  final bool approved;

  const Measurement({
    this.id,
    required this.projectId,
    this.walls = const [],
    this.openings = const [],
    this.ceilingHeightMm,
    this.confidence = const {},
    this.approved = false,
  });
}

class WallSegment {
  final String label;        // e.g. "A", "B", "C"
  final double lengthMm;

  const WallSegment({required this.label, required this.lengthMm});
}

class Opening {
  final OpeningType type;
  final String wallLabel;    // which wall
  final double fromLeftMm;
  final double widthMm;
  final double heightMm;
  final double? sillMm;      // window sill height from floor

  const Opening({
    required this.type,
    required this.wallLabel,
    required this.fromLeftMm,
    required this.widthMm,
    required this.heightMm,
    this.sillMm,
  });
}

enum OpeningType { window, door, column }

// ─── Cabinet Plan ────────────────────────────────────────────────────────────

class CabinetPlan {
  final int? id;
  final int projectId;
  final int version;
  final List<WallSegment> wallSegments;
  final List<Module> modules;
  final DateTime createdAt;

  CabinetPlan({
    this.id,
    required this.projectId,
    this.version = 1,
    this.wallSegments = const [],
    this.modules = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ─── Module ──────────────────────────────────────────────────────────────────

class Module {
  final ModuleCode code;
  final double xPosMm;          // position along wall
  final double widthMm;
  final double heightMm;
  final double depthMm;
  final ModuleParams params;

  const Module({
    required this.code,
    required this.xPosMm,
    required this.widthMm,
    required this.heightMm,
    required this.depthMm,
    this.params = const ModuleParams(),
  });
}

class ModuleParams {
  final int rafSayisi;
  final int cekmeceSayisi;
  final bool camli;
  final bool ortaDikme;
  final bool ilkKucuk;         // A3: first drawer smaller
  final bool gorunurYan;       // visible side = door material
  final bool bazaDevam;        // A6: plinth continues under dishwasher gap
  final bool sabitRaf;         // A5: fixed panel vs drawer above oven

  const ModuleParams({
    this.rafSayisi = 1,
    this.cekmeceSayisi = 0,
    this.camli = false,
    this.ortaDikme = false,
    this.ilkKucuk = false,
    this.gorunurYan = false,
    this.bazaDevam = true,
    this.sabitRaf = false,
  });
}

// ─── Material Spec ───────────────────────────────────────────────────────────

class MaterialSpec {
  final MalzemeTip bodyMaterial;
  final String bodyColor;       // RAL code or texture name
  final MalzemeTip doorMaterial;
  final String doorColor;
  final EdgeBandSpec edgeBand;
  final PanelSize panelSize;
  final double thicknessMm;         // govde/kapak kalinligi (default 18)
  final double arkalikThicknessMm;  // arkalik kalinligi (3 veya 8)

  const MaterialSpec({
    this.bodyMaterial = MalzemeTip.mdflam,
    this.bodyColor = 'Beyaz',
    this.doorMaterial = MalzemeTip.mdflam,
    this.doorColor = 'Beyaz',
    this.edgeBand = const EdgeBandSpec(),
    this.panelSize = PanelSize.p2100x2800,
    this.thicknessMm = 18,
    this.arkalikThicknessMm = 8,
  });
}

class EdgeBandSpec {
  final double thicknessMm;     // 0.4 / 1 / 2
  final String color;           // matches body or door

  const EdgeBandSpec({this.thicknessMm = 1, this.color = ''});
}

// ─── Part ────────────────────────────────────────────────────────────────────

class Part {
  final String moduleId;        // e.g. "A2"
  final String name;            // "Yan", "Kapak", etc.
  final int qty;
  final double netWidthMm;
  final double netLengthMm;
  final double thicknessMm;
  final String material;        // Tam malzeme adi: "MDFlam 18mm Beyaz"
  final String role;            // "govde" | "kapak" | "arkalik" — maliyet eslestirme icin
  final List<double> banding;   // [Ön, Arka, Sol, Sağ] band thicknesses
  final bool grainLocked;
  final String? label;          // unique label e.g. "P-A2.3-07"

  const Part({
    required this.moduleId,
    required this.name,
    required this.qty,
    required this.netWidthMm,
    required this.netLengthMm,
    required this.thicknessMm,
    required this.material,
    this.role = 'govde',
    this.banding = const [0, 0, 0, 0],
    this.grainLocked = false,
    this.label,
  });

  /// Band-deducted cut dimensions per MODUL_FORMULLERI.md §0.2
  double get cutWidthMm => netWidthMm - (banding[2] + banding[3]);
  double get cutLengthMm => netLengthMm - (banding[0] + banding[1]);

  /// Total banding length for this part (sum of banded edge lengths)
  double get totalBandingMm {
    double total = 0;
    if (banding[0] > 0) total += netWidthMm;   // ön
    if (banding[1] > 0) total += netWidthMm;   // arka
    if (banding[2] > 0) total += netLengthMm;  // sol
    if (banding[3] > 0) total += netLengthMm;  // sağ
    return total;
  }
}

// ─── Cut Layout ──────────────────────────────────────────────────────────────

class CutLayout {
  final List<CutSheet> sheets;
  final double totalWastePct;

  const CutLayout({this.sheets = const [], this.totalWastePct = 0});
}

class CutSheet {
  final String material;
  final double widthMm;
  final double lengthMm;
  final List<PlacedPart> partsPlaced;
  final double wastePct;

  const CutSheet({
    required this.material,
    required this.widthMm,
    required this.lengthMm,
    this.partsPlaced = const [],
    this.wastePct = 0,
  });
}

class PlacedPart {
  final String label;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double lengthMm;
  final bool rotated;

  const PlacedPart({
    required this.label,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.lengthMm,
    this.rotated = false,
  });
}

// ─── Cost Report ─────────────────────────────────────────────────────────────

class CostReport {
  final List<CostLine> lines;
  final double subtotal;
  final double marginPct;
  final double customerPrice;
  final double vat;             // KDV

  const CostReport({
    this.lines = const [],
    this.subtotal = 0,
    this.marginPct = 0,
    this.customerPrice = 0,
    this.vat = 0,
  });

  double get total => subtotal + vat;
}

class CostLine {
  final String item;
  final double qty;
  final String unit;            // adet, m, mtül, m², plaka
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

// ─── Price DB Entry ──────────────────────────────────────────────────────────

class PriceEntry {
  final String sku;
  final String category;        // plaka, bant, mentese, ray, kulp, tezgah, cam, aksesuar
  final String name;
  final String unit;
  final double price;
  final DateTime updatedAt;

  PriceEntry({
    required this.sku,
    required this.category,
    required this.name,
    required this.unit,
    required this.price,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

// ─── Settings ────────────────────────────────────────────────────────────────

class AppSettings {
  final double kerfMm;          // testere payı (default 4.8)
  final double trimMm;          // traş payı
  final double plateWidthMm;    // varsayılan plaka eni
  final double plateLengthMm;   // varsayılan plaka boyu
  final ArkalikTip arkalikTip;
  final double minSeritMm;      // minimum şerit genişliği
  final bool useDeduction;      // bant düşümü uygula (≥1mm bant için zorunlu)
  final int maxPartCount;       // optimizasyon parça limiti

  const AppSettings({
    this.kerfMm = 4.8,
    this.trimMm = 10,
    this.plateWidthMm = 2100,
    this.plateLengthMm = 2800,
    this.arkalikTip = ArkalikTip.cakma,
    this.minSeritMm = 50,
    this.useDeduction = true,
    this.maxPartCount = 300,
  });

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      kerfMm: double.tryParse(map['kerf_mm'] ?? '') ?? 4.8,
      trimMm: double.tryParse(map['trim_mm'] ?? '') ?? 10,
      plateWidthMm: double.tryParse(map['plate_width_mm'] ?? '') ?? 2100,
      plateLengthMm: double.tryParse(map['plate_length_mm'] ?? '') ?? 2800,
      arkalikTip: map['arkalik_tip'] == 'kanal' ? ArkalikTip.kanal : ArkalikTip.cakma,
      minSeritMm: double.tryParse(map['min_serit_mm'] ?? '') ?? 50,
      useDeduction: map['use_band_deduction'] != 'false',
      maxPartCount: int.tryParse(map['max_part_count'] ?? '') ?? 300,
    );
  }
}
