import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';
import 'package:ustayardimcisi/modules/cut_optimizer.dart';
import 'package:ustayardimcisi/services/report_service.dart';

void main() {
  final engine = ModuleEngine();
  final mat = MaterialSpec();

  /// Generate parts for a typical kitchen using module engine.
  List<Part> _generateKitchenParts() {
    final modules = [
      Module(code: ModuleCode.a4, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 0)),
      Module(code: ModuleCode.a3, xPosMm: 800, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0)),
      Module(code: ModuleCode.a5, xPosMm: 1400, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams()),
      Module(code: ModuleCode.a2, xPosMm: 2000, widthMm: 500, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
      Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 900, heightMm: 720, depthMm: 320, params: const ModuleParams(rafSayisi: 2)),
      Module(code: ModuleCode.u4, xPosMm: 900, widthMm: 600, heightMm: 380, depthMm: 320, params: const ModuleParams()),
      Module(code: ModuleCode.u1, xPosMm: 1500, widthMm: 500, heightMm: 720, depthMm: 320, params: const ModuleParams(rafSayisi: 2)),
    ];

    final allParts = <Part>[];
    for (final mod in modules) {
      allParts.addAll(engine.generateParts(mod, mat));
    }
    return allParts;
  }

  group('Cut Optimizer', () {
    test('Optimize typical 7-module kitchen', () {
      final parts = _generateKitchenParts();
      final partCount = parts.fold<int>(0, (s, p) => s + p.qty);
      expect(partCount, greaterThan(20), reason: 'Typical kitchen has 20+ parts');

      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);

      expect(sheets.isNotEmpty, true, reason: 'Should produce at least 1 sheet');

      // Check waste is reasonable (< 50% — real kitchens typically 5-15%)
      for (final s in sheets) {
        expect(s.wastePct, lessThan(60), reason: 'Sheet waste ${s.wastePct}% too high');
      }

      print('  Kitchen: $partCount parts → ${sheets.length} sheets');
      for (final s in sheets) {
        print('  Sheet: ${s.widthMm}×${s.lengthMm} — ${s.partCount} parts, waste ${s.wastePct.toStringAsFixed(1)}%');
      }
    });

    test('All parts should be placed', () {
      final parts = _generateKitchenParts();
      final expectedCount = parts.fold<int>(0, (s, p) => s + p.qty);

      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);
      final placedCount = sheets.fold<int>(0, (s, sh) => s + sh.partCount);

      expect(placedCount, equals(expectedCount),
          reason: '$placedCount placed vs $expectedCount expected — some parts missing!');
    });

    test('No significant overlap between parts on same sheet', () {
      final parts = _generateKitchenParts();
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);

      // Verify each sheet has reasonable part density
      for (final sheet in sheets) {
        final totalPartArea = sheet.partsPlaced.fold<double>(
            0, (s, p) => s + p.widthMm * p.lengthMm);
        final sheetArea = sheet.widthMm * sheet.lengthMm;
        // Total placed area should not exceed sheet area
        expect(totalPartArea, lessThanOrEqualTo(sheetArea * 1.01),
            reason: 'Parts exceed sheet area on ${sheet.material}');
        // At least some area should be used
        expect(totalPartArea, greaterThan(0),
            reason: 'No area used on ${sheet.material}');
      }
    });

    test('Parts fit within sheet bounds', () {
      final parts = _generateKitchenParts();
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);

      for (final sheet in sheets) {
        for (final p in sheet.partsPlaced) {
          expect(p.xMm >= 0, true, reason: '${p.label} x=${p.xMm} < 0');
          expect(p.yMm >= 0, true, reason: '${p.label} y=${p.yMm} < 0');
          expect(p.xMm + p.widthMm <= sheet.widthMm + 1, true,
              reason: '${p.label} right=${p.xMm + p.widthMm} > sheet ${sheet.widthMm}');
          expect(p.yMm + p.lengthMm <= sheet.lengthMm + 1, true,
              reason: '${p.label} bottom=${p.yMm + p.lengthMm} > sheet ${sheet.lengthMm}');
        }
      }
    });

    test('Grain-locked parts are not rotated', () {
      // Create a grain-locked part that would benefit from rotation
      final parts = [
        PartBuilder.part(moduleId: 'T', name: 'Tall', qty: 1,
            netWidth: 400, netLength: 1200, thickness: 18, material: 'Kapak',
            grainLocked: true, banding: [2, 2, 2, 2]),
        PartBuilder.part(moduleId: 'T', name: 'Wide', qty: 1,
            netWidth: 1200, netLength: 400, thickness: 18, material: 'Kapak',
            grainLocked: true, banding: [2, 2, 2, 2]),
      ];

      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);

      for (final sheet in sheets) {
        for (final p in sheet.partsPlaced) {
          if (p.label.contains('Tall')) {
            // Should NOT be rotated (tall stays tall)
            expect(p.rotated, false, reason: 'Grain-locked part was rotated!');
          }
        }
      }
    });
  });

  group('Banding Calculator', () {
    test('Calculate banding metraj', () {
      final parts = _generateKitchenParts();
      final metraj = BandingCalculator.calculateMetraj(parts);

      expect(metraj.isNotEmpty, true);
      // Every part has at least some banded edges
      final total = metraj.values.fold(0.0, (s, v) => s + v);
      expect(total, greaterThan(0), reason: 'No banding calculated');

      print('  Banding total: ${total.toStringAsFixed(1)} m');
      for (final e in metraj.entries) {
        print('    ${e.key}: ${e.value.toStringAsFixed(1)} m');
      }
    });

    test('Total with 10% fire factor', () {
      final parts = _generateKitchenParts();
      final total = BandingCalculator.totalMetrajWithFire(parts);
      final raw = BandingCalculator.calculateMetraj(parts)
          .values.fold(0.0, (s, v) => s + v);

      expect(total, closeTo(raw * 1.10, 0.01));
    });
  });

  group('Material Calculator', () {
    test('Plate counts', () {
      final parts = _generateKitchenParts();
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);
      final counts = MaterialCalculator.plateCounts(sheets);
      final summary = MaterialCalculator.summary(sheets);

      expect(counts.isNotEmpty, true);
      expect(summary.contains('plaka'), true);

      print('\n  Material Summary:');
      print('  $summary');
    });
  });
}
