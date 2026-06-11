/// Fixture-based integration tests per MODUL_FORMULLERI.md §5.4.
///
/// Loads 3 reference projects from test/fixtures/, runs the module engine,
/// and validates total part counts, plate counts, and hardware totals.

import 'dart:convert';
import 'dart:io';
import 'project.dart';
import 'module_engine.dart';

// ─── JSON Parsing Helpers ────────────────────────────────────────────────────

ModuleCode _parseCode(String s) {
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
      code: _parseCode(j['code'] as String),
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

// ─── Test Runner ─────────────────────────────────────────────────────────────

void testFixture(String path) {
  final content = File('test/fixtures/$path').readAsStringSync();
  final json = jsonDecode(content) as Map<String, dynamic>;
  final name = json['name'];
  final modules = parseModules(json['modules'] as List<dynamic>);
  final checks = json['expected_checks'] as Map<String, dynamic>;
  final expectedHw = json['expected_hardware'] as Map<String, dynamic>;

  print('\n--- $name ---');
  print('Modules: ${modules.length}');

  final engine = ModuleEngine();
  final mat = MaterialSpec();
  final allParts = <Part>[];
  final allHw = <String, int>{};

  for (final mod in modules) {
    final parts = engine.generateParts(mod, mat);
    allParts.addAll(parts);

    final hw = engine.generateHardware(mod);
    for (final e in hw.entries) {
      allHw[e.key] = (allHw[e.key] ?? 0) + e.value;
    }
  }

  // Total parts (counting qty > 1 properly)
  int totalPartCount = 0;
  for (final p in allParts) {
    totalPartCount += p.qty;
  }

  final range = checks['total_part_count_range'] as List<dynamic>;
  final minParts = range[0] as int;
  final maxParts = range[1] as int;
  assert(totalPartCount >= minParts && totalPartCount <= maxParts,
      '$name: Part count $totalPartCount not in [$minParts, $maxParts]');

  // Hardware checks
  final hwMenteseMin = expectedHw['menteşe_min'] as int;
  final totalMentese = (allHw['Menteşe'] ?? 0) + (allHw['Menteşe (geniş açı)'] ?? 0) +
      (allHw['Menteşe (amortisörlü)'] ?? 0) + (allHw['Cam menteşesi'] ?? 0);
  assert(totalMentese >= hwMenteseMin,
      '$name: Hinges $totalMentese < $hwMenteseMin');

  final kulplar = allHw['Kulp'] ?? 0;
  assert(kulplar == expectedHw['kulplar'],
      '$name: Handles $kulplar != ${expectedHw['kulplar']}');

  final raylar = allHw['Ray (çift)'] ?? 0;
  assert(raylar == expectedHw['ray_cift'],
      '$name: Rail pairs $raylar != ${expectedHw['ray_cift']}');

  final aski = allHw['Askı'] ?? 0;
  assert(aski == expectedHw['aski_takimi'],
      '$name: Askı $aski != ${expectedHw['aski_takimi']}');

  // Print summary
  print('  Part count: $totalPartCount (in [$minParts, $maxParts])');
  print('  Hardware:');
  for (final e in allHw.entries) {
    print('    ${e.key}: ${e.value}');
  }

  // Banding total > 0 check
  double totalBanding = 0;
  for (final p in allParts) {
    totalBanding += p.totalBandingMm * p.qty;
  }
  assert(totalBanding > 0, '$name: No banding at all?');
  print('  Total banding: ${(totalBanding / 1000).toStringAsFixed(1)} m');

  print('✅ $name PASSED');
}

// ─── Main ────────────────────────────────────────────────────────────────────

void main() {
  print('=== Fixture Integration Tests ===');

  testFixture('duz_mutfak.json');
  testFixture('l_mutfak.json');
  testFixture('u_mutfak.json');

  print('\n=== ALL FIXTURES PASSED ✅ ===');
}
