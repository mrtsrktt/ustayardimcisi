/// Complete test suite for all 14 modules.
/// Validates every module formula against hand-calculated expected values.
/// References MODUL_FORMULLERI.md sections.

import 'project.dart';
import 'module_engine.dart';

const eps = 0.01;
bool near(double a, double b) => (a - b).abs() < eps;

ModuleEngine engine = ModuleEngine();
MaterialSpec mat = MaterialSpec();

// ─── Alt Modüller ────────────────────────────────────────────────────────────

void testA1() {
  final mod = Module(code: ModuleCode.a1, xPosMm: 0, widthMm: 500, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
  final parts = engine.generateParts(mod, mat);
  print('  A1: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  assert(partsMap.containsKey('Yan'), 'A1: Yan missing');
  assert(partsMap.containsKey('Kapak'), 'A1: Kapak missing');
  final kapak = partsMap['Kapak']!.first;
  assert(near(kapak.netWidthMm, 496), 'A1: Kapak EN=${kapak.netWidthMm} != 496');
  assert(near(kapak.netLengthMm, 736), 'A1: Kapak BOY=${kapak.netLengthMm} != 736');
  assert(kapak.qty == 1, 'A1: 1 kapak');

  final hw = engine.generateHardware(mod);
  assert(hw['Menteşe'] == 2, 'A1: 2 hinges');
  assert(hw['Kulp'] == 1, 'A1: 1 handle');
  print('✅ A1');
}

void testA2() {
  final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
  final parts = engine.generateParts(mod, mat);
  print('  A2: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  final kapaklar = partsMap['Kapak']!;
  final expectedEn = (800 - 4 - 3) / 2; // = 396.5
  assert(near(kapaklar.first.netWidthMm, expectedEn), 'A2: Kapak EN');
  assert(near(kapaklar.first.netLengthMm, 736), 'A2: Kapak BOY');
  // 2 kapak: ya 2 group ya da 1 group qty=2
  final totalKapak = kapaklar.fold<int>(0, (s, p) => s + p.qty);
  assert(totalKapak == 2, 'A2: 2 kapak total');

  final hw = engine.generateHardware(mod);
  assert(hw['Menteşe'] == 4, 'A2: 4 hinges');
  assert(hw['Kulp'] == 2, 'A2: 2 handles');
  print('✅ A2');
}

void testA3() {
  final mod = Module(code: ModuleCode.a3, xPosMm: 0, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0));
  final parts = engine.generateParts(mod, mat);
  print('  A3: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  final onler = partsMap['Çekmece önü']!;
  final totalOn = onler.fold<int>(0, (s, p) => s + p.qty);
  assert(totalOn == 3, 'A3: 3 drawer fronts');
  // Expected height: (736 − 2×3)/3 = 243.33
  final expectedH = (736 - 6) / 3;
  assert(near(onler.first.netLengthMm, expectedH), 'A3: Front height');

  // Check drawer box parts exist
  assert(partsMap.containsKey('Kutu yanı'), 'A3: Kutu yanı missing');
  assert(partsMap.containsKey('Kutu ön/arka'), 'A3: Kutu ön/arka missing');
  assert(partsMap.containsKey('Kutu dibi'), 'A3: Kutu dibi missing');

  final hw = engine.generateHardware(mod);
  assert(hw['Ray (çift)'] == 3, 'A3: 3 rail pairs');
  assert(hw['Kulp'] == 3, 'A3: 3 handles');
  print('✅ A3');
}

void testA4() {
  final mod = Module(code: ModuleCode.a4, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 0));
  final parts = engine.generateParts(mod, mat);
  print('  A4: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  // Alt tabla: 4 kenar bant (su koruması)
  final alt = partsMap['Alt tabla']!.first;
  assert(alt.banding[0] == 1 && alt.banding[1] == 1 && alt.banding[2] == 1 && alt.banding[3] == 1,
      'A4: Alt tabla 4-edge banded');

  // Arkalık YOK → Arka bağlantı kaydı var
  assert(partsMap.containsKey('Arka bağ. kaydı'), 'A4: Arka bağ. kaydı missing');
  assert(!partsMap.containsKey('Arkalık'), 'A4: Arkalık should NOT exist');

  // 2 kapak
  final kapaklar = partsMap['Kapak']!;
  final totalKapak = kapaklar.fold<int>(0, (s, p) => s + p.qty);
  assert(totalKapak == 2, 'A4: 2 kapak');

  final hw = engine.generateHardware(mod);
  assert(hw['Menteşe'] == 4, 'A4: 4 hinges');
  assert(hw['Kulp'] == 2, 'A4: 2 handles');
  print('✅ A4');
}

void testA5() {
  final mod = Module(code: ModuleCode.a5, xPosMm: 0, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams());
  final parts = engine.generateParts(mod, mat);
  print('  A5: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  // Fırın üstü tabla var
  assert(partsMap.containsKey('Fırın üstü tabla'), 'A5: Fırın üstü tabla missing');

  // Üst ön: 740−595−18−4 = 123
  final ustOn = partsMap['Üst çekmece önü']!;
  assert(near(ustOn.first.netLengthMm, 123), 'A5: Üst ön BOY=${ustOn.first.netLengthMm}');

  // Check kutu parts (cekmece drawer box)
  assert(partsMap.containsKey('Kutu yanı'), 'A5: Kutu yanı missing');
  print('✅ A5');
}

void testA6() {
  final mod = Module(code: ModuleCode.a6, xPosMm: 0, widthMm: 450, heightMm: 740, depthMm: 560, params: const ModuleParams(gorunurYan: true));
  final parts = engine.generateParts(mod, mat);
  print('  A6: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  assert(partsMap.containsKey('Görünür yan'), 'A6: Görünür yan missing');
  assert(partsMap.containsKey('Üst bağ. kaydı'), 'A6: Üst bağ. kaydı missing');

  // No hardware (machine has own)
  final hw = engine.generateHardware(mod);
  assert(hw.isEmpty, 'A6: No hardware expected');
  print('✅ A6');
}

void testA7() {
  final mod = Module(code: ModuleCode.a7, xPosMm: 0, widthMm: 900, heightMm: 740, depthMm: 900, params: const ModuleParams());
  final parts = engine.generateParts(mod, mat);
  print('  A7: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  assert(partsMap.containsKey('Kör dolgu'), 'A7: Kör dolgu missing');
  assert(partsMap.containsKey('Alt tabla P1'), 'A7: Alt tabla P1 missing');
  assert(partsMap.containsKey('Alt tabla P2'), 'A7: Alt tabla P2 missing');

  final hw = engine.generateHardware(mod);
  assert((hw['Menteşe (geniş açı)'] ?? 0) == 2, 'A7: 2 wide-angle hinges');
  print('✅ A7');
}

// ─── Üst Modüller ────────────────────────────────────────────────────────────

void testU1() {
  final mod = Module(code: ModuleCode.u1, xPosMm: 0, widthMm: 500, heightMm: 720, depthMm: 320, params: const ModuleParams(rafSayisi: 2));
  final parts = engine.generateParts(mod, mat);
  print('  U1: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  // Alt + Üst tabla ikisi de var
  assert(partsMap.containsKey('Alt tabla'), 'U1: Alt tabla missing');
  assert(partsMap.containsKey('Üst tabla'), 'U1: Üst tabla missing');

  final kapak = partsMap['Kapak']!.first;
  assert(near(kapak.netWidthMm, 496), 'U1: Kapak EN=496');
  assert(near(kapak.netLengthMm, 716), 'U1: Kapak BOY=716');

  final hw = engine.generateHardware(mod);
  assert(hw['Askı'] == 2, 'U1: 2 hangers');
  assert(hw['Menteşe'] == 2, 'U1: 2 hinges (Y=716→2)');
  print('✅ U1');
}

void testU2() {
  final mod = Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320, params: const ModuleParams(rafSayisi: 2));
  final parts = engine.generateParts(mod, mat);
  print('  U2: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  final kapaklar = partsMap['Kapak']!;
  final total = kapaklar.fold<int>(0, (s, p) => s + p.qty);
  assert(total == 2, 'U2: 2 kapak');
  final expectedEn = (800 - 4 - 3) / 2;
  assert(near(kapaklar.first.netWidthMm, expectedEn), 'U2: Kapak EN');

  final hw = engine.generateHardware(mod);
  assert(hw['Menteşe'] == 4, 'U2: 4 hinges');
  assert(hw['Askı'] == 2, 'U2: 2 hangers');
  print('✅ U2');
}

void testU3() {
  // Camlı
  final modCamli = Module(code: ModuleCode.u3, xPosMm: 0, widthMm: 600, heightMm: 720, depthMm: 320, params: const ModuleParams(camli: true, rafSayisi: 1));
  final partsCamli = engine.generateParts(modCamli, mat);
  print('  U3 (camlı): ${partsCamli.length} part entries');

  final hwCamli = engine.generateHardware(modCamli);
  assert((hwCamli['Cam menteşesi'] ?? 0) > 0, 'U3: Cam hinges required');

  // MDF çerçeveli
  final modMdf = Module(code: ModuleCode.u3, xPosMm: 0, widthMm: 600, heightMm: 720, depthMm: 320, params: const ModuleParams(camli: false, rafSayisi: 1));
  final partsMdf = engine.generateParts(modMdf, mat);
  print('  U3 (MDF frame): ${partsMdf.length} part entries');

  final partsMap = _groupBy(partsMdf);
  assert(partsMap.containsKey('Cam kapak dikme'), 'U3: Çerçeve dikme missing');
  assert(partsMap.containsKey('Cam kapak başlık'), 'U3: Çerçeve başlık missing');
  print('✅ U3');
}

void testU4() {
  final mod = Module(code: ModuleCode.u4, xPosMm: 0, widthMm: 600, heightMm: 380, depthMm: 320, params: const ModuleParams());
  final parts = engine.generateParts(mod, mat);
  print('  U4: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  // Alt tabla YOK (baca)
  assert(!partsMap.containsKey('Alt tabla'), 'U4: Alt tabla should NOT exist');
  // Arkalık YOK
  assert(!partsMap.containsKey('Arkalık'), 'U4: Arkalık should NOT exist');
  // Üst tabla var
  assert(partsMap.containsKey('Üst tabla'), 'U4: Üst tabla missing');
  // Ön panel var
  assert(partsMap.containsKey('Ön panel'), 'U4: Ön panel missing');

  final hw = engine.generateHardware(mod);
  assert(hw['Askı'] == 2, 'U4: 2 hangers');
  print('✅ U4');
}

void testU5() {
  final mod = Module(code: ModuleCode.u5, xPosMm: 0, widthMm: 600, heightMm: 720, depthMm: 600, params: const ModuleParams());
  final parts = engine.generateParts(mod, mat);
  print('  U5: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  assert(partsMap.containsKey('Kör dolgu'), 'U5: Kör dolgu missing');
  assert(partsMap.containsKey('Üst tabla P1'), 'U5: Üst tabla P1 missing');

  final hw = engine.generateHardware(mod);
  assert(hw['Askı'] == 2, 'U5: 2 hangers');
  print('✅ U5');
}

// ─── Boy Modüller ────────────────────────────────────────────────────────────

void testB1() {
  final mod = Module(code: ModuleCode.b1, xPosMm: 0, widthMm: 600, heightMm: 2080, depthMm: 560, params: const ModuleParams());
  final parts = engine.generateParts(mod, mat);
  print('  B1: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  // alt + üst kapak
  assert(partsMap.containsKey('Alt kapak'), 'B1: Alt kapak missing');
  assert(partsMap.containsKey('Üst kapak'), 'B1: Üst kapak missing');
  // ara tabla
  assert(partsMap.containsKey('Ara tabla'), 'B1: Ara tabla missing');
  // 4 raf
  final raflar = partsMap['Raf']!;
  final totalRaf = raflar.fold<int>(0, (s, p) => s + p.qty);
  assert(totalRaf == 4, 'B1: 4 shelves, got $totalRaf');

  // Arkalık 2 parça (2080-4=2076 > 1830)
  if (partsMap.containsKey('Arkalık alt')) {
    assert(partsMap.containsKey('Arkalık üst'), 'B1: Both back pieces needed');
  }
  print('✅ B1');
}

void testB2() {
  final mod = Module(code: ModuleCode.b2, xPosMm: 0, widthMm: 800, heightMm: 2080, depthMm: 560, params: const ModuleParams(gorunurYan: true));
  final parts = engine.generateParts(mod, mat);
  print('  B2: ${parts.length} part entries');

  final partsMap = _groupBy(parts);
  assert(partsMap.containsKey('Boy yan panel'), 'B2: Boy yan panel missing');
  // Üst kutu U1 formülünde
  assert(partsMap.containsKey('Yan'), 'B2: Üst kutu yanları missing');

  final hw = engine.generateHardware(mod);
  assert(hw['Askı'] == 2, 'B2: 2 hangers');
  print('✅ B2');
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Map<String, List<Part>> _groupBy(List<Part> parts) {
  final map = <String, List<Part>>{};
  for (final p in parts) {
    map.putIfAbsent(p.name, () => []).add(p);
  }
  return map;
}

// ─── Main ────────────────────────────────────────────────────────────────────

void main() {
  print('=== ALL 14 MODULES TEST ===\n');

  testA1(); testA2(); testA3(); testA4(); testA5(); testA6(); testA7();
  testU1(); testU2(); testU3(); testU4(); testU5();
  testB1(); testB2();

  print('\n=== ALL 14 MODULES PASSED ✅ ===');
}
