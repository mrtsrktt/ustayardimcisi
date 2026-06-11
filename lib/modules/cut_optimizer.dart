/// 2D Guillotine Cut Optimizer — First-Fit Decreasing + strip placement.
///
/// Implements the algorithm described in TEKNIK_RAPOR.md §5.
/// - Plates sorted by area (largest first)
/// - Strips placed top-to-bottom
/// - Parts placed left-to-right within strips
/// - Guillotine constraint (cuts go edge-to-edge)
/// - Kerf (testere payı) applied between parts
/// - Grain direction lock (damar yönü kilidi)
///
/// Target: 300 parts < 2 sec, waste ≤ 12% for typical kitchen.

import 'dart:math';
import '../models/project.dart';

// ─── Cut Optimizer ───────────────────────────────────────────────────────────

class CutOptimizer {
  final CutConfig config;

  const CutOptimizer({this.config = const CutConfig()});

  /// Optimize a part list into sheet layouts.
  /// Groups parts by material+thickness, then packs each group.
  List<SheetLayout> optimize(List<Part> parts, {String? labelPrefix}) {
    // Group parts by material + thickness
    final groups = <String, List<Part>>{};
    for (final p in parts) {
      final key = '${p.material}_${p.thicknessMm.toInt()}mm';
      groups.putIfAbsent(key, () => []).add(p);
    }

    final allSheets = <SheetLayout>[];

    for (final entry in groups.entries) {
      final groupParts = entry.value;
      // Use material-specific plate size based on role
      final role = groupParts.first.role;
      final plateSize = config.getSizeFor(role);
      final sheets = _packGroup(groupParts, plateSize.widthMm, plateSize.lengthMm);
      allSheets.addAll(sheets);
    }

    return allSheets;
  }

  /// Pack a group of same-material same-thickness parts.
  List<SheetLayout> _packGroup(List<Part> parts, double plateW, double plateL) {
    // Expand parts by qty into individual items
    final items = <_CutItem>[];
    for (final p in parts) {
      for (var i = 0; i < p.qty; i++) {
        items.add(_CutItem(
          label: p.label ?? '?',
          netWidth: p.cutWidthMm,
          netLength: p.cutLengthMm,
          grainLocked: p.grainLocked,
          material: p.material,
        ));
      }
    }

    // Sort by area descending (FFD)
    items.sort((a, b) => (b.netWidth * b.netLength).compareTo(a.netWidth * a.netLength));

    final sheets = <SheetLayout>[];
    final placedIds = <int>{};

    while (placedIds.length < items.length) {
      // Filter out already placed items
      final unplaced = items.where((it) => !placedIds.contains(it._id)).toList();
      if (unplaced.isEmpty) break;

      final (sheet, placed) = _packSheet(unplaced, plateW, plateL);
      if (placed.isEmpty) break; // safety: part too big for sheet
      sheets.add(sheet);
      placedIds.addAll(placed.map((p) => p._id));
    }

    return sheets;
  }

  /// Pack parts into a single sheet using shelf-based placement.
  /// Parts are sorted by length descending; shelves are created matching
  /// the tallest part in that shelf. Parts fill each shelf left-to-right.
  (SheetLayout, List<_PlacedItem>) _packSheet(List<_CutItem> items, double plateW, double plateL) {
    final usableW = plateW - 2 * config.trimMm;
    final usableL = plateL - 2 * config.trimMm;

    // Sort by length descending for shelf packing
    final sorted = List<_CutItem>.from(items)
      ..sort((a, b) => b.netLength.compareTo(a.netLength));

    final placed = <_PlacedItem>[];
    final shelves = <_Shelf>[];

    for (final item in sorted) {
      bool placed_ = false;

      // Try to fit in existing shelves first (left-to-right)
      for (final shelf in shelves) {
        if (item.netLength > shelf.height) continue;

        // Rightmost X in this shelf
        double rightmostX = config.trimMm;
        for (final p in shelf.placed) {
          final r = p.xMm + p.widthMm + config.kerfMm;
          if (r > rightmostX) rightmostX = r;
        }

        final remainingW = plateW - config.trimMm - rightmostX;

        // Normal orientation
        if (item.netWidth <= remainingW) {
          shelf.placed.add(_PlacedItem(
            label: item.label, xMm: rightmostX, yMm: shelf.yMm,
            widthMm: item.netWidth, lengthMm: item.netLength,
            rotated: false, id: item._id, material: item.material,
          ));
          placed.add(shelf.placed.last);
          placed_ = true;
          break;
        }

        // Rotated: netWidth becomes Y/length, must fit shelf height
        if (!item.grainLocked && item.netLength <= remainingW && item.netWidth <= shelf.height) {
          shelf.placed.add(_PlacedItem(
            label: item.label, xMm: rightmostX, yMm: shelf.yMm,
            widthMm: item.netLength, lengthMm: item.netWidth,
            rotated: true, id: item._id, material: item.material,
          ));
          placed.add(shelf.placed.last);
          placed_ = true;
          break;
        }
      }

      if (placed_) continue;

      // Start new shelf
      final lastShelfBottom = shelves.isEmpty
          ? config.trimMm
          : shelves.last.yMm + shelves.last.height + config.kerfMm;

      if (lastShelfBottom + item.netLength + config.trimMm <= plateL) {
        final shelf = _Shelf(yMm: lastShelfBottom, height: item.netLength);
        shelf.placed.add(_PlacedItem(
          label: item.label, xMm: config.trimMm, yMm: lastShelfBottom,
          widthMm: item.netWidth, lengthMm: item.netLength,
          rotated: false, id: item._id, material: item.material,
        ));
        placed.add(shelf.placed.last);
        shelves.add(shelf);
      }
      // else: part doesn't fit on this sheet at all → skip (will go to next sheet)
    }

    // Validate: remove parts that exceed plate or overlap
    final valid = <_PlacedItem>[];
    for (final p in placed) {
      if (p.xMm < 0 || p.yMm < 0 ||
          p.xMm + p.widthMm > plateW + 0.5 ||
          p.yMm + p.lengthMm > plateL + 0.5) {
        continue; // skip out-of-bounds part
      }
      bool hasOverlap = false;
      for (final existing in valid) {
        if (p.xMm < existing.xMm + existing.widthMm &&
            p.xMm + p.widthMm > existing.xMm &&
            p.yMm < existing.yMm + existing.lengthMm &&
            p.yMm + p.lengthMm > existing.yMm) {
          hasOverlap = true;
          break;
        }
      }
      if (!hasOverlap) valid.add(p);
    }
    placed
      ..clear()
      ..addAll(valid);

    // Calculate waste
    final totalArea = plateW * plateL;
    double usedArea = 0;
    for (final p in placed) {
      usedArea += p.widthMm * p.lengthMm;
    }
    final wastePct = ((totalArea - usedArea) / totalArea * 100);

    return (
      SheetLayout(
        material: placed.isNotEmpty ? placed.first.material : '?',
        widthMm: plateW, lengthMm: plateL,
        partsPlaced: placed.map((p) => PlacedPartData(
          label: p.label, xMm: p.xMm, yMm: p.yMm,
          widthMm: p.widthMm, lengthMm: p.lengthMm, rotated: p.rotated,
        )).toList(),
        wastePct: wastePct,
      ),
      placed,
    );
  }
}

