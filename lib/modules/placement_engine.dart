/// Auto-placement engine — wall length → module layout.
///
/// Takes wall measurements and user preferences (sink, cooktop, fridge positions)
/// and generates an optimal module sequence for lower and upper cabinet runs.

import '../models/project.dart';

// ─── Standard width library (mm) ─────────────────────────────────────────────

/// Standard module widths in mm (TR practice, CLAUDE.md §4.1).
/// Sorted by width for best-fit algorithm.
const _stdAltGenislikler = [300, 400, 450, 500, 600, 800, 900, 1000, 1200];
const _stdUstGenislikler = [300, 400, 450, 500, 600, 800, 900, 1000];

/// Fixed widths for specific modules.
const _evyeMin = 600;       // A4 min width
const _evyeMax = 1000;
const _firinG = 600;        // A5 fixed
const _bulasikG = [450, 600]; // A6 options
const _buzdolabiMin = 700;
const _buzdolabiMax = 900;
const _davlumbazG = 600;    // U4 fixed
const _koseMin = 900;       // A7/U5 min

// ─── Placement Input ─────────────────────────────────────────────────────────

class PlacementInput {
  final double wallLengthMm;
  final bool isLower;               // true = alt dolap, false = üst dolap
  final WallAnchors anchors;

  const PlacementInput({
    required this.wallLengthMm,
    required this.isLower,
    this.anchors = const WallAnchors(),
  });
}

/// User-marked positions for mandatory appliances.
/// Positions are in mm from left edge of the wall.
class WallAnchors {
  final double? sinkCenterMm;       // evye center
  final double? cooktopCenterMm;    // ocak center (implies A5 + davlumbaz above)
  final double? fridgeCenterMm;     // buzdolabı center
  final double? dishwasherCenterMm; // bulaşık mak. center

  const WallAnchors({
    this.sinkCenterMm,
    this.cooktopCenterMm,
    this.fridgeCenterMm,
    this.dishwasherCenterMm,
  });

  bool get hasSink => sinkCenterMm != null;
  bool get hasCooktop => cooktopCenterMm != null;
  bool get hasFridge => fridgeCenterMm != null;
  bool get hasDishwasher => dishwasherCenterMm != null;
}

// ─── Placement Result ────────────────────────────────────────────────────────

class PlacementResult {
  final List<PlacedModule> modules;
  final List<String> warnings;
  final double totalWidthMm;
  final double fillerMm;            // remaining gap needing filler strip

  const PlacementResult({
    this.modules = const [],
    this.warnings = const [],
    this.totalWidthMm = 0,
    this.fillerMm = 0,
  });

  bool get needsFiller => fillerMm >= 10;
}

class PlacedModule {
  final ModuleCode code;
  final double widthMm;
  final double xPosMm;              // position from left edge
  final bool isMandatory;
  final String? label;              // e.g. "Evye", "Ocak"

  const PlacedModule({
    required this.code,
    required this.widthMm,
    required this.xPosMm,
    this.isMandatory = false,
    this.label,
  });

  Module toModule(double heightMm, double depthMm, {ModuleParams params = const ModuleParams()}) {
    return Module(
      code: code,
      xPosMm: xPosMm,
      widthMm: widthMm,
      heightMm: heightMm,
      depthMm: depthMm,
      params: params,
    );
  }
}

// ─── Placement Engine ────────────────────────────────────────────────────────

