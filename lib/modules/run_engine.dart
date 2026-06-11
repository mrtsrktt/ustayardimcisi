/// Run (Hat) Level Engine — generates parts that span across multiple modules.
///
/// When individual modules are combined into a kitchen run, these parts are
/// automatically generated per MODUL_FORMULLERI.md §4.

import '../models/project.dart';
import 'module_engine.dart';

// ─── Run-level Parts (§4) ────────────────────────────────────────────────────

class RunEngine {
  final AppSettings settings;

  const RunEngine({this.settings = const AppSettings()});

  /// Generate all run-level parts for a given module sequence.
  RunParts generateRunParts({
    required List<Module> altModules,          // lower cabinet modules
    required List<Module> ustModules,          // upper cabinet modules
    required double wallLengthMm,              // total wall length
    required ModuleDefaults defaults,
  }) {
    final parts = <Part>[];
    final purchaseItems = <PurchaseItem>[];

    // Alt hat
    if (altModules.isNotEmpty) {
      final altHatUzunluk = altModules.fold<double>(0, (s, m) => s + m.widthMm);

      // D1: Dolgu çıtası (filler strip)
      final dolguMm = wallLengthMm - altHatUzunluk;
      if (dolguMm >= 10) {
        final altY = altModules.first.heightMm;
        parts.add(PartBuilder.part(
          moduleId: 'RUN',
          name: 'Dolgu çıtası (alt)',
          qty: 1,
          netWidth: dolguMm,
          netLength: altY,
          thickness: ModuleDefaults.t,
          materialFull: 'High Gloss 18mm Beyaz', role: 'kapak',
          banding: [1, 0, 0, 0],
        ));
      }

      // D2: Baza önü (plinth front) — skip dishwasher gaps if baza_devam=false
      double bazaUzunluk = 0;
      for (final m in altModules) {
        if (m.code == ModuleCode.a6 && !m.params.bazaDevam) continue;
        bazaUzunluk += m.widthMm;
      }
      // Split if > 2400mm (standard panel limit)
      const maxBazaParca = 2400.0;
      int bazaParca = (bazaUzunluk / maxBazaParca).ceil();
      double kalan = bazaUzunluk;
      for (var i = 0; i < bazaParca; i++) {
        final parcaBoy = kalan > maxBazaParca ? maxBazaParca : kalan;
        parts.add(PartBuilder.part(
          moduleId: 'RUN',
          name: 'Baza önü',
          qty: 1,
          netWidth: parcaBoy,
          netLength: ModuleDefaults.bazaH,
          thickness: ModuleDefaults.t,
          materialFull: 'High Gloss 18mm Beyaz', role: 'kapak',
          banding: [1, 1, 0, 0],  // alt+üst kenar bant (zemin koruması)
        ));
        kalan -= parcaBoy;
      }

      // D3: Tezgah (countertop) — purchase item
      final tezgahMtul = altHatUzunluk / 1000;
      purchaseItems.add(PurchaseItem(
          item: 'Tezgah', qty: tezgahMtul, unit: 'mtül', category: 'tezgah'));

      // D4: Süpürgelik (backsplash)
      purchaseItems.add(PurchaseItem(
          item: 'Tezgah üstü alın (süpürgelik)',
          qty: tezgahMtul,
          unit: 'mtül',
          category: 'tezgah'));
    }

    // Üst hat
    if (ustModules.isNotEmpty) {
      final ustHatUzunluk = ustModules.fold<double>(0, (s, m) => s + m.widthMm);

      // D1: Upper filler
      final dolguMm = wallLengthMm - ustHatUzunluk;
      if (dolguMm >= 10) {
        final ustY = ustModules.first.heightMm;
        parts.add(PartBuilder.part(
          moduleId: 'RUN',
          name: 'Dolgu çıtası (üst)',
          qty: 1,
          netWidth: dolguMm,
          netLength: ustY,
          thickness: ModuleDefaults.t,
          materialFull: 'High Gloss 18mm Beyaz', role: 'kapak',
          banding: [1, 0, 0, 0],
        ));
      }

      // D5: Kornij/ışık bandı (cornice/light valence) — purchase item
      if (ustHatUzunluk > 0) {
        purchaseItems.add(PurchaseItem(
            item: 'Kornij/ışık bandı (opsiyonel)',
            qty: ustHatUzunluk / 1000,
            unit: 'mtül',
            category: 'aksesuar'));
      }
    }

    return RunParts(parts: parts, purchaseItems: purchaseItems);
  }
}

