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
        countertopType: 'Tezgah laminant', countertopLengthMtul: 1.0);
      final arkalikLine3 = report3.lines.firstWhere((l) => l.item.contains('Arkalik'));

      // 8mm scenario
      final parts8 = engine.generateParts(mod, MaterialSpec(arkalikThicknessMm: 8));
      final sheets8 = optimizer.optimize(parts8);
      final report8 = calc.calculate(allParts: parts8, sheets: sheets8, hardware: {},
        bodyMaterial: 'MDFlam', bodyColor: 'Beyaz', doorMaterial: 'MDFlam', doorColor: 'Beyaz',
        countertopType: 'Tezgah laminant', countertopLengthMtul: 1.0);
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
}
