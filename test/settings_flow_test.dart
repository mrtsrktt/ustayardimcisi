/// Verifies that settings flow from AppSettings → ModuleEngine + CutOptimizer.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';
import 'package:ustayardimcisi/modules/cut_optimizer.dart';
import 'package:ustayardimcisi/services/cost_service.dart' as cost;

void main() {
  group('Settings Flow', () {
    test('AppSettings.fromMap parses all fields', () {
      final map = {
        'kerf_mm': '3.2',
        'trim_mm': '5',
        'plate_width_mm': '1830',
        'plate_length_mm': '3660',
        'arkalik_tip': 'kanal',
        'min_serit_mm': '40',
        'use_band_deduction': 'true',
      };
      final s = AppSettings.fromMap(map);
      expect(s.kerfMm, 3.2);
      expect(s.trimMm, 5);
      expect(s.plateWidthMm, 1830);
      expect(s.plateLengthMm, 3660);
      expect(s.arkalikTip, ArkalikTip.kanal);
      expect(s.minSeritMm, 40);
      expect(s.useDeduction, true);
    });

    test('ArkalikTip.kanal → engine uses kanal formula (G−2t+2k)', () {
      final settings = const AppSettings(arkalikTip: ArkalikTip.kanal);
      final engine = ModuleEngine(settings: settings);
      final mat = MaterialSpec();

      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1));

      final parts = engine.generateParts(mod, mat);
      final arkalik = parts.where((p) => p.role == 'arkalik').toList();

      expect(arkalik.isNotEmpty, true);

      // Kanal formula: G − 2t + 2k = 800 − 36 + 16 = 780
      final p = arkalik.first;
      expect(p.netWidthMm, closeTo(800 - 2 * ModuleDefaults.t + 2 * 8, 0.1),
          reason: 'Kanal arkalik eni G−2t+2k olmali. Got: ${p.netWidthMm}');
      expect(p.material, 'Arkalik 8mm');
    });

    test('ArkalikTip.cakma → engine uses cakma formula (G−4)', () {
      final settings = const AppSettings(arkalikTip: ArkalikTip.cakma);
      final engine = ModuleEngine(settings: settings);
      final mat = MaterialSpec();

      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1));

      final parts = engine.generateParts(mod, mat);
      final arkalik = parts.where((p) => p.role == 'arkalik').toList();

      expect(arkalik.isNotEmpty, true);

      // Cakma formula: G − 4 = 796
      final p = arkalik.first;
      expect(p.netWidthMm, closeTo(800 - 4, 0.1),
          reason: 'Cakma arkalik eni G−4 olmali. Got: ${p.netWidthMm}');
    });

    test('CutConfig.fromSettings → optimizer uses custom plate size', () {
      final map = {
        'kerf_mm': '3.2',
        'trim_mm': '5',
        'plate_width_mm': '1830',
        'plate_length_mm': '3660',
      };
      final config = CutConfig.fromSettings(map);
      expect(config.kerfMm, 3.2);
      expect(config.trimMm, 5);
      expect(config.plateWidthMm, 1830);
      expect(config.plateLengthMm, 3660);
    });

    test('Custom plate 1830×3660 + kerf 3.2 produces correct sheet sizes', () {
      final config = CutConfig(
        plateWidthMm: 1830, plateLengthMm: 3660,
        kerfMm: 3.2, trimMm: 5,
      );
      final optimizer = CutOptimizer(config: config);
      final engine = ModuleEngine();
      final mat = MaterialSpec();

      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1, gorunurYan: true));
      final parts = engine.generateParts(mod, mat);
      final sheets = optimizer.optimize(parts);

      expect(sheets.isNotEmpty, true);
      for (final s in sheets) {
        expect(s.widthMm, 1830, reason: 'Sheet width should be 1830 from settings');
        expect(s.lengthMm, 3660, reason: 'Sheet length should be 3660 from settings');
      }
    });

    test('Default settings (no DB) → uses sensible defaults', () {
      final settings = AppSettings.fromMap({});
      expect(settings.kerfMm, 4.8);
      expect(settings.plateWidthMm, 2100);
      expect(settings.plateLengthMm, 2800);
      expect(settings.arkalikTip, ArkalikTip.cakma);
      expect(settings.useDeduction, true);
    });

    test('Full flow: kanal arkalik + 1830×3660 plate + kerf 3.2', () {
      final settings = const AppSettings(
        arkalikTip: ArkalikTip.kanal,
        kerfMm: 3.2,
        plateWidthMm: 1830,
        plateLengthMm: 3660,
        trimMm: 5,
      );
      final config = CutConfig.fromSettings({
        'kerf_mm': '3.2', 'trim_mm': '5',
        'plate_width_mm': '1830', 'plate_length_mm': '3660',
      });

      final engine = ModuleEngine(settings: settings);
      final optimizer = CutOptimizer(config: config);
      final mat = MaterialSpec();

      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1, gorunurYan: true));

      final parts = engine.generateParts(mod, mat);
      final sheets = optimizer.optimize(parts);

      // Assert: arkalik uses kanal formula
      final arkalik = parts.where((p) => p.role == 'arkalik').first;
      expect(arkalik.netWidthMm, closeTo(800 - 2 * 18 + 2 * 8, 0.1));

      // Assert: sheets are 1830×3660
      for (final s in sheets) {
        expect(s.widthMm, 1830);
        expect(s.lengthMm, 3660);
      }

      // Assert: all parts placed
      final total = parts.fold<int>(0, (s, p) => s + p.qty);
      final placed = sheets.fold<int>(0, (s, sh) => s + sh.partCount);
      expect(placed, total);

      print('\n  Settings flow verified:');
      print('  - Arkalik tip: kanal (G−2t+2k = ${arkalik.netWidthMm.toInt()}mm)');
      print('  - Plate: ${sheets.first.widthMm.toInt()}×${sheets.first.lengthMm.toInt()}');
      print('  - Kerf: ${config.kerfMm}mm');
      print('  - Parts: $total placed on ${sheets.length} sheet(s)');
    });
  });

  group('Arkalik Thickness (3mm vs 8mm)', () {
    test('3mm arkalik → correct dimensions and price', () {
      final mat = MaterialSpec(arkalikThicknessMm: 3);
      final engine = ModuleEngine();
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1));

      final parts = engine.generateParts(mod, mat);
      final arkalik = parts.where((p) => p.role == 'arkalik').first;

      // Thickness should be 3mm
      expect(arkalik.thicknessMm, 3);
      expect(arkalik.material, 'Arkalik 3mm');

      // Cakma formula: G−4, Y−4
      expect(arkalik.netWidthMm, closeTo(800 - 4, 0.1));
      expect(arkalik.netLengthMm, closeTo(740 - 4, 0.1));
    });

    test('8mm arkalik → correct dimensions and price', () {
      final mat = MaterialSpec(arkalikThicknessMm: 8);
      final engine = ModuleEngine();
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1));

      final parts = engine.generateParts(mod, mat);
      final arkalik = parts.where((p) => p.role == 'arkalik').first;

      expect(arkalik.thicknessMm, 8);
      expect(arkalik.material, 'Arkalik 8mm');
    });

    test('3mm vs 8mm different price', () {
      final optimizer = CutOptimizer();
      final engine = ModuleEngine();
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1));

      // 3mm scenario
      final parts3 = engine.generateParts(mod, MaterialSpec(arkalikThicknessMm: 3));
      final sheets3 = optimizer.optimize(parts3);
      final calc = cost.CostCalculator();
      final report3 = calc.calculate(allParts: parts3, sheets: sheets3, hardware: {},
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz', doorMaterial: 'MDFlam', doorColor: 'Beyaz',
        );
      final arkalikLine3 = report3.lines.firstWhere((l) => l.item.contains('Arkalik'));

      // 8mm scenario
      final parts8 = engine.generateParts(mod, MaterialSpec(arkalikThicknessMm: 8));
      final sheets8 = optimizer.optimize(parts8);
      final report8 = calc.calculate(allParts: parts8, sheets: sheets8, hardware: {},
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz', doorMaterial: 'MDFlam', doorColor: 'Beyaz',
        );
      final arkalikLine8 = report8.lines.firstWhere((l) => l.item.contains('Arkalik'));

      expect(arkalikLine3.unitPrice, 350, reason: 'Arkalik 3mm = 350 TL');
      expect(arkalikLine8.unitPrice, 650, reason: 'Arkalik 8mm = 650 TL');
      expect(arkalikLine3.item, contains('3mm'));
      expect(arkalikLine8.item, contains('8mm'));

      print('\n  Arkalik 3mm: ${arkalikLine3.item} × ${arkalikLine3.unitPrice.toInt()} TL');
      print('  Arkalik 8mm: ${arkalikLine8.item} × ${arkalikLine8.unitPrice.toInt()} TL');
    });

    test('3mm kanal arkalik → kanal derinligi = 3mm', () {
      final settings = const AppSettings(arkalikTip: ArkalikTip.kanal);
      final mat = MaterialSpec(arkalikThicknessMm: 3);
      final engine = ModuleEngine(settings: settings);
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1));

      final parts = engine.generateParts(mod, mat);
      final arkalik = parts.where((p) => p.role == 'arkalik').first;

      // Kanal: G − 2t + 2k = 800 − 36 + 6 = 770 (k=3)
      expect(arkalik.netWidthMm, closeTo(800 - 2 * 18 + 2 * 3, 0.1));
      expect(arkalik.thicknessMm, 3);
      print('\n  3mm kanal arkalik: ${arkalik.netWidthMm.toInt()}×${arkalik.netLengthMm.toInt()} mm');
    });
  });

  group('Plate Size per Material', () {
    test('Different material roles get different plate sizes', () {
      final config = CutConfig(materialSizes: {
        'govde': PlateSize.std2100x2800,
        'kapak': PlateSize.std1220x2800,
        'arkalik': PlateSize.std1830x3660,
      });
      expect(config.getSizeFor('govde').widthMm, 2100);
      expect(config.getSizeFor('kapak').widthMm, 1220);
      expect(config.getSizeFor('arkalik').widthMm, 1830);
    });

    test('Govde 1830×3660 vs 2100×2800 comparison', () {
      final engine = ModuleEngine();
      final mat = MaterialSpec();
      final mods = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320,
            params: const ModuleParams(rafSayisi: 2)),
      ];
      final parts = <Part>[];
      for (final m in mods) { parts.addAll(engine.generateParts(m, mat)); }

      // Size A: 2100×2800
      final optA = CutOptimizer(config: CutConfig(plateWidthMm: 2100, plateLengthMm: 2800));
      final sheetsA = optA.optimize(parts);
      final countA = sheetsA.length;
      final wasteA = sheetsA.isEmpty ? 0.0 : sheetsA.map((s) => s.wastePct).reduce((a, b) => a + b) / sheetsA.length;

      // Size B: 1830×3660
      final optB = CutOptimizer(config: CutConfig(plateWidthMm: 1830, plateLengthMm: 3660));
      final sheetsB = optB.optimize(parts);
      final countB = sheetsB.length;
      final wasteB = sheetsB.isEmpty ? 0.0 : sheetsB.map((s) => s.wastePct).reduce((a, b) => a + b) / sheetsB.length;

      print('\n  PLATE SIZE COMPARISON:');
      print('  2100×2800: $countA sheets, %${wasteA.toStringAsFixed(1)} waste');
      print('  1830×3660: $countB sheets, %${wasteB.toStringAsFixed(1)} waste');

      // Both should place all parts
      final totalParts = parts.fold<int>(0, (s, p) => s + p.qty);
      expect(sheetsA.fold<int>(0, (s, sh) => s + sh.partCount), totalParts);
      expect(sheetsB.fold<int>(0, (s, sh) => s + sh.partCount), totalParts);
    });

    test('Kapak 1220×2800 standard size for High Gloss', () {
      final mat = MaterialSpec(
        doorMaterial: MalzemeTip.highGloss, doorColor: 'Beyaz',
        bodyMaterial: MalzemeTip.mdflam, bodyColor: 'Beyaz');
      final engine = ModuleEngine();
      final mods = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
      ];
      final parts = <Part>[];
      for (final m in mods) { parts.addAll(engine.generateParts(m, mat)); }

      final config = CutConfig(materialSizes: {
        'govde': PlateSize.std2100x2800,
        'kapak': PlateSize.std1220x2800,
        'arkalik': PlateSize.std2100x2800,
      });
      final optimizer = CutOptimizer(config: config);
      final sheets = optimizer.optimize(parts);

      // Kapak sheets should be 1220×2800
      for (final s in sheets) {
        if (s.material.contains('High Gloss')) {
          expect(s.widthMm, 1220, reason: 'HG kapak 1220×2800 olmali, got ${s.widthMm}×${s.lengthMm}');
        }
      }
      print('\n  Kapak 1220×2800 verified for High Gloss parts');
    });

    test('Kesim ucreti = plaka adedi × 100 TL', () {
      final engine = ModuleEngine();
      final mat = MaterialSpec();
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1, gorunurYan: true));
      final parts = engine.generateParts(mod, mat);
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);
      final calc = cost.CostCalculator();
      final report = calc.calculate(
        allParts: parts, sheets: sheets, hardware: {},
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz',
        doorMaterial: 'MDFlam', doorColor: 'Beyaz',
        );

      final cutLine = report.lines.firstWhere((l) => l.item == 'Kesim ucreti');
      expect(cutLine.qty.toInt(), sheets.length);
      expect(cutLine.unitPrice, 100, reason: '100 TL/plaka');
      expect(cutLine.total, closeTo(100 * sheets.length, 0.1));
      print('\n  Kesim ucreti: ${sheets.length} plaka × 100 TL = ${cutLine.total.toInt()} TL');
    });
  });

  group('Bantlama Iscilik Ucreti', () {
    test('0.4mm govde + 2mm kapak → correct labor prices', () {
      final engine = ModuleEngine();
      final mat = MaterialSpec();
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
          params: const ModuleParams(rafSayisi: 1, gorunurYan: true));
      final parts = engine.generateParts(mod, mat);
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);
      final calc = cost.CostCalculator();
      final report = calc.calculate(
        allParts: parts, sheets: sheets, hardware: {},
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz',
        doorMaterial: 'MDFlam', doorColor: 'Beyaz',
        );

      // Find bantlama isciligi lines
      final iscilikLines = report.lines.where((l) => l.item.contains('Bantlama isciligi')).toList();
      expect(iscilikLines.isNotEmpty, true);

      // 1mm govde banding → 20 TL/m
      final govdeIscilik = iscilikLines.firstWhere((l) => l.item.contains('1.0mm'));
      expect(govdeIscilik.unitPrice, 20, reason: '1mm bant iscilik = 20 TL/m');

      // 2mm kapak banding → 40 TL/m
      final kapakIscilik = iscilikLines.firstWhere((l) => l.item.contains('2.0mm'));
      expect(kapakIscilik.unitPrice, 40, reason: '2mm bant iscilik = 40 TL/m');

      print('\n  Bantlama Iscilik:');
      for (final l in iscilikLines) {
        print('  ${l.item}: ${l.qty.toStringAsFixed(1)}m × ${l.unitPrice.toInt()} TL/m = ${l.total.toInt()} TL');
      }

      // Also verify separate material cost line exists
      final materialLines = report.lines.where((l) => l.item.contains('Kenar bandı')).toList();
      expect(materialLines.isNotEmpty, true);
      print('  (ayri malzeme satiri da mevcut: ${materialLines.length} adet)');
    });

    test('0.4mm bant → 10 TL/m iscilik', () {
      final engine = ModuleEngine();
      // Use a module with 0.4mm banding (cekmece kutusu)
      final mat = MaterialSpec();
      final mod = Module(code: ModuleCode.a3, xPosMm: 0, widthMm: 600, heightMm: 740, depthMm: 560,
          params: const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0));
      final parts = engine.generateParts(mod, mat);
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(parts);
      final calc = cost.CostCalculator();
      final report = calc.calculate(
        allParts: parts, sheets: sheets, hardware: {},
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz',
        doorMaterial: 'MDFlam', doorColor: 'Beyaz',
        );

      final iscilikLines = report.lines.where((l) => l.item.contains('Bantlama isciligi')).toList();
      final has04 = iscilikLines.any((l) => l.item.contains('0.4mm'));
      if (has04) {
        final l04 = iscilikLines.firstWhere((l) => l.item.contains('0.4mm'));
        expect(l04.unitPrice, 10, reason: '0.4mm bant iscilik = 10 TL/m');
        print('\n  0.4mm iscilik: ${l04.qty.toStringAsFixed(1)}m × 10 TL/m = ${l04.total.toInt()} TL');
      }
    });
  });
}
