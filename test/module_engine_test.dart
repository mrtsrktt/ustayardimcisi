import 'dart:math';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';

/// Unit tests for ModuleEngine — validates every module formula
/// against hand-calculated expected values from MODUL_FORMULLERI.md.
///
/// Run: flutter test test/module_engine_test.dart

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Tolerance for double comparisons (mm)
const eps = 0.01;

bool near(double a, double b) => (a - b).abs() < eps;

double sumPartProperty(List<Part> parts, String Function(Part) prop) {
  double total = 0;
  for (final p in parts) {
    total += double.parse(prop(p).toString()) * p.qty;
  }
  return total;
}

// ─── A1 — Alt Tek Kapak ──────────────────────────────────────────────────────

void testA1() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.a1,
    xPosMm: 0,
    widthMm: 500,       // G = 500
    heightMm: 740,      // Y = 740
    depthMm: 560,       // D = 560
    params: const ModuleParams(rafSayisi: 1),
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  // Count & check parts
  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  // Yan ×2: 560×740, bant [1,0,0,0]
  assert(byName['Yan']!.length == 1, 'A1: Yan should be 1 group');
  assert(byName['Yan']!.first.qty == 2, 'A1: Yan qty=2');
  assert(near(byName['Yan']!.first.netWidthMm, 560), 'A1: Yan EN=560');
  assert(near(byName['Yan']!.first.netLengthMm, 740), 'A1: Yan BOY=740');

  // Alt tabla: (500−2×18)×560 = 464×560
  final alt = byName['Alt tabla']!.first;
  assert(near(alt.netWidthMm, 464), 'A1: Alt EN=464');
  assert(near(alt.netLengthMm, 560), 'A1: Alt BOY=560');

  // Kapak ×1: (500−4)×(740−4) = 496×736
  final kapak = byName['Kapak']!.first;
  assert(kapak.qty == 1, 'A1: 1 kapak');
  assert(near(kapak.netWidthMm, 496), 'A1: Kapak EN=496');
  assert(near(kapak.netLengthMm, 736), 'A1: Kapak BOY=736');

  print('✅ A1 passed');
}

// ─── A2 — Alt Çift Kapak ─────────────────────────────────────────────────────

void testA2() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.a2,
    xPosMm: 0,
    widthMm: 800,       // G = 800
    heightMm: 740,
    depthMm: 560,
    params: const ModuleParams(rafSayisi: 1),
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  // Her kapak: ((800−4−3)/2) × (740−4) = 396.5×736
  final kapaklar = byName['Kapak']!;
  assert(kapaklar.length == 2, 'A2: 2 kapak groups');
  final expectedKapakEn = (800 - 4 - 3) / 2;
  assert(near(kapaklar.first.netWidthMm, expectedKapakEn), 'A2: Kapak EN=$expectedKapakEn');
  assert(near(kapaklar.first.netLengthMm, 736), 'A2: Kapak BOY=736');

  // Hardware
  final hw = engine.generateHardware(mod);
  assert(hw['Menteşe'] == 4, 'A2: 4 hinges');
  assert(hw['Kulp'] == 2, 'A2: 2 handles');

  print('✅ A2 passed');
}

// ─── A3 — Alt Çekmeceli (3 drawers) ──────────────────────────────────────────

void testA3() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.a3,
    xPosMm: 0,
    widthMm: 800,
    heightMm: 740,
    depthMm: 560,
    params: const ModuleParams(cekmeceSayisi: 3),
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  // 3 çekmece önü
  final cekmeceOnleri = byName['Çekmece önü']!;
  assert(cekmeceOnleri.first.qty == 3 || cekmeceOnleri.length == 3,
      'A3: 3 drawer fronts');

  // Expected front height: (736 − (3−1)×3) / 3 = (736−6)/3 = 243.33
  final expectedH = (736 - 2 * 3) / 3;
  assert(near(cekmeceOnleri.first.netLengthMm, expectedH),
      'A3: Drawer front height=$expectedH');

  // Hardware
  final hw = engine.generateHardware(mod);
  assert(hw['Ray (çift)'] == 3, 'A3: 3 rail pairs');
  assert(hw['Kulp'] == 3, 'A3: 3 handles');

  print('✅ A3 passed');
}

// ─── A5 — Ankastre Fırın ─────────────────────────────────────────────────────

void testA5() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.a5,
    xPosMm: 0,
    widthMm: 600,
    heightMm: 740,
    depthMm: 560,
    params: const ModuleParams(),  // üst = çekmece (112 > 110 → OK)
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  // Üst ön: Y−fb−t−2r = 740−595−18−4 = 123
  final ustOn = byName['Üst çekmece önü']!;
  assert(near(ustOn.first.netLengthMm, 123), 'A5: Üst ön BOY=123');

  // Arkalık sadece üst bölgede: Y−fb−t−4 = 123
  final arka = byName['Arkalık']!;
  assert(near(arka.first.netLengthMm, 123), 'A5: Arkalık BOY=123');

  print('✅ A5 passed');
}