class PlacementEngine {
  /// Generate lower cabinet placement for a wall.
  static PlacementResult placeLower(PlacementInput input) {
    final warnings = <String>[];
    double kalan = input.wallLengthMm;
    double x = 0;
    final modules = <PlacedModule>[];
    final anchors = input.anchors;

    // Priority order for mandatory modules:
    // 1. Buzdolabı (usually at one end, takes B2)
    // 2. Evye (A4, centered on sink position)
    // 3. Fırın/ocak (A5, centered on cooktop position)
    // 4. Bulaşık mak. (A6)

    // Determine which mandatory modules exist and sort by position
    final mandatories = <_Mandatory>[];
    if (anchors.hasFridge) {
      mandatories.add(_Mandatory('buzdolabi', ModuleCode.b2,
          _buzdolabiMin, _buzdolabiMax, anchors.fridgeCenterMm!));
    }
    if (anchors.hasSink) {
      mandatories.add(_Mandatory('evye', ModuleCode.a4,
          _evyeMin, _evyeMax, anchors.sinkCenterMm!));
    }
    if (anchors.hasCooktop) {
      mandatories.add(_Mandatory('firin', ModuleCode.a5,
          _firinG, _firinG, anchors.cooktopCenterMm!));
    }
    if (anchors.hasDishwasher) {
      mandatories.add(_Mandatory('bulasik', ModuleCode.a6,
          _bulasikG.first, _bulasikG.last, anchors.dishwasherCenterMm!));
    }

    // Sort mandatories by position (left to right)
    mandatories.sort((a, b) => a.centerMm.compareTo(b.centerMm));

    // Check for overlaps and adjust
    for (var i = 0; i < mandatories.length; i++) {
      final m = mandatories[i];
      final w = _pickWidth(m.minW, m.maxW, kalan);

      // Calculate position: try to center on anchor, but respect left boundary
      double idealX = m.centerMm - w / 2;
      if (idealX < x) idealX = x; // can't place before previous module
      if (idealX + w > input.wallLengthMm) {
        idealX = input.wallLengthMm - w;
        if (idealX < x) {
          warnings.add('${m.label} sığmadı, atlandı');
          continue;
        }
      }

      modules.add(PlacedModule(
        code: m.code,
        widthMm: w.toDouble(),
        xPosMm: idealX,
        isMandatory: true,
        label: m.label,
      ));

      x = idealX + w;
      kalan = input.wallLengthMm - x;
    }

    // Fill remaining gaps with standard modules
    _fillGaps(modules, kalan, input.wallLengthMm, true, warnings);

    // Calculate filler
    final totalWidth = modules.fold<double>(0, (s, m) => s + m.widthMm);
    final fillerMm = input.wallLengthMm - totalWidth;

    return PlacementResult(
      modules: modules,
      warnings: warnings,
      totalWidthMm: totalWidth,
      fillerMm: fillerMm,
    );
  }

  /// Generate upper cabinet placement.
  static PlacementResult placeUpper(PlacementInput input) {
    final warnings = <String>[];
    final modules = <PlacedModule>[];
    final anchors = input.anchors;

    // Davlumbaz (U4) goes above cooktop
    double x = 0;
    if (anchors.hasCooktop) {
      final center = anchors.cooktopCenterMm!;
      final w = _davlumbazG.toDouble();
      double idealX = center - w / 2;
      if (idealX < 0) idealX = 0;

      modules.add(PlacedModule(
        code: ModuleCode.u4,
        widthMm: w,
        xPosMm: idealX,
        isMandatory: true,
        label: 'Davlumbaz',
      ));
      x = idealX + w;
    }

    final kalan = input.wallLengthMm - x;
    _fillGaps(modules, kalan, input.wallLengthMm, false, warnings);

    final totalWidth = modules.fold<double>(0, (s, m) => s + m.widthMm);
    final fillerMm = input.wallLengthMm - totalWidth;

    return PlacementResult(
      modules: modules,
      warnings: warnings,
      totalWidthMm: totalWidth,
      fillerMm: fillerMm,
    );
  }

  /// Fill remaining wall space with standard modules.
  static void _fillGaps(
    List<PlacedModule> modules,
    double kalan,
    double wallLength,
    bool isLower,
    List<String> warnings,
  ) {
    if (kalan <= 20) return; // too small for any module

    final widths = isLower ? _stdAltGenislikler : _stdUstGenislikler;
    double remaining = kalan;

    // Find rightmost x position
    double x = 0;
    if (modules.isNotEmpty) {
      x = modules.map((m) => m.xPosMm + m.widthMm).reduce((a, b) => a > b ? a : b);
    }

    // Find leftmost x (modules may start at x > 0)
    double leftX = 0;
    if (modules.isNotEmpty) {
      leftX = modules.map((m) => m.xPosMm).reduce((a, b) => a < b ? a : b);
    }

    // Fill gap on the RIGHT side of the rightmost module
    _fillSide(modules, x, wallLength, widths, isLower);

    // Fill gap on the LEFT side of the leftmost module
    if (leftX > 20) {
      // Modules starting after left wall edge → fill left gap
      final leftModules = <PlacedModule>[];
      _fillSide(leftModules, 0, leftX, widths, isLower);
      // Shift leftModules to start at x=0
      for (final lm in leftModules) {
        modules.add(PlacedModule(
          code: lm.code, widthMm: lm.widthMm, xPosMm: lm.xPosMm,
        ));
      }
    }

    // Re-sort by x position
    modules.sort((a, b) => a.xPosMm.compareTo(b.xPosMm));

    // Fill any remaining gaps between modules
    final result = <PlacedModule>[];
    double expectedX = 0;
    for (final m in modules) {
      if (m.xPosMm > expectedX + 10) {
        // Gap before this module — fill it
        final gapModules = <PlacedModule>[];
        _fillSide(gapModules, expectedX, m.xPosMm, widths, isLower);
        result.addAll(gapModules);
      }
      result.add(m);
      expectedX = m.xPosMm + m.widthMm;
    }

    modules
      ..clear()
      ..addAll(result);
  }

