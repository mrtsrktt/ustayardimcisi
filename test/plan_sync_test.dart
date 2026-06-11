/// MADDE 4: Plan degisince kesim listesi otomatik yeniden hesaplanir.
import 'package:flutter_test/flutter_test.dart';
import 'package:ustayardimcisi/models/project.dart';
import 'package:ustayardimcisi/modules/module_engine.dart';

void main() {
  group('Plan → Kesim Senkron', () {
    test('Modul genisligi degisince parca olculeri degisir', () {
      final mat = MaterialSpec(bodyMaterial: MalzemeTip.mdflam, bodyColor: 'Beyaz');
      final engine = ModuleEngine();

      // 600mm genislik
      final mod600 = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 600,
          heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
      final parts600 = engine.generateParts(mod600, mat);

      // 800mm genislik
      final mod800 = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800,
          heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
      final parts800 = engine.generateParts(mod800, mat);

      // Alt tabla genisligi farkli
      final alt600 = parts600.firstWhere((p) => p.name == 'Alt tabla');
      final alt800 = parts800.firstWhere((p) => p.name == 'Alt tabla');
      expect(alt600.cutWidthMm, isNot(alt800.cutWidthMm),
          reason: '600mm vs 800mm: alt tabla kesim olcusu farkli olmali');

      // Kapak genisligi farkli
      final kpk600 = parts600.where((p) => p.name == 'Kapak').first;
      final kpk800 = parts800.where((p) => p.name == 'Kapak').first;
      expect(kpk600.cutWidthMm, isNot(kpk800.cutWidthMm),
          reason: 'Kapak olcusu modul genisligiyle degismeli');
    });

    test('Cekmece sayisi degisince parca listesi degisir', () {
      final mat = MaterialSpec();
      final engine = ModuleEngine();

      // 2 cekmeceli
      final mod2 = Module(code: ModuleCode.a3, xPosMm: 0, widthMm: 600,
          heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 2, rafSayisi: 0));
      final parts2 = engine.generateParts(mod2, mat);

      // 4 cekmeceli
      final mod4 = Module(code: ModuleCode.a3, xPosMm: 0, widthMm: 600,
          heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 4, rafSayisi: 0));
      final parts4 = engine.generateParts(mod4, mat);

      // Cekmece onu adedi farkli
      final on2 = parts2.where((p) => p.name == 'Çekmece önü').fold<int>(0, (s, p) => s + p.qty);
      final on4 = parts4.where((p) => p.name == 'Çekmece önü').fold<int>(0, (s, p) => s + p.qty);
      expect(on2, 2, reason: '2 cekmece onu');
      expect(on4, 4, reason: '4 cekmece onu');
      expect(on2, isNot(on4));

      // Kutu yani sayisi da farkli
      final kutu2 = parts2.where((p) => p.name == 'Kutu yanı').fold<int>(0, (s, p) => s + p.qty);
      final kutu4 = parts4.where((p) => p.name == 'Kutu yanı').fold<int>(0, (s, p) => s + p.qty);
      expect(kutu2, isNot(kutu4), reason: 'Kutu yani adedi cekmece sayisiyla degismeli');
    });

    test('Tip degisince (A2→A3) parca listesi farklidir', () {
      final mat = MaterialSpec();
      final engine = ModuleEngine();

      final a2 = Module(code: ModuleCode.a2, xPosMm: 0, widthMm: 800,
          heightMm: 740, depthMm: 560, params: const ModuleParams(rafSayisi: 1));
      final a3 = Module(code: ModuleCode.a3, xPosMm: 0, widthMm: 800,
          heightMm: 740, depthMm: 560, params: const ModuleParams(cekmeceSayisi: 3, rafSayisi: 0));

      final pA2 = engine.generateParts(a2, mat);
      final pA3 = engine.generateParts(a3, mat);

      // A2'de kapak var, A3'te cekmece onu var
      final a2Kapak = pA2.any((p) => p.name == 'Kapak');
      final a3Cekmece = pA3.any((p) => p.name == 'Çekmece önü');
      expect(a2Kapak, true);
      expect(a3Cekmece, true);

      // Toplam parca sayilari farkli
      final t2 = pA2.fold<int>(0, (s, p) => s + p.qty);
      final t3 = pA3.fold<int>(0, (s, p) => s + p.qty);
      expect(t2, isNot(t3), reason: 'A2 ve A3 farkli parca sayisi uretir');
    });
  });
}