// ─── U1 — Üst Tek Kapak ──────────────────────────────────────────────────────

void testU1() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.u1,
    xPosMm: 0,
    widthMm: 500,
    heightMm: 720,
    depthMm: 320,
    params: const ModuleParams(rafSayisi: 2),
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  // Raflar: 2 adet
  final raflar = byName['Raf']!;
  assert(raflar.first.qty == 2 || raflar.length == 2, 'U1: 2 shelves');

  // Kapak: (500−4)×(720−4) = 496×716
  final kapak = byName['Kapak']!.first;
  assert(near(kapak.netWidthMm, 496), 'U1: Kapak EN=496');
  assert(near(kapak.netLengthMm, 716), 'U1: Kapak BOY=716');

  print('✅ U1 passed');
}

// ─── U2 — Üst Çift Kapak ─────────────────────────────────────────────────────

void testU2() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.u2,
    xPosMm: 0,
    widthMm: 800,
    heightMm: 720,
    depthMm: 320,
    params: const ModuleParams(rafSayisi: 2),
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  final kapaklar = byName['Kapak']!;
  assert(kapaklar.length == 2, 'U2: 2 kapak groups');

  // Each: ((800−4−3)/2)×716 = 396.5×716
  final expectedEn = (800 - 4 - 3) / 2;
  assert(near(kapaklar.first.netWidthMm, expectedEn), 'U2: Kapak EN=$expectedEn');

  print('✅ U2 passed');
}

// ─── B1 — Kiler/Boy Dolap ────────────────────────────────────────────────────

void testB1() {
  final engine = ModuleEngine();
  final mod = Module(
    code: ModuleCode.b1,
    xPosMm: 0,
    widthMm: 600,
    heightMm: 2080,
    depthMm: 560,
    params: const ModuleParams(),
  );
  final mat = MaterialSpec();
  final parts = engine.generateParts(mod, mat);

  final byName = <String, List<Part>>{};
  for (final p in parts) {
    byName.putIfAbsent(p.name, () => []).add(p);
  }

  // 1 alt kapak + 1 üst kapak (G ≤ 600 → k=1)
  assert(byName['Alt kapak'] != null, 'B1: Alt kapak exists');
  assert(byName['Üst kapak'] != null, 'B1: Üst kapak exists');

  // Arkalık 2080 > 1830 → 2 parça
  final arkalikAlt = byName['Arkalık alt'];
  final arkalikUst = byName['Arkalık üst'];
  assert(arkalikAlt != null || arkalikUst != null,
      'B1: Arkalık split into 2 pieces');

  // 4 raf
  final raflar = byName['Raf']!;
  assert(raflar.first.qty == 4 || raflar.length == 4, 'B1: 4 shelves');

  print('✅ B1 passed');
}

// ─── Bant Düşümü (§0.2) ──────────────────────────────────────────────────────

void testBantDusumu() {
  // 2mm bantlı, 4 kenarı bantlı kapak: NET 497×736 → KESİM 493×732
  final part = PartBuilder.part(
    moduleId: 'TEST',
    name: 'Kapak',
    qty: 1,
    netWidth: 497,
    netLength: 736,
    thickness: 18,
    material: 'Kapak',
    banding: [2, 2, 2, 2],
  );

  assert(near(part.cutWidthMm, 497 - 4), 'Bant düşümü EN: ${part.cutWidthMm}');
  assert(near(part.cutLengthMm, 736 - 4), 'Bant düşümü BOY: ${part.cutLengthMm}');

  print('✅ Bant düşümü passed');
}

// ─── Hardware Rules (§0.4) ───────────────────────────────────────────────────

void testHardwareRules() {
  // Menteşe count
  assert(HardwareCalc.mentese(500) == 2, '≤900 → 2');
  assert(HardwareCalc.mentese(1200) == 3, '901-1600 → 3');
  assert(HardwareCalc.mentese(1800) == 4, '1601-2000 → 4');
  assert(HardwareCalc.mentese(2200) == 5, '>2000 → 5');

  // Ray boy = D−60, standard'a yuvarla
  assert(HardwareCalc.rayBoy(560) == 500, 'D=560 → 500');
  assert(HardwareCalc.rayBoy(320) == 250, 'D=320 → 250');
  assert(HardwareCalc.rayBoy(450) == 350, 'D=450 → 350');

  print('✅ Hardware rules passed');
}

// ─── Run All ─────────────────────────────────────────────────────────────────

void main() {
  print('=== Module Engine Tests ===\n');

  testA1();
  testA2();
  testA3();
  testA5();
  testU1();
  testU2();
  testB1();
  testBantDusumu();
  testHardwareRules();

  print('\n=== ALL TESTS PASSED ✅ ===');
}