// ─── Configuration ───────────────────────────────────────────────────────────

class PlateSize {
  final double widthMm;
  final double lengthMm;

  const PlateSize({required this.widthMm, required this.lengthMm});

  static const std2100x2800 = PlateSize(widthMm: 2100, lengthMm: 2800);
  static const std1830x3660 = PlateSize(widthMm: 1830, lengthMm: 3660);
  static const std1220x2800 = PlateSize(widthMm: 1220, lengthMm: 2800);
}

class CutConfig {
  final double plateWidthMm;     // default plate width (fallback)
  final double plateLengthMm;    // default plate length (fallback)
  final double kerfMm;           // testere payı (blade width)
  final double trimMm;           // edge trim allowance
  final bool lockGrain;          // lock grain direction globally
  final double minStripMm;       // minimum strip width
  final Map<String, PlateSize> materialSizes; // malzeme rolü -> ebat

  const CutConfig({
    this.plateWidthMm = 2100,
    this.plateLengthMm = 2800,
    this.kerfMm = 4.8,
    this.trimMm = 10,
    this.lockGrain = false,
    this.minStripMm = 50,
    this.materialSizes = const {},
  });

  /// Get plate size for a material role.
  PlateSize getSizeFor(String role) {
    return materialSizes[role] ?? PlateSize(widthMm: plateWidthMm, lengthMm: plateLengthMm);
  }

  /// Create from app settings.
  factory CutConfig.fromSettings(Map<String, String> settings) {
    return CutConfig(
      plateWidthMm: double.tryParse(settings['plate_width_mm'] ?? '') ?? 2100,
      plateLengthMm: double.tryParse(settings['plate_length_mm'] ?? '') ?? 2800,
      kerfMm: double.tryParse(settings['kerf_mm'] ?? '') ?? 4.8,
      trimMm: double.tryParse(settings['trim_mm'] ?? '') ?? 10,
      minStripMm: double.tryParse(settings['min_serit_mm'] ?? '') ?? 50,
    );
  }
}

// ─── Result Types ────────────────────────────────────────────────────────────

class SheetLayout {
  final String material;
  final double widthMm;
  final double lengthMm;
  final List<PlacedPartData> partsPlaced;
  final double wastePct;

  const SheetLayout({
    required this.material,
    required this.widthMm,
    required this.lengthMm,
    this.partsPlaced = const [],
    this.wastePct = 0,
  });

  int get partCount => partsPlaced.length;

  double get usedAreaMm2 =>
      partsPlaced.fold(0, (s, p) => s + p.widthMm * p.lengthMm);
}

class PlacedPartData {
  final String label;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double lengthMm;
  final bool rotated;

  const PlacedPartData({
    required this.label,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.lengthMm,
    this.rotated = false,
  });
}

// ─── Internal ────────────────────────────────────────────────────────────────

int _idCounter = 0;

class _CutItem {
  final String label;
  final double netWidth;
  final double netLength;
  final bool grainLocked;
  final String material;
  final int _id;

  _CutItem({
    required this.label,
    required this.netWidth,
    required this.netLength,
    this.grainLocked = false,
    required this.material,
  }) : _id = _idCounter++;
}

class _Shelf {
  final double yMm;
  final double height;
  final List<_PlacedItem> placed;

  _Shelf({required this.yMm, required this.height}) : placed = [];
}

class _PlacedItem {
  final String label;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double lengthMm;
  final bool rotated;
  final int _id;
  final String material;

  _PlacedItem({
    required this.label,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.lengthMm,
    this.rotated = false,
    required int id,
    required this.material,
  }) : _id = id;
}

// ─── Optimization Summary ────────────────────────────────────────────────────

class CutSummary {
  final List<SheetLayout> sheets;
  final int totalParts;
  final double totalWastePct;
  final int totalSheets;

  CutSummary({required this.sheets})
      : totalParts = sheets.fold(0, (s, sh) => s + sh.partCount),
        totalSheets = sheets.length,
        totalWastePct = sheets.isEmpty
            ? 0
            : sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / sheets.length;

  /// Check if waste meets target (≤12% per CLAUDE.md).
  bool get wasteOk => totalWastePct <= 12.0;
}
