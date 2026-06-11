/// Kesim Sonucu Ekrani — Plaka semalari + detayli malzeme listesi + maliyet.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../modules/module_engine.dart';
import '../modules/placement_engine.dart';
import '../modules/cut_optimizer.dart';
import '../services/report_service.dart';
import '../services/siparis_formu.dart';
import '../services/cost_service.dart' as cost;
import '../providers/database_provider.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final double wallLengthMm;
  final String govdeMalzeme, govdeRenk;
  final String altKapakMalzeme, altKapakRenk;
  final String ustKapakMalzeme, ustKapakRenk;
  final String kulpTipi, customerName;
  final int cekmeceSayisi;
  final bool camli;
  final double arkalikKalinlik;
  final PlateSize govdePlateSize;
  final PlateSize kapakPlateSize;
  final PlateSize arkalikPlateSize;

  const ResultScreen({
    super.key, required this.wallLengthMm,
    required this.govdeMalzeme, required this.govdeRenk,
    required this.altKapakMalzeme, required this.altKapakRenk,
    required this.ustKapakMalzeme, required this.ustKapakRenk,
    required this.kulpTipi, required this.customerName,
    required this.cekmeceSayisi, required this.camli,
    this.arkalikKalinlik = 8,
    this.govdePlateSize = PlateSize.std2100x2800,
    this.kapakPlateSize = PlateSize.std2100x2800,
    this.arkalikPlateSize = PlateSize.std2100x2800,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  int _tab = 0;
  String? _pdfPath, _excelPath;
  final _marjCtrl = TextEditingController();
  double _marjYuzde = 0;
  double _teklifTutar = 0;
  String? _oncekiOzet; // onceki hesaplama ozeti

  late List<Part> _allParts;
  late List<SheetLayout> _sheets;
  late cost.CostReport _costReport;
  late Map<String, int> _hardware;
  late double _bandingMetraj;

  @override
  void initState() {
    super.initState();
    _hesapla();
  }

  void _hesapla() {
    // Load settings from DB
    Map<String, String> settingsMap = {};
    try {
      final db = ref.read(databaseProvider);
      settingsMap = db.getAllSettings();
    } catch (_) {}

    final appSettings = AppSettings.fromMap(settingsMap);
    final cutConfig = CutConfig.fromSettings(settingsMap);

    final engine = ModuleEngine(settings: appSettings);

    // Build MaterialSpec from wizard selections
    final mat = MaterialSpec(
      bodyMaterial: _parseMalzeme(widget.govdeMalzeme),
      bodyColor: widget.govdeRenk,
      doorMaterial: _parseMalzeme(widget.altKapakMalzeme),
      doorColor: widget.altKapakRenk,
      edgeBand: const EdgeBandSpec(govdeThicknessMm: 1, kapakThicknessMm: 2),
      arkalikThicknessMm: widget.arkalikKalinlik,
    );

    // Plate sizes from wizard dialog selection
    final optimizer = CutOptimizer(config: CutConfig(
      kerfMm: cutConfig.kerfMm,
      trimMm: cutConfig.trimMm,
      materialSizes: {
        'govde': widget.govdePlateSize,
        'kapak': widget.kapakPlateSize,
        'arkalik': widget.arkalikPlateSize,
      },
    ));

    final placement = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: widget.wallLengthMm, isLower: true));
    final ustPlacement = PlacementEngine.placeUpper(PlacementInput(
        wallLengthMm: widget.wallLengthMm, isLower: false));

    _allParts = [];
    final modCounts = <String, int>{};
    for (final m in placement.modules) {
      final code = m.code.name.toUpperCase();
      modCounts[code] = (modCounts[code] ?? 0) + 1;
      final instanceMod = m.toModule(740, 560, params: ModuleParams(
          rafSayisi: m.code == ModuleCode.a3 ? 0 : 1,
          cekmeceSayisi: m.code == ModuleCode.a3 ? widget.cekmeceSayisi : 0));
      var parts = engine.generateParts(instanceMod, mat);
      // Add instance suffix to labels
      parts = parts.map((p) => Part(
        moduleId: '${p.moduleId}-${modCounts[code]}',
        name: p.name, qty: p.qty,
        netWidthMm: p.netWidthMm, netLengthMm: p.netLengthMm,
        thicknessMm: p.thicknessMm, material: p.material, role: p.role,
        banding: p.banding, grainLocked: p.grainLocked,
        label: p.label?.replaceFirst(p.moduleId, '${p.moduleId}-${modCounts[code]}'),
      )).toList();
      _allParts.addAll(parts);
    }
    for (final m in ustPlacement.modules) {
      final code = m.code.name.toUpperCase();
      modCounts[code] = (modCounts[code] ?? 0) + 1;
      final instanceMod = m.toModule(720, 320, params: ModuleParams(
          rafSayisi: 2, camli: widget.camli));
      var parts = engine.generateParts(instanceMod, mat);
      parts = parts.map((p) => Part(
        moduleId: '${p.moduleId}-${modCounts[code]}',
        name: p.name, qty: p.qty,
        netWidthMm: p.netWidthMm, netLengthMm: p.netLengthMm,
        thicknessMm: p.thicknessMm, material: p.material, role: p.role,
        banding: p.banding, grainLocked: p.grainLocked,
        label: p.label?.replaceFirst(p.moduleId, '${p.moduleId}-${modCounts[code]}'),
      )).toList();
      _allParts.addAll(parts);
    }

    _hardware = {};
    for (final m in [...placement.modules, ...ustPlacement.modules]) {
      final mod = m.toModule(m.code.name.startsWith('u') ? 720 : 740, m.code.name.startsWith('u') ? 320 : 560);
      for (final e in engine.generateHardware(mod).entries) {
        _hardware[e.key] = (_hardware[e.key] ?? 0) + e.value;
      }
    }

    _sheets = optimizer.optimize(_allParts);
    // Sort sheets: govde → kapak → arkalik
    const roleOrder = ['govde', 'kapak', 'arkalik'];
    _sheets.sort((a, b) {
      final aRole = _allParts.firstWhere((p) => a.material == p.material,
          orElse: () => _allParts.first).role;
      final bRole = _allParts.firstWhere((p) => b.material == p.material,
          orElse: () => _allParts.first).role;
      return roleOrder.indexOf(aRole).compareTo(roleOrder.indexOf(bRole));
    });
    _bandingMetraj = BandingCalculator.totalMetrajWithFire(_allParts);

    final calc = cost.CostCalculator();
    _costReport = calc.calculate(
      allParts: _allParts, sheets: _sheets, hardware: _hardware,
      bodyMaterial: widget.govdeMalzeme, bodyColor: widget.govdeRenk,
      doorMaterial: widget.altKapakMalzeme, doorColor: widget.altKapakRenk,
      edgeBandThickness: 2,
      // Tezgah kaldirildi
    );
  }

  Future<void> _pdfIndir() async {
    try {
      final file = await SiparisFormuGenerator.generatePdf(
        allParts: _allParts, sheets: _sheets,
        projectName: widget.customerName, customerName: widget.customerName,
        outputPath: 'C:\\3matolye\\usta-yardimcisi\\siparis_${widget.customerName.replaceAll(' ', '_')}.pdf',
      );
      setState(() => _pdfPath = file.path);
      _mesaj('Siparis Formu PDF: ${file.path}');
    } catch (e) { _mesaj('PDF hatasi: $e', true); }
  }

  Future<void> _excelIndir() async {
    try {
      final file = await SiparisFormuGenerator.generateExcel(
        allParts: _allParts, sheets: _sheets, projectName: widget.customerName,
        outputPath: 'C:\\3matolye\\usta-yardimcisi\\siparis_${widget.customerName.replaceAll(' ', '_')}.xlsx',
      );
      setState(() => _excelPath = file.path);
      _mesaj('Siparis Formu Excel: ${file.path}');
    } catch (e) { _mesaj('Excel hatasi: $e', true); }
  }

  /// Parse Turkish material display name to enum.
  static MalzemeTip _parseMalzeme(String name) => switch (name) {
    'MDFlam' => MalzemeTip.mdflam, 'Suntalam' => MalzemeTip.suntalam,
    'MDF' => MalzemeTip.mdf, 'High Gloss' => MalzemeTip.highGloss,
    'Membran' => MalzemeTip.membran, 'Akrilik' => MalzemeTip.akrilik,
    _ => MalzemeTip.mdflam,
  };

  void _farkliEbatHesapla() {
    final totalParts = _allParts.fold<int>(0, (s, p) => s + p.qty);
    final avgWaste = _sheets.isEmpty ? 0.0
        : _sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / _sheets.length;
    // Save current summary for comparison
    setState(() {
      _oncekiOzet = 'Onceki: $_sheets.length plaka, $totalParts parca, %${avgWaste.toStringAsFixed(1)} fire';
    });

    // Show ebat dialog with current sizes, then recalculate
    _ebatDialog();
  }

  void _ebatDialog() {
    String govdeEbat = '${widget.govdePlateSize.widthMm.toInt()}×${widget.govdePlateSize.lengthMm.toInt()}';
    String kapakEbat = '${widget.kapakPlateSize.widthMm.toInt()}×${widget.kapakPlateSize.lengthMm.toInt()}';
    String arkalikEbat = '${widget.arkalikPlateSize.widthMm.toInt()}×${widget.arkalikPlateSize.lengthMm.toInt()}';

    final govdeOpts = ['2100×2800', '1830×3660'];
    final kapakOpts = ['2100×2800', '1830×3660', '1220×2800'];
    final arkalikOpts = ['2100×2800', '1830×3660'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Farkli Ebat Sec', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_oncekiOzet != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.amber.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                    child: Text(_oncekiOzet!, style: const TextStyle(fontSize: 14)),
                  ),
                Text('Govde', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...govdeOpts.map((e) => RadioListTile<String>(
                  title: Text(e, style: const TextStyle(fontSize: 18)),
                  value: e, groupValue: govdeEbat, onChanged: (v) => setDlg(() => govdeEbat = v!),
                )),
                const Divider(),
                Text('Kapak', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...kapakOpts.map((e) => RadioListTile<String>(
                  title: Text(e, style: const TextStyle(fontSize: 18)),
                  value: e, groupValue: kapakEbat, onChanged: (v) => setDlg(() => kapakEbat = v!),
                )),
                const Divider(),
                Text('Arkalik', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...arkalikOpts.map((e) => RadioListTile<String>(
                  title: Text(e, style: const TextStyle(fontSize: 18)),
                  value: e, groupValue: arkalikEbat, onChanged: (v) => setDlg(() => arkalikEbat = v!),
                )),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _hesaplaWithSizes(govdeEbat, kapakEbat, arkalikEbat);
                  });
                },
                child: const Text('TEKRAR HESAPLA', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hesaplaWithSizes(String govdeEbat, String kapakEbat, String arkalikEbat) {
    PlateSize parse(String s) {
      final parts = s.split('×');
      return PlateSize(widthMm: double.parse(parts[0]), lengthMm: double.parse(parts[1]));
    }
    final govdePS = parse(govdeEbat);
    final kapakPS = parse(kapakEbat);
    final arkalikPS = parse(arkalikEbat);

    _sheets = CutOptimizer(config: CutConfig(
      kerfMm: 4.8, trimMm: 10,
      materialSizes: {'govde': govdePS, 'kapak': kapakPS, 'arkalik': arkalikPS},
    )).optimize(_allParts);

    _bandingMetraj = BandingCalculator.totalMetrajWithFire(_allParts);
    final calc = cost.CostCalculator();
    _costReport = calc.calculate(
      allParts: _allParts, sheets: _sheets, hardware: _hardware,
      bodyMaterial: widget.govdeMalzeme, bodyColor: widget.govdeRenk,
      doorMaterial: widget.altKapakMalzeme, doorColor: widget.altKapakRenk,
      edgeBandThickness: 2,
    );
  }

  void _mesaj(String msg, [bool err = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: err ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final totalParts = _allParts.fold<int>(0, (s, p) => s + p.qty);
    final avgWaste = _sheets.isEmpty ? 0.0
        : _sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / _sheets.length;
    final metraj = BandingCalculator.calculateMetraj(_allParts);

    return Scaffold(
      appBar: AppBar(title: const Text('Kesim Sonucu'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            // Ozet satiri
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withAlpha(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniOzet('Plaka', '${_sheets.length}', Icons.grid_view),
                  _miniOzet('Fire', '%${avgWaste.toStringAsFixed(1)}', Icons.delete_outline),
                  _miniOzet('Parca', '$totalParts', Icons.category),
                  _miniOzet('Bant', '${_bandingMetraj.toStringAsFixed(0)}m', Icons.straighten),
                  _miniOzet('Teklif', _costReport.formattedCustomerPrice, Icons.payment),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _tabButton('Plaka Semasi', 0),
                  _tabButton('Malzeme Listesi', 1),
                  _tabButton('Indir', 2),
                ],
              ),
            ),

            // Tab icerik
            Expanded(child: _tabIcerik(totalParts, avgWaste, metraj)),
          ],
        ),
      ),
    );
  }

  Widget _miniOzet(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.blue[700]),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? Colors.blue : Colors.transparent, width: 3)),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.blue : Colors.grey[700])),
        ),
      ),
    );
  }

  // ─── Tab icerikleri ────────────────────────────────────────────────────

  Widget _tabIcerik(int totalParts, double avgWaste, Map<String, double> metraj) {
    return switch (_tab) {
      0 => _tabPlakaSemasi(),
      1 => _tabMalzemeListesi(metraj),
      2 => _tabIndir(),
      _ => const SizedBox(),
    };
  }

  // ─── TAB 0: Plaka Semasi ──────────────────────────────────────────────

  Widget _tabPlakaSemasi() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sheets.length,
      itemBuilder: (_, i) {
        final sheet = _sheets[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baslik
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Plaka ${i + 1}/${_sheets.length}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${sheet.widthMm.toInt()} × ${sheet.lengthMm.toInt()} mm',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                    Row(
                      children: [
                        Text('${sheet.partCount} parca',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sheet.wastePct <= 12 ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('%${sheet.wastePct.toStringAsFixed(1)} fire',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                  color: sheet.wastePct <= 12 ? Colors.green[800] : Colors.orange[800])),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Gorsel sema
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final scale = constraints.maxWidth / sheet.widthMm;
                    final h = sheet.lengthMm * scale;
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: h.clamp(100, 400),
                      child: CustomPaint(
                        painter: _SheetPainter(sheet: sheet, scale: scale),
                      ),
                    );
                  },
                ),
              ),

              // Parca listesi (bu plakadaki) — malzeme tipine gore renkli
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Wrap(spacing: 4, runSpacing: 4, children: sheet.partsPlaced.map((p) {
                  final borderColor = _materialColor(p.label, light: false);
                  final fillColor = _materialColor(p.label, light: true);
                  final parts = p.label.split('-');
                  final shortLabel = parts.length > 2 ? parts.sublist(1).join('-') : p.label;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text('$shortLabel ${p.widthMm.toInt()}×${p.lengthMm.toInt()}',
                        style: const TextStyle(fontSize: 10)),
                  );
                }).toList()),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TAB 1: Malzeme Listesi ──────────────────────────────────────────

  Widget _tabMalzemeListesi(Map<String, double> metraj) {
    final teklif = _teklifTutar > 0 ? _teklifTutar : (_marjYuzde > 0 ? _costReport.subtotal * (1 + _marjYuzde / 100) : 0.0);
    final teklifVat = teklif > 0 ? teklif * 0.20 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ═══ KESIM LISTESI (GRUPLU) ═══
        Text('Kesim Listesi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ..._buildGroupedCutList(),
        const Divider(height: 24),

        // ═══ PLAKALAR ═══
        _section('PLAKALAR', Icons.grid_view, Colors.blue),
        ..._sheets.asMap().entries.map((e) {
          final s = e.value;
          final platePrice = _costReport.lines
              .where((l) => l.unit == 'plaka' && s.material.contains(l.item.replaceAll(' plaka', '')))
              .fold<double>(0, (sum, l) => l.unitPrice);
          final priceText = platePrice > 0 ? '${platePrice.toInt()} TL' : '—';
          return Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              leading: CircleAvatar(radius: 16, backgroundColor: Colors.blue.withAlpha(25),
                  child: Text('${e.key + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
              title: Text(s.material, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: Text('${s.widthMm.toInt()}×${s.lengthMm.toInt()} mm  |  ${s.partCount} parca  |  Fire %${s.wastePct.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 13)),
              trailing: Text(priceText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          );
        }),
        const Divider(height: 24),

        // ═══ KENAR BANDI ═══
        _section('KENAR BANDI', Icons.straighten, Colors.purple),
        ..._costReport.lines
            .where((l) => l.item.contains('Kenar bandı'))
            .map((l) => ListTile(
              dense: true,
              title: Text(l.item, style: const TextStyle(fontSize: 14)),
              trailing: Text('${l.qty.toStringAsFixed(1)} m  ×  ${l.unitPrice.toInt()} TL  =  ${l.total.toInt()} TL',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            )),
        ..._costReport.lines
            .where((l) => l.item.contains('Bantlama isciligi'))
            .map((l) => ListTile(
              dense: true,
              title: Text(l.item, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
              trailing: Text('${l.qty.toStringAsFixed(1)} m  ×  ${l.unitPrice.toInt()} TL  =  ${l.total.toInt()} TL',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            )),
        const Divider(height: 24),

        // ═══ DONANIM ═══
        _section('DONANIM', Icons.build, Colors.teal),
        ..._hardware.entries.map((e) {
          final hwLine = _costReport.lines.where((l) => l.item == e.key ||
              l.item.contains(e.key)).firstOrNull;
          final birimFiyat = hwLine?.unitPrice ?? 0;
          final tutar = hwLine?.total ?? 0;
          return ListTile(
            dense: true,
            title: Text(e.key, style: const TextStyle(fontSize: 14)),
            trailing: Text('${e.value} adet  ×  ${birimFiyat.toInt()} TL  =  ${tutar.toInt()} TL',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          );
        }),
        const Divider(height: 24),

        // ═══ KESIM UCRETI ═══
        _section('KESIM UCRETI', Icons.cut, Colors.orange),
        ListTile(
          title: const Text('Plaka basi kesim', style: TextStyle(fontSize: 14)),
          trailing: Text('${_sheets.length} plaka  ×  100 TL  =  ${_sheets.length * 100} TL',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        const Divider(height: 24),

        // ═══ TOPLAM ═══
        Card(
          color: Colors.blue.withAlpha(12),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('TOPLAM', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                _toplamSatir('Ara Toplam (KDV haric)', _costReport.subtotal, size: 20),
                const SizedBox(height: 8),
                _toplamSatir('KDV (%20)', _costReport.vat, size: 18, color: Colors.grey[700]),
                const Divider(height: 24),
                _toplamSatir('GENEL TOPLAM', _costReport.total, bold: true, size: 24, color: Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ═══ TEKLIF ═══
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TEKLIF', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('Kar marji veya teklif tutari girin:', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _marjCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kar marji (%)',
                          hintText: 'ornek: 25',
                          suffixText: '%',
                          prefixIcon: Icon(Icons.percent, size: 24),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          setState(() {
                            _marjYuzde = double.tryParse(v) ?? 0;
                            _teklifTutar = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('veya', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Teklif Tutari',
                          hintText: 'ornek: 20000',
                          suffixText: 'TL',
                          prefixIcon: Icon(Icons.payment, size: 24),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          setState(() {
                            _teklifTutar = double.tryParse(v) ?? 0;
                            _marjYuzde = 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (teklif > 0) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  _toplamSatir('Teklif Tutari', teklif, bold: true, size: 22, color: Colors.blue),
                  _toplamSatir('KDV (%20)', teklifVat, size: 16, color: Colors.grey[700]),
                  const SizedBox(height: 4),
                  _toplamSatir('TEKLIF (KDV Dahil)', teklif + teklifVat, bold: true, size: 26, color: Colors.green),
                ] else
                  Text('Teklif: —', style: TextStyle(fontSize: 22, color: Colors.grey[400], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  /// Build cut list grouped by material (govde → kapak → arkalik).
  List<Widget> _buildGroupedCutList() {
    final groups = <String, List<Part>>{};
    for (final p in _allParts) {
      groups.putIfAbsent(p.material, () => []).add(p);
    }

    // Sort groups by role priority
    const roleOrder = ['govde', 'kapak', 'arkalik'];
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final aRole = groups[a]!.first.role;
        final bRole = groups[b]!.first.role;
        return roleOrder.indexOf(aRole).compareTo(roleOrder.indexOf(bRole));
      });

    final widgets = <Widget>[];
    for (final mat in sortedKeys) {
      final parts = groups[mat]!;
      final partCount = parts.fold<int>(0, (s, p) => s + p.qty);
      final totalM2 = parts.fold<double>(0, (s, p) =>
          s + (p.netWidthMm * p.netLengthMm / 1e6) * p.qty);

      widgets.add(Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Material header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _materialColor(mat, light: true),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(mat, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  Text('$partCount parca', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(width: 12),
                  Text('${totalM2.toStringAsFixed(2)} m²', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            // Parts in this group (compact)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Wrap(spacing: 4, runSpacing: 2, children: parts.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text('${p.name} ${p.cutWidthMm.toInt()}×${p.cutLengthMm.toInt()}',
                      style: const TextStyle(fontSize: 10)),
                );
              }).toList()),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }

  Widget _section(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  TableRow _tableHeader(List<String> headers) => TableRow(
    decoration: BoxDecoration(color: Colors.grey[200]),
    children: headers.map((h) => _cell(h, bold: true, size: 13)).toList(),
  );

  Widget _cell(String text, {bool bold = false, double size = 13, TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(text, textAlign: align,
          style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _toplamSatir(String label, double value, {bool bold = false, Color? color, double size = 18}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: size - 2, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('${value.toInt()} TL',
              style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }

  // ─── TAB 2: Indir ─────────────────────────────────────────────────────

  Widget _tabIndir() {
    final totalParts = _allParts.fold<int>(0, (s, p) => s + p.qty);
    final avgWaste = _sheets.isEmpty ? 0.0
        : _sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / _sheets.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Onceki hesaplama ozeti (varsa)
          if (_oncekiOzet != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Text(_oncekiOzet!, style: const TextStyle(fontSize: 15)),
            ),

          // Su anki ozet
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Bu hesaplama: $_sheets.length plaka, $totalParts parca, %${avgWaste.toStringAsFixed(1)} fire',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),

          // Farkli ebatla tekrar hesapla
          SizedBox(
            width: double.infinity, height: 56,
            child: OutlinedButton.icon(
              onPressed: _farkliEbatHesapla,
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text('Farkli Ebatla Tekrar Hesapla', style: TextStyle(fontSize: 18)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          Icon(Icons.download, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Raporlari Indir', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('PDF plaka semalari ve Excel kesim listesi',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 64,
            child: ElevatedButton.icon(
              onPressed: _pdfIndir,
              icon: const Icon(Icons.picture_as_pdf, size: 28),
              label: const Text('PDF — Kesim Plani', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 64,
            child: ElevatedButton.icon(
              onPressed: _excelIndir,
              icon: const Icon(Icons.table_chart, size: 28),
              label: const Text('Excel — Kesim Listesi', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
          if (_pdfPath != null || _excelPath != null) ...[
            const SizedBox(height: 24),
            if (_pdfPath != null)
              ListTile(leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(_pdfPath!, style: const TextStyle(fontSize: 12))),
            if (_excelPath != null)
              ListTile(leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(_excelPath!, style: const TextStyle(fontSize: 12))),
          ],
        ],
      ),
    );
  }
}

// ─── Custom Painter for Plate Schema ─────────────────────────────────────

Color _materialColor(String label, {bool light = true}) {
  // Color by material role from Part.role
  // The label contains role info embedded from Part
  // Fallback: parse from part name in label
  final parts = label.split('-');
  final name = parts.length > 2 ? parts[2] : '';

  // Arkalik
  if (label.contains('Arkalik') || name.startsWith('Ark')) {
    return light ? const Color(0xFFFFF3E0) : const Color(0xFFFFCC80); // orange
  }
  // Kapak/on yuzey
  if (label.contains('Kapak') || name.startsWith('Kap') || name.startsWith('Cek') ||
      name.startsWith('On panel') || name.startsWith('Gorunur') || name.startsWith('Kor') ||
      name.startsWith('Alt kap') || name.startsWith('Ust kap') || name.startsWith('Cam kap')) {
    return light ? const Color(0xFFE3F2FD) : const Color(0xFF90CAF9); // blue
  }
  // Govde
  return light ? const Color(0xFFE8F5E9) : const Color(0xFFA5D6A7); // green
}

class _SheetPainter extends CustomPainter {
  final SheetLayout sheet;
  final double scale;

  _SheetPainter({required this.sheet, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    // Sheet border
    final sheetRect = Rect.fromLTWH(0, 0, sheet.widthMm * scale, sheet.lengthMm * scale);
    canvas.drawRect(sheetRect, Paint()..color = Colors.grey[100]!..style = PaintingStyle.fill);
    canvas.drawRect(sheetRect, Paint()..color = Colors.grey[400]!..style = PaintingStyle.stroke..strokeWidth = 2);

    for (final p in sheet.partsPlaced) {
      final fillColor = _materialColor(p.label, light: true);
      final borderColor = _materialColor(p.label, light: false);
      final rect = Rect.fromLTWH(p.xMm * scale, p.yMm * scale, p.widthMm * scale, p.lengthMm * scale);

      // Fill with material color
      canvas.drawRect(rect, Paint()..color = fillColor..style = PaintingStyle.fill);
      // Border with darker shade
      canvas.drawRect(rect, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.5);

      // Material badge (small colored dot at top-left corner)
      final badgeColor = borderColor;
      canvas.drawCircle(
        Offset(p.xMm * scale + 6, p.yMm * scale + 6),
        4,
        Paint()..color = badgeColor..style = PaintingStyle.fill,
      );

      // Label
      final parts = p.label.split('-');
      final shortLabel = parts.length > 2
          ? '${parts[1]}-${parts[2]}'
          : p.label;
      final tp = TextPainter(
        text: TextSpan(text: shortLabel, style: TextStyle(color: Colors.black87, fontSize: (9 * scale).clamp(6, 11), fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      );
      tp.layout(maxWidth: p.widthMm * scale - 8);
      if (p.lengthMm * scale > 16 && p.widthMm * scale > 30) {
        tp.paint(canvas, Offset(p.xMm * scale + 12, p.yMm * scale + 2));
      }

      // Dimensions
      final dimText = '${p.widthMm.toInt()}×${p.lengthMm.toInt()}';
      final dtp = TextPainter(
        text: TextSpan(text: dimText, style: TextStyle(color: Colors.black54, fontSize: (7 * scale).clamp(5, 9))),
        textDirection: TextDirection.ltr,
      );
      dtp.layout();
      if (p.lengthMm * scale > dtp.height + 14) {
        dtp.paint(canvas, Offset(p.xMm * scale + 2, p.yMm * scale + p.lengthMm * scale - dtp.height - 2));
      }
    }

    // Legend at bottom-right
    final legends = [
      ('Kapak', const Color(0xFF90CAF9)),
      ('Govde', const Color(0xFFA5D6A7)),
      ('Arkalik', const Color(0xFFFFCC80)),
    ];
    var ly = size.height - 56.0;
    for (final (label, color) in legends) {
      canvas.drawCircle(Offset(size.width - 80, ly + 6), 5, Paint()..color = color..style = PaintingStyle.fill);
      final ltp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.black54, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      ltp.layout();
      ltp.paint(canvas, Offset(size.width - 70, ly));
      ly += 18;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