// ─── Run-level data classes ──────────────────────────────────────────────────

class RunParts {
  final List<Part> parts;
  final List<PurchaseItem> purchaseItems;

  const RunParts({this.parts = const [], this.purchaseItems = const []});
}

class PurchaseItem {
  final String item;
  final double qty;
  final String unit;      // mtül, m², adet
  final String category;  // tezgah, aksesuar, cam

  const PurchaseItem({
    required this.item,
    required this.qty,
    required this.unit,
    required this.category,
  });
}

// ─── Complete Project Part Generator ─────────────────────────────────────────

class ProjectPartGenerator {
  final ModuleEngine moduleEngine;
  final RunEngine runEngine;

  ProjectPartGenerator({AppSettings? settings})
      : moduleEngine = ModuleEngine(settings: settings ?? const AppSettings()),
        runEngine = RunEngine(settings: settings ?? const AppSettings());

  /// Generate the complete part list for an entire cabinet plan.
  ProjectParts generateAll({
    required List<Module> altModules,
    required List<Module> ustModules,
    required List<Module> boyModules,
    required double wallLengthMm,
    required MaterialSpec material,
  }) {
    final allParts = <Part>[];
    final allHardware = <String, int>{};
    final allPurchase = <PurchaseItem>[];

    void processModules(List<Module> modules) {
      for (final mod in modules) {
        allParts.addAll(moduleEngine.generateParts(mod, material));
        final hw = moduleEngine.generateHardware(mod);
        for (final e in hw.entries) {
          allHardware[e.key] = (allHardware[e.key] ?? 0) + e.value;
        }
      }
    }

    processModules(altModules);
    processModules(ustModules);
    processModules(boyModules);

    // Run-level parts for each wall
    // (simplified: assumes one wall; multi-wall handled in UI)
    final runResult = runEngine.generateRunParts(
      altModules: altModules,
      ustModules: ustModules,
      wallLengthMm: wallLengthMm,
      defaults: ModuleDefaults(),
    );
    allParts.addAll(runResult.parts);
    allPurchase.addAll(runResult.purchaseItems);

    // Label all parts
    final labeled = _labelAll(allParts);

    return ProjectParts(
      parts: labeled,
      hardware: allHardware,
      purchaseItems: allPurchase,
    );
  }

  List<Part> _labelAll(List<Part> parts) {
    final result = <Part>[];
    var idx = 1;
    for (final p in parts) {
      result.add(Part(
        moduleId: p.moduleId,
        name: p.name,
        qty: p.qty,
        netWidthMm: p.netWidthMm,
        netLengthMm: p.netLengthMm,
        thicknessMm: p.thicknessMm,
        material: p.material,
        banding: p.banding,
        grainLocked: p.grainLocked,
        label: 'P-${idx.toString().padLeft(3, '0')}',
      ));
      idx++;
    }
    return result;
  }
}

class ProjectParts {
  final List<Part> parts;
  final Map<String, int> hardware;
  final List<PurchaseItem> purchaseItems;

  const ProjectParts({
    this.parts = const [],
    this.hardware = const {},
    this.purchaseItems = const [],
  });

  int get totalPartCount => parts.fold<int>(0, (s, p) => s + p.qty);

  double get totalBandingM {
    double total = 0;
    for (final p in parts) {
      total += p.totalBandingMm * p.qty;
    }
    return total / 1000; // mm → m
  }
}
