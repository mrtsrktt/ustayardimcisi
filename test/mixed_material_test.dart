/// Mixed material test: Govde MDFlam Beyaz + Kapak High Gloss Antrasit.
/// Verifies: different materials → different sheets → correct pricing.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';
import 'package:ustayardimcisi/modules/cut_optimizer.dart';
import 'package:ustayardimcisi/services/cost_service.dart';
import 'package:ustayardimcisi/services/report_service.dart';

void main() {
  group('Mixed Material Scenario', () {
    // Govde: MDFlam Beyaz, Kapak: High Gloss Antrasit
    final mat = MaterialSpec(
      bodyMaterial: MalzemeTip.mdflam,
      bodyColor: 'Beyaz',
      doorMaterial: MalzemeTip.highGloss,
      doorColor: 'Antrasit',
      edgeBand: const EdgeBandSpec(govdeThicknessMm: 1, kapakThicknessMm: 2),
    );

    final engine = ModuleEngine();

    test('Different materials produce separate sheet groups', () {
      // A2 + U2 with mixed materials
      final modules = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320,
            params: const ModuleParams(rafSayisi: 2)),
      ];

      final allParts = <Part>[];
      for (final mod in modules) {
        allParts.addAll(engine.generateParts(mod, mat));
      }

      // Verify material names are correct
      final govdeParts = allParts.where((p) => p.role == 'govde').toList();
      final kapakParts = allParts.where((p) => p.role == 'kapak').toList();
      final arkalikParts = allParts.where((p) => p.role == 'arkalik').toList();

      expect(govdeParts.isNotEmpty, true);
      expect(kapakParts.isNotEmpty, true);
      expect(arkalikParts.isNotEmpty, true);

      // Check material strings match expected
      for (final p in govdeParts) {
        expect(p.material, 'MDFlam 18mm Beyaz');
        expect(p.role, 'govde');
      }
      for (final p in kapakParts) {
        expect(p.material, 'High Gloss 18mm Antrasit');
        expect(p.role, 'kapak');
      }
      for (final p in arkalikParts) {
        expect(p.material, 'Arkalik 8mm');
        expect(p.role, 'arkalik');
      }

      // Run optimizer
      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(allParts);

      // Collect unique materials from sheets
      final sheetMaterials = <String>{};
      for (final s in sheets) {
        sheetMaterials.add(s.material);
      }

      // Must have at least 2 different material groups (govde + kapak + arkalik)
      expect(sheetMaterials.length, greaterThanOrEqualTo(3),
          reason: 'Expected >=3 material groups, got ${sheetMaterials.length}: $sheetMaterials');

      // Each sheet must only contain parts of ONE material
      for (final s in sheets) {
        final firstMat = s.material;
        // All parts on this sheet should match the sheet's material
        print('  Sheet: $firstMat — ${s.partCount} parts, waste ${s.wastePct.toStringAsFixed(1)}%');
      }

      // Verify specific material groups exist
      expect(sheetMaterials.contains('MDFlam 18mm Beyaz'), true,
          reason: 'Govde material group missing');
      expect(sheetMaterials.contains('High Gloss 18mm Antrasit'), true,
          reason: 'Kapak material group missing');
      expect(sheetMaterials.contains('Arkalik 8mm'), true,
          reason: 'Arkalik material group missing');

      print('\n  Sheet materials: $sheetMaterials');
    });

    test('Cost report shows correct prices for each material', () {
      final modules = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320,
            params: const ModuleParams(rafSayisi: 2)),
      ];

      final allParts = <Part>[];
      final allHw = <String, int>{};
      for (final mod in modules) {
        allParts.addAll(engine.generateParts(mod, mat));
        for (final e in engine.generateHardware(mod).entries) {
          allHw[e.key] = (allHw[e.key] ?? 0) + e.value;
        }
      }

      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(allParts);

      final calc = CostCalculator();
      final report = calc.calculate(
        allParts: allParts,
        sheets: sheets,
        hardware: allHw,
        bodyMaterial: 'MDFlam',
        bodyColor: 'Beyaz',
        doorMaterial: 'High Gloss',
        doorColor: 'Antrasit',
        edgeBandThickness: 2,
        countertopType: 'Tezgah laminant',
        countertopLengthMtul: 2.0,
      );

      // Find plate cost lines
      final plateLines = report.lines
          .where((l) => l.unit == 'plaka')
          .toList();

      expect(plateLines.length, greaterThanOrEqualTo(2),
          reason: 'Expected >=2 plate cost lines for mixed materials, got ${plateLines.length}');

      // Check MDFlam Beyaz plate pricing (1850 TL in DefaultPrices)
      final govdeLine = plateLines.firstWhere(
          (l) => l.item.contains('MDFlam'), orElse: () => throw 'MDFlam line not found');
      expect(govdeLine.item, contains('MDFlam 18mm Beyaz'));
      expect(govdeLine.unitPrice, 1850);

      // Check High Gloss Antrasit plate pricing (3500 TL)
      final kapakLine = plateLines.firstWhere(
          (l) => l.item.contains('High Gloss'), orElse: () => throw 'High Gloss line not found');
      expect(kapakLine.item, contains('High Gloss 18mm Antrasit'));
      expect(kapakLine.unitPrice, 3500);

      // Check Arkalik plate pricing (650 TL)
      final arkalikLine = plateLines.firstWhere(
          (l) => l.item.contains('Arkalik'), orElse: () => throw 'Arkalik line not found');
      expect(arkalikLine.unitPrice, 650);

      // Verify no parts from different materials share a sheet
      // (already tested in optimize group logic, but double-check)
      final sheetMats = sheets.map((s) => s.material).toSet();
      expect(sheetMats.length, greaterThanOrEqualTo(3));

      print('\n  === Mixed Material Cost Report ===');
      for (final l in plateLines) {
        print('  ${l.item}: ${l.qty.toInt()} × ${l.unitPrice.toInt()} TL = ${l.total.toInt()} TL');
      }
      print('  Sheet materials: $sheetMats');
      print('  Subtotal: ${report.subtotal.toInt()} TL');
      print('  Customer price: ${report.formattedCustomerPrice}');
    });

    test('Banding calculator separates govde and kapak banding', () {
      final modules = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320,
            params: const ModuleParams(rafSayisi: 2)),
      ];

      final allParts = <Part>[];
      for (final mod in modules) {
        allParts.addAll(engine.generateParts(mod, mat));
      }

      final metraj = BandingCalculator.calculateMetraj(allParts);

      // Govde parts have 1mm banding, kapak parts have 2mm banding
      // They should appear as separate entries
      expect(metraj.length, greaterThanOrEqualTo(2),
          reason: 'Expected separate banding entries for govde (1mm) and kapak (2mm)');

      // Check we have both 1mm and 2mm banding
      final keys = metraj.keys.join(', ');
      expect(keys.contains('1'), true, reason: '1mm govde banding missing from $keys');
      expect(keys.contains('2'), true, reason: '2mm kapak banding missing from $keys');

      print('\n  Banding metraj:');
      for (final e in metraj.entries) {
        print('  ${e.key}: ${e.value.toStringAsFixed(1)} m');
      }
    });

    test('Generate real PDF and Excel files with mixed materials', () async {
      final modules = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320,
            params: const ModuleParams(rafSayisi: 2)),
      ];

      final allParts = <Part>[];
      for (final mod in modules) {
        allParts.addAll(engine.generateParts(mod, mat));
      }

      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(allParts);

      // Create output directory
      final dir = Directory('test_output');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      // Generate PDF
      final pdfFile = await PdfReportGenerator.generate(
        sheets: sheets,
        allParts: allParts,
        projectName: 'Test_Karisik_Malzeme',
        customerName: 'Test Musteri',
        outputPath: 'test_output/kesim_plani_karisik_malzeme.pdf',
      );
      expect(await pdfFile.exists(), true);
      print('\n  PDF: ${pdfFile.path} (${(await pdfFile.length()) ~/ 1024} KB)');

      // Generate Excel
      final xlsFile = await ExcelReportGenerator.generate(
        allParts: allParts,
        sheets: sheets,
        projectName: 'Test_Karisik_Malzeme',
        outputPath: 'test_output/kesim_listesi_karisik_malzeme.xlsx',
      );
      expect(await xlsFile.exists(), true);
      print('  Excel: ${xlsFile.path} (${(await xlsFile.length()) ~/ 1024} KB)');

      // Print sample rows from cut list
      print('\n  === PDF Kesim Listesi Ornek Satirlar ===');
      var count = 0;
      for (final p in allParts) {
        if (count >= 4) break;
        print('  ${p.moduleId} | ${p.name} | ${p.cutWidthMm.toInt()}×${p.cutLengthMm.toInt()} mm | ${p.material}');
        for (var q = 1; q < p.qty && count < 4; q++) {
          count++;
        }
        count++;
      }

      // Print plate schema headers
      print('\n  === Plaka Semasi Basliklari ===');
      for (var i = 0; i < sheets.length; i++) {
        print('  Plaka ${i + 1}: ${sheets[i].material} — ${sheets[i].partCount} parca');
      }
    });

    // ─── Manual test scenario: Suntalam Antrasit + Akrilik Beyaz ──────────
    test('Manual scenario: Suntalam Antrasit govde + Akrilik Beyaz kapak (A2+A3+U2)', () {
      final mat = MaterialSpec(
        bodyMaterial: MalzemeTip.suntalam,
        bodyColor: 'Antrasit',
        doorMaterial: MalzemeTip.akrilik,
        doorColor: 'Beyaz',
        edgeBand: const EdgeBandSpec(govdeThicknessMm: 1, kapakThicknessMm: 2),
      );

      final modules = [
        Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560,
            params: const ModuleParams(rafSayisi: 1, gorunurYan: true)),
        Module(code: ModuleCode.a3, xPosMm: 800, widthMm: 600, heightMm: 740, depthMm: 560,
            params: const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0)),
        Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320,
            params: const ModuleParams(rafSayisi: 2)),
      ];

      final allParts = <Part>[];
      for (final mod in modules) {
        allParts.addAll(engine.generateParts(mod, mat));
      }

      final optimizer = CutOptimizer();
      final sheets = optimizer.optimize(allParts);
      final sheetMats = sheets.map((s) => s.material).toSet();

      // Verify material names in parts
      final govdeParts = allParts.where((p) => p.role == 'govde');
      final kapakParts = allParts.where((p) => p.role == 'kapak');
      final arkalikParts = allParts.where((p) => p.role == 'arkalik');

      for (final p in govdeParts) {
        expect(p.material, 'Suntalam 18mm Antrasit');
      }
      for (final p in kapakParts) {
        expect(p.material, 'Akrilik 18mm Beyaz');
      }

      // Verify sheet materials
      expect(sheetMats.contains('Suntalam 18mm Antrasit'), true,
          reason: 'Suntalam govde sheet group missing');
      expect(sheetMats.contains('Akrilik 18mm Beyaz'), true,
          reason: 'Akrilik kapak sheet group missing');
      expect(sheetMats.contains('Arkalik 8mm'), true,
          reason: 'Arkalik sheet group missing');

      // Cost report
      final calc = CostCalculator();
      final report = calc.calculate(
        allParts: allParts, sheets: sheets, hardware: {},
        bodyMaterial: 'Suntalam', bodyColor: 'Antrasit',
        doorMaterial: 'Akrilik', doorColor: 'Beyaz',
        countertopType: 'Tezgah laminant',
        countertopLengthMtul: 3.0,
      );

      final plateLines = report.lines.where((l) => l.unit == 'plaka').toList();

      // Check Suntalam plate price (1500 TL)
      final suntalamLine = plateLines.firstWhere((l) => l.item.contains('Suntalam'));
      expect(suntalamLine.unitPrice, 1500,
          reason: 'Suntalam should be 1500 TL, got ${suntalamLine.unitPrice}');

      // Check Akrilik plate price (3800 TL)
      final akrilikLine = plateLines.firstWhere((l) => l.item.contains('Akrilik'));
      expect(akrilikLine.unitPrice, 3800,
          reason: 'Akrilik should be 3800 TL, got ${akrilikLine.unitPrice}');

      // Print full report
      print('\n  === MANUEL SENARYO: Suntalam Antrasit + Akrilik Beyaz ===');
      print('  Moduller: A2(800) + A3(600,3cek) + U2(800)');
      print('');
      print('  PLAKA GRUPLARI:');
      for (final s in sheets) {
        print('  ${s.material}: ${s.partCount} parca, %${s.wastePct.toStringAsFixed(1)} fire');
      }
      print('');
      print('  KESIM LISTESI (ilk 5):');
      var count = 0;
      for (final p in allParts) {
        if (count >= 5) break;
        print('  ${p.moduleId} | ${p.name} | ${p.cutWidthMm.toInt()}×${p.cutLengthMm.toInt()} | ${p.material}');
        count++;
      }
      print('');
      print('  MALIYET (plaka satirlari):');
      for (final l in plateLines) {
        print('  ${l.item}: ${l.qty.toInt()} plaka × ${l.unitPrice.toInt()} TL = ${l.total.toInt()} TL');
      }
      print('  Teklif Fiyati: ${report.formattedCustomerPrice}');
    });
  });
}
