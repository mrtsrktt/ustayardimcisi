import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';

const eps = 0.01;
bool near(double a, double b) => (a - b).abs() < eps;

final engine = ModuleEngine();
final mat = MaterialSpec();

Map<String, List<Part>> groupBy(List<Part> parts) {
  final map = <String, List<Part>>{};
  for (final p in parts) {
    map.putIfAbsent(p.name, () => []).add(p);
  }
  return map;
}

void main() {
  group('Alt Modüller', () {
    test('A1 - Alt Tek Kapak', () {
      final mod = Module(code: ModuleCode.a1, xPosMm: 0, widthMm: 500, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      final kapak = m['Kapak']!.first;
      expect(near(kapak.netWidthMm, 496), true);
      expect(near(kapak.netLengthMm, 736), true);
      expect(kapak.qty, 1);

      final hw = engine.generateHardware(mod);
      expect(hw['Menteşe'], 2);
      expect(hw['Kulp'], 1);
    });

    test('A2 - Alt Çift Kapak', () {
      final mod = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      final kapaklar = m['Kapak']!;
      final total = kapaklar.fold<int>(0, (s, p) => s + p.qty);
      expect(total, 2);
      final expectedEn = (800 - 4 - 3) / 2;
      expect(near(kapaklar.first.netWidthMm, expectedEn), true);

      final hw = engine.generateHardware(mod);
      expect(hw['Menteşe'], 4);
      expect(hw['Kulp'], 2);
    });

    test('A3 - Alt Çekmeceli (3 çekmece)', () {
      final mod = Module(code: ModuleCode.a3, xPosMm: 0, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      final onler = m['Çekmece önü']!;
      final total = onler.fold<int>(0, (s, p) => s + p.qty);
      expect(total, 3);

      final expectedH = (736 - 6) / 3;
      expect(near(onler.first.netLengthMm, expectedH), true);
      expect(m.containsKey('Kutu yanı'), true);
      expect(m.containsKey('Kutu ön/arka'), true);
      expect(m.containsKey('Kutu dibi'), true);

      final hw = engine.generateHardware(mod);
      expect(hw['Ray (çift)'], 3);
      expect(hw['Kulp'], 3);
    });

    test('A4 - Evye Dolabı', () {
      final mod = Module(code: ModuleCode.a4, xPosMm: 0, widthMm: 800, heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 0));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      final alt = m['Alt tabla']!.first;
      expect(alt.banding, [1, 1, 1, 1]); // 4 kenar bant
      expect(m.containsKey('Arka bağ. kaydı'), true);
      expect(m.containsKey('Arkalık'), false); // arkalık YOK

      final hw = engine.generateHardware(mod);
      expect(hw['Menteşe'], 4);
      expect(hw['Kulp'], 2);
    });

    test('A5 - Ankastre Fırın', () {
      final mod = Module(code: ModuleCode.a5, xPosMm: 0, widthMm: 600, heightMm: 740, depthMm: 560, params: const ModuleParams());
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Fırın üstü tabla'), true);
      final ustOn = m['Üst çekmece önü']!;
      expect(near(ustOn.first.netLengthMm, 123), true); // 740-595-18-4
      expect(m.containsKey('Kutu yanı'), true);
    });

    test('A6 - Bulaşık Makinesi Boşluğu', () {
      final mod = Module(code: ModuleCode.a6, xPosMm: 0, widthMm: 450, heightMm: 740, depthMm: 560, params: const ModuleParams(gorunurYan: true));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Görünür yan'), true);
      expect(m.containsKey('Üst bağ. kaydı'), true);

      final hw = engine.generateHardware(mod);
      expect(hw.isEmpty, true); // no hardware
    });

    test('A7 - Alt Köşe L', () {
      final mod = Module(code: ModuleCode.a7, xPosMm: 0, widthMm: 900, heightMm: 740, depthMm: 900, params: const ModuleParams());
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Kör dolgu'), true);
      expect(m.containsKey('Alt tabla P1'), true);
      expect(m.containsKey('Alt tabla P2'), true);

      final hw = engine.generateHardware(mod);
      expect(hw['Menteşe (geniş açı)'] ?? 0, 2);
    });
  });

  group('Üst Modüller', () {
    test('U1 - Üst Tek Kapak', () {
      final mod = Module(code: ModuleCode.u1, xPosMm: 0, widthMm: 500, heightMm: 720, depthMm: 320, params: const ModuleParams(rafSayisi: 2));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Alt tabla'), true);
      expect(m.containsKey('Üst tabla'), true);
      final kapak = m['Kapak']!.first;
      expect(near(kapak.netWidthMm, 496), true);
      expect(near(kapak.netLengthMm, 716), true);

      final hw = engine.generateHardware(mod);
      expect(hw['Askı'], 2);
      expect(hw['Menteşe'], 2);
    });

    test('U2 - Üst Çift Kapak', () {
      final mod = Module(code: ModuleCode.u2, xPosMm: 0, widthMm: 800, heightMm: 720, depthMm: 320, params: const ModuleParams(rafSayisi: 2));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      final kapaklar = m['Kapak']!;
      expect(kapaklar.fold<int>(0, (s, p) => s + p.qty), 2);

      final hw = engine.generateHardware(mod);
      expect(hw['Menteşe'], 4);
      expect(hw['Askı'], 2);
    });

    test('U3 - Üst Camlı Kapak', () {
      final modCamli = Module(code: ModuleCode.u3, xPosMm: 0, widthMm: 600, heightMm: 720, depthMm: 320, params: const ModuleParams(camli: true, rafSayisi: 1));
      final hw = engine.generateHardware(modCamli);
      expect((hw['Cam menteşesi'] ?? 0) > 0, true);

      final modMdf = Module(code: ModuleCode.u3, xPosMm: 0, widthMm: 600, heightMm: 720, depthMm: 320, params: const ModuleParams(camli: false, rafSayisi: 1));
      final parts = engine.generateParts(modMdf, mat);
      final m = groupBy(parts);
      expect(m.containsKey('Cam kapak dikme'), true);
      expect(m.containsKey('Cam kapak başlık'), true);
    });

    test('U4 - Davlumbaz', () {
      final mod = Module(code: ModuleCode.u4, xPosMm: 0, widthMm: 600, heightMm: 380, depthMm: 320, params: const ModuleParams());
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Alt tabla'), false); // YOK
      expect(m.containsKey('Arkalık'), false);   // YOK
      expect(m.containsKey('Üst tabla'), true);
      expect(m.containsKey('Ön panel'), true);

      final hw = engine.generateHardware(mod);
      expect(hw['Askı'], 2);
    });

    test('U5 - Üst Köşe', () {
      final mod = Module(code: ModuleCode.u5, xPosMm: 0, widthMm: 600, heightMm: 720, depthMm: 600, params: const ModuleParams());
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Kör dolgu'), true);
      expect(m.containsKey('Üst tabla P1'), true);

      final hw = engine.generateHardware(mod);
      expect(hw['Askı'], 2);
    });
  });

  group('Boy Modüller', () {
    test('B1 - Kiler/Boy Dolap', () {
      final mod = Module(code: ModuleCode.b1, xPosMm: 0, widthMm: 600, heightMm: 2080, depthMm: 560, params: const ModuleParams());
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Alt kapak'), true);
      expect(m.containsKey('Üst kapak'), true);
      expect(m.containsKey('Ara tabla'), true);

      final raflar = m['Raf']!;
      expect(raflar.fold<int>(0, (s, p) => s + p.qty), 4);

      // Arkalık split check
      if (m.containsKey('Arkalık alt')) {
        expect(m.containsKey('Arkalık üst'), true);
      }
    });

    test('B2 - Buzdolabı Boşluğu', () {
      final mod = Module(code: ModuleCode.b2, xPosMm: 0, widthMm: 800, heightMm: 2080, depthMm: 560, params: const ModuleParams(gorunurYan: true));
      final parts = engine.generateParts(mod, mat);
      final m = groupBy(parts);

      expect(m.containsKey('Boy yan panel'), true);
      expect(m.containsKey('Yan'), true); // üst kutu

      final hw = engine.generateHardware(mod);
      expect(hw['Askı'], 2);
    });
  });

  group('Bant Düşümü ve Donanım', () {
    test('Bant düşümü (§0.2)', () {
      final part = PartBuilder.part(
        moduleId: 'TEST', name: 'Kapak', qty: 1,
        netWidth: 497, netLength: 736, thickness: 18,
        materialFull: 'High Gloss 18mm Beyaz', role: 'kapak', banding: [2, 2, 2, 2],
      );
      expect(near(part.cutWidthMm, 497 - 4), true);
      expect(near(part.cutLengthMm, 736 - 4), true);
    });

    test('Menteşe kuralları (§0.4)', () {
      expect(HardwareCalc.mentese(500), 2);
      expect(HardwareCalc.mentese(1200), 3);
      expect(HardwareCalc.mentese(1800), 4);
      expect(HardwareCalc.mentese(2200), 5);
    });

    test('Ray boy hesabı (§0.4)', () {
      expect(HardwareCalc.rayBoy(560), 500);
      expect(HardwareCalc.rayBoy(320), 250);
    });
  });
}