  /// Fill a continuous space from [startX] to [endX] with modules.
  static void _fillSide(
    List<PlacedModule> modules,
    double startX,
    double endX,
    List<int> widths,
    bool isLower,
  ) {
    double kalan = endX - startX;
    if (kalan < widths.first.toDouble()) return;

    double x = startX;

    while (kalan >= widths.first) {
      // Find largest width that fits
      int? chosen;
      for (final w in widths.reversed) {
        if (w <= kalan) {
          chosen = w;
          break;
        }
      }
      if (chosen == null) break;

      // Pick module type based on size
      final code = _pickModuleCode(chosen, isLower);
      final params = _defaultParams(code);

      modules.add(PlacedModule(
        code: code,
        widthMm: chosen.toDouble(),
        xPosMm: x,
      ));

      x += chosen;
      kalan -= chosen;
    }
  }

  /// Pick the best module code for a given width.
  static ModuleCode _pickModuleCode(int widthMm, bool isLower) {
    if (isLower) {
      if (widthMm <= 600) return ModuleCode.a1; // tek kapak
      return ModuleCode.a2;                       // çift kapak
    } else {
      if (widthMm <= 600) return ModuleCode.u1;
      return ModuleCode.u2;
    }
  }

  /// Default params for a module code.
  static ModuleParams _defaultParams(ModuleCode code) {
    return switch (code) {
      ModuleCode.a1 || ModuleCode.a2 => const ModuleParams(rafSayisi: 1),
      ModuleCode.a3 => const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0),
      ModuleCode.a4 => const ModuleParams(rafSayisi: 0),
      ModuleCode.a5 => const ModuleParams(),
      ModuleCode.a6 => const ModuleParams(gorunurYan: true),
      ModuleCode.a7 => const ModuleParams(),
      ModuleCode.u1 || ModuleCode.u2 => const ModuleParams(rafSayisi: 2),
      ModuleCode.u3 => const ModuleParams(camli: true, rafSayisi: 1),
      ModuleCode.u4 => const ModuleParams(),
      ModuleCode.u5 => const ModuleParams(),
      ModuleCode.b1 => const ModuleParams(),
      ModuleCode.b2 => const ModuleParams(gorunurYan: true),
    };
  }

  /// Pick optimal width between min and max.
  static int _pickWidth(int minW, int maxW, double available) {
    if (maxW <= available) return maxW;
    if (minW <= available) {
      // Pick a standard width close to available
      for (final w in _stdAltGenislikler.reversed) {
        if (w >= minW && w <= available) return w;
      }
      return available.round();
    }
    return minW; // will trigger warning upstream
  }

  // ─── Kitchen Layout Generator ──────────────────────────────────────────

  /// Generate a complete kitchen layout given walls and anchors.
  /// Returns a map of wall label → list of placed modules (both lower and upper).
  static Map<String, List<PlacedModule>> generateKitchen({
    required Map<String, double> walls,        // wall label → length mm
    required Map<String, WallAnchors> anchors, // wall label → anchors
    required bool hasUpper,                    // üst dolap var mı?
    double altY = 740,
    double altD = 560,
    double ustY = 720,
    double ustD = 320,
  }) {
    final result = <String, List<PlacedModule>>{};

    for (final entry in walls.entries) {
      final wallLabel = entry.key;
      final wallMm = entry.value;
      final wallAnchors = anchors[wallLabel] ?? const WallAnchors();

      final lowerResult = placeLower(PlacementInput(
        wallLengthMm: wallMm,
        isLower: true,
        anchors: wallAnchors,
      ));

      result['$wallLabel-alt'] = lowerResult.modules;

      if (hasUpper) {
        final upperResult = placeUpper(PlacementInput(
          wallLengthMm: wallMm,
          isLower: false,
          anchors: wallAnchors,
        ));
        result['$wallLabel-ust'] = upperResult.modules;
      }
    }

    return result;
  }
}

// ─── Internal ────────────────────────────────────────────────────────────────

class _Mandatory {
  final String label;
  final ModuleCode code;
  final int minW;
  final int maxW;
  final double centerMm;

  _Mandatory(this.label, this.code, this.minW, this.maxW, this.centerMm);
}
