import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';
import 'package:ustayardimcisi/modules/cut_optimizer.dart';
import 'package:ustayardimcisi/services/cost_service.dart';
import 'package:ustayardimcisi/services/report_service.dart';

void main() {
  final engine = ModuleEngine();
  final mat = MaterialSpec();

  List<Part> _generateParts() {
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

  group('Cost Calculator', () {
    test('Calculate cost for 7-module kitchen', () {
      final parts = _generateParts();
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);

      // Collect hardware from modules
      final hw = <String, int>{};
      final modules = [
        Module(code: ModuleCode.a4, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560),
        Module(code: ModuleCode.a3, xPosMm: 800, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 3)),
        Module(code: ModuleCode.a5, xPosMm: 1400, widthMm: 600, heightMm: 740, depthMm: 560),
        Module(code: ModuleCode.a2, xPosMm: 2000, widthMm: 500, heightMm: 740, depthMm: 560),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 900, heightMm: 720, depthMm: 320),
        Module(code: ModuleCode.u4, xPosMm: 900, widthMm: 600, heightMm: 380, depthMm: 320),
        Module(code: ModuleCode.u1, xPosMm: 1500, widthMm: 500, heightMm: 720, depthMm: 320),
      ];
      for (final mod in modules) {
        final mhw = engine.generateHardware(mod);
        for (final e in mhw.entries) {
          hw[e.key] = (hw[e.key] ?? 0) + e.value;
        }
      }

      final calc = CostCalculator();
      final report = calc.calculate(
        allParts: parts,
        sheets: sheets,
        hardware: hw,
        bodyMaterial: 'MDFlam',
        bodyColor: 'Beyaz',
        doorMaterial: 'High Gloss',
        doorColor: 'Beyaz',
        edgeBandThickness: 2,
        countertopType: 'Tezgah laminant',
        countertopLengthMtul: 2.5,
      );

      expect(report.lines.isNotEmpty, true);
      expect(report.subtotal, greaterThan(0));
      expect(report.vat, greaterThan(0));
      expect(report.total, greaterThan(report.subtotal));
      expect(report.customerPrice, greaterThan(report.subtotal));

      // With 25% margin, customer price should be roughly subtotal * 1.25
      expect(report.customerPrice, closeTo(report.subtotal * 1.25, report.subtotal * 0.05));

      print('\n  Cost Report:');
      for (final l in report.lines) {
        print('    ${l.item}: ${l.qty} ${l.unit} × ${l.unitPrice} TL = ${l.total.toStringAsFixed(0)} TL');
      }
      print('  Subtotal: ${report.subtotal.toStringAsFixed(0)} TL');
      print('  VAT (20%): ${report.vat.toStringAsFixed(0)} TL');
      print('  Customer Price (25% margin): ${report.customerPrice.toStringAsFixed(0)} TL');
      print('  Total (incl. VAT): ${report.total.toStringAsFixed(0)} TL');
    });

    test('Cost report with margin', () {
      final parts = _generateParts();
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);
      final hw = <String, int>{'Mentese': 10, 'Kulp': 8, 'Ray (cift)': 3, 'Aski': 6};

      final calc = CostCalculator();
      final report = calc.calculate(
        allParts: parts, sheets: sheets, hardware: hw,
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz',
        doorMaterial: 'Membran', doorColor: 'Krem',
        countertopType: 'Tezgah kompakt',
        countertopLengthMtul: 3.0,
      );

      final withMargin = report.withMargin(30); // 30% margin
      expect(withMargin.marginPct, 30);
      expect(withMargin.customerPrice, closeTo(report.subtotal * 1.30, report.subtotal * 0.05));
    });

    test('Default prices exist for all categories', () {
      expect(DefaultPrices.plates.isNotEmpty, true);
      expect(DefaultPrices.banding.isNotEmpty, true);
      expect(DefaultPrices.hardware.isNotEmpty, true);
      expect(DefaultPrices.countertops.isNotEmpty, true);
    });

    test('Banding price lookup', () {
      expect(DefaultPrices.getBandingPrice(0.4), DefaultPrices.banding['0.4mm PVC']);
      expect(DefaultPrices.getBandingPrice(1.0), DefaultPrices.banding['1mm PVC']);
      expect(DefaultPrices.getBandingPrice(2.0), DefaultPrices.banding['2mm PVC']);
      expect(DefaultPrices.getBandingPrice(0.6), DefaultPrices.banding['1mm PVC']); // rounds up
    });
  });

  group('Price Sync', () {
    test('Default prices can be loaded', () {
      final service = PriceSyncService();
      final items = service.getDefaults();
      expect(items.isNotEmpty, true);
      expect(items.any((i) => i.category == 'plaka'), true);
      expect(items.any((i) => i.category == 'bant'), true);
      expect(items.any((i) => i.category == 'mentese'), true);
    });
  });
}
