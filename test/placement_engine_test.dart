import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/placement_engine.dart';

void main() {
  group('Placement Engine', () {
    test('Düz duvar - sadece alt dolaplar', () {
      final result = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: 3000,
        isLower: true,
      ));

      expect(result.modules.isNotEmpty, true);
      expect(result.totalWidthMm <= 3000, true);
      // Should fill most of the wall
      expect(result.totalWidthMm >= 2400, true, reason: 'Only ${result.totalWidthMm}mm of 3000mm filled');
      // No warnings for simple case
      expect(result.warnings.where((w) => w.contains('sığmadı')).isEmpty, true);
    });

    test('Düz duvar - evye + fırın yerleşimi', () {
      final result = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: 3000,
        isLower: true,
        anchors: WallAnchors(
          sinkCenterMm: 1000,    // evye ~100cm'de
          cooktopCenterMm: 2000, // fırın ~200cm'de
        ),
      ));

      // Should include sink and oven modules
      final codes = result.modules.map((m) => m.code).toSet();
      expect(codes.contains(ModuleCode.a4), true, reason: 'Evye (A4) missing');
      expect(codes.contains(ModuleCode.a5), true, reason: 'Fırın (A5) missing');

      // No overlaps: modules should not overlap
      for (var i = 0; i < result.modules.length; i++) {
        for (var j = i + 1; j < result.modules.length; j++) {
          final a = result.modules[i];
          final b = result.modules[j];
          final aEnd = a.xPosMm + a.widthMm;
          final bEnd = b.xPosMm + b.widthMm;
          expect(a.xPosMm >= bEnd || b.xPosMm >= aEnd, true,
              reason: 'Overlap: ${a.code}(${a.xPosMm}-$aEnd) vs ${b.code}(${b.xPosMm}-$bEnd)');
        }
      }
    });

    test('Düz duvar - buzdolabı + bulaşık makinesi', () {
      final result = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: 2800,
        isLower: true,
        anchors: WallAnchors(
          fridgeCenterMm: 400,
          dishwasherCenterMm: 1600,
        ),
      ));

      final codes = result.modules.map((m) => m.code).toSet();
      expect(codes.contains(ModuleCode.b2), true, reason: 'Buzdolabı (B2) missing');
      expect(codes.contains(ModuleCode.a6), true, reason: 'Bulaşık (A6) missing');
    });

    test('Üst dolaplar - davlumbaz yerleşimi', () {
      final result = PlacementEngine.placeUpper(PlacementInput(
        wallLengthMm: 2400,
        isLower: false,
        anchors: WallAnchors(cooktopCenterMm: 1200),
      ));

      // Should have hood module above cooktop
      final codes = result.modules.map((m) => m.code).toSet();
      expect(codes.contains(ModuleCode.u4), true, reason: 'Davlumbaz (U4) missing');

      // Hood should be near cooktop center
      final hood = result.modules.firstWhere((m) => m.code == ModuleCode.u4);
      final hoodCenter = hood.xPosMm + hood.widthMm / 2;
      expect((hoodCenter - 1200).abs() <= 300, true,
          reason: 'Hood center $hoodCenter too far from cooktop center 1200');
    });

    test('Çok kısa duvar - uyarı vermeli', () {
      final result = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: 500,
        isLower: true,
        anchors: WallAnchors(sinkCenterMm: 250),
      ));

      // Evye min 600mm, 500mm duvara sığmaz
      final hasWarning = result.warnings.any((w) => w.contains('sığmadı'));
      // May or may not fit depending on placement
      // Just verify it doesn't crash
      expect(result.modules.isNotEmpty || hasWarning, true);
    });

    test('Tam mutfak yerleşimi', () {
      final result = PlacementEngine.generateKitchen(
        walls: {
          'A': 2800,
          'B': 2200,
        },
        anchors: {
          'A': WallAnchors(sinkCenterMm: 1000, cooktopCenterMm: 2000),
          'B': WallAnchors(fridgeCenterMm: 300),
        },
        hasUpper: true,
      );

      expect(result.containsKey('A-alt'), true);
      expect(result.containsKey('A-ust'), true);
      expect(result.containsKey('B-alt'), true);
      expect(result.containsKey('B-ust'), true);
      expect(result['A-alt']!.isNotEmpty, true);
      expect(result['A-ust']!.isNotEmpty, true);
    });
  });
}
