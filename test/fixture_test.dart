import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';

ModuleCode parseCode(String s) {
  return switch (s.toUpperCase()) {
    'A1' => ModuleCode.a1, 'A2' => ModuleCode.a2, 'A3' => ModuleCode.a3,
    'A4' => ModuleCode.a4, 'A5' => ModuleCode.a5, 'A6' => ModuleCode.a6,
    'A7' => ModuleCode.a7, 'U1' => ModuleCode.u1, 'U2' => ModuleCode.u2,
    'U3' => ModuleCode.u3, 'U4' => ModuleCode.u4, 'U5' => ModuleCode.u5,
    'B1' => ModuleCode.b1, 'B2' => ModuleCode.b2,
    _ => throw ArgumentError('Unknown module code: $s'),
  };
}

List<Module> parseModules(List<dynamic> jsonList) {
  return jsonList.map((j) {
    final params = j['params'] as Map<String, dynamic>? ?? {};
    return Module(
      code: parseCode(j['code'] as String),
      xPosMm: (j['x_mm'] as num).toDouble(),
      widthMm: (j['width_mm'] as num).toDouble(),
      heightMm: (j['height_mm'] as num).toDouble(),
      depthMm: (j['depth_mm'] as num).toDouble(),
      params: ModuleParams(
        rafSayisi: params['rafSayisi'] ?? 1,
        cekmeceSayisi: params['cekmeceSayisi'] ?? 0,
        camli: params['camli'] ?? false,
        ortaDikme: params['ortaDikme'] ?? false,
        gorunurYan: params['gorunurYan'] ?? false,
        bazaDevam: params['bazaDevam'] ?? true,
        sabitRaf: params['sabitRaf'] ?? false,
      ),
    );
  }).toList();
}

void main() {
  final fixtures = ['duz_mutfak.json', 'l_mutfak.json', 'u_mutfak.json'];
  final engine = ModuleEngine();
  final mat = MaterialSpec();

  for (final fixturePath in fixtures) {
    test('Fixture: $fixturePath', () {
      final content = File('test/fixtures/$fixturePath').readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final name = json['name'];
      final modules = parseModules(json['modules'] as List<dynamic>);
      final checks = json['expected_checks'] as Map<String, dynamic>;
      final expectedHw = json['expected_hardware'] as Map<String, dynamic>;

      final allParts = <Part>[];
      final allHw = <String, int>{};

      for (final mod in modules) {
        allParts.addAll(engine.generateParts(mod, mat));
        final hw = engine.generateHardware(mod);
        for (final e in hw.entries) {
          allHw[e.key] = (allHw[e.key] ?? 0) + e.value;
        }
      }

      // Part count range check
      int count = allParts.fold<int>(0, (s, p) => s + p.qty);
      final range = checks['total_part_count_range'] as List<dynamic>;
      final minParts = (range[0] as num).toInt();
      final maxParts = (range[1] as num).toInt();
      expect(count >= minParts && count <= maxParts, true,
          reason: '$name: Part count $count not in [$minParts, $maxParts]');

      // Hardware minimum checks (exact counts verified in module tests)
      final hwMenteseMin = (expectedHw['menteşe_min'] as num).toInt();
      final totalMentese = (allHw['Menteşe'] ?? 0) +
          (allHw['Menteşe (geniş açı)'] ?? 0) +
          (allHw['Menteşe (amortisörlü)'] ?? 0) +
          (allHw['Cam menteşesi'] ?? 0);
      expect(totalMentese >= hwMenteseMin, true,
          reason: '$name: Hinges $totalMentese < $hwMenteseMin');

      final kulplar = allHw['Kulp'] ?? 0;
      expect(kulplar >= (expectedHw['kulplar'] as num).toInt(), true,
          reason: '$name: Handles too few ($kulplar)');

      final raylar = allHw['Ray (çift)'] ?? 0;
      expect(raylar >= (expectedHw['ray_cift'] as num).toInt(), true,
          reason: '$name: Rail pairs too few ($raylar)');

      final aski = allHw['Askı'] ?? 0;
      expect(aski >= (expectedHw['aski_takimi'] as num).toInt(), true,
          reason: '$name: Askı too few ($aski)');

      // Banding must exist
      double totalBanding = allParts.fold<double>(
          0, (s, p) => s + p.totalBandingMm * p.qty);
      expect(totalBanding > 0, true);
    });
  }
}
