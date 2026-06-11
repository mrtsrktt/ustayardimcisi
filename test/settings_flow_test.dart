/// Verifies that settings flow from AppSettings → ModuleEngine + CutOptimizer.

import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';
import 'package:ustayardimcisi/modules/cut_optimizer.dart';

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
}
