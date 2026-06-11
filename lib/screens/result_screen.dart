/// Kesim Sonucu Ekrani — Gercek raporlari gosterir.
/// Modul motoru + kesim optimizasyonu + maliyet hesaplama.

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../modules/module_engine.dart';
import '../modules/placement_engine.dart';
import '../modules/cut_optimizer.dart';
import '../services/report_service.dart';
import '../models/project.dart';
import '../services/cost_service.dart' as cost;

class ResultScreen extends StatefulWidget {
  final double wallLengthMm;
  final String govdeMalzeme;
  final String govdeRenk;
  final String altKapakMalzeme;
  final String altKapakRenk;
  final String ustKapakMalzeme;
  final String ustKapakRenk;
  final String tezgahTipi;
  final int cekmeceSayisi;
  final bool camli;
  final String kulpTipi;
  final String customerName;

  const ResultScreen({
    super.key,
    required this.wallLengthMm,
    required this.govdeMalzeme,
    required this.govdeRenk,
    required this.altKapakMalzeme,
    required this.altKapakRenk,
    required this.ustKapakMalzeme,
    required this.ustKapakRenk,
    required this.tezgahTipi,
    required this.cekmeceSayisi,
    required this.camli,
    required this.kulpTipi,
    required this.customerName,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _loading = true;
  String? _pdfPath;
  String? _excelPath;

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
    final engine = ModuleEngine();
    final optimizer = CutOptimizer();

    // Basit modul yerlesimi (duvar uzunluguna gore)
    final placement = PlacementEngine.placeLower(PlacementInput(
      wallLengthMm: widget.wallLengthMm, isLower: true));
    final ustPlacement = PlacementEngine.placeUpper(PlacementInput(
      wallLengthMm: widget.wallLengthMm, isLower: false));

    final mat = MaterialSpec();
    _allParts = [];

    // Alt modullerden parca uret
    for (final m in placement.modules) {
      final mod = m.toModule(740, 560, params: ModuleParams(
        rafSayisi: m.code == ModuleCode.a3 ? 0 : 1,
        cekmeceSayisi: m.code == ModuleCode.a3 ? widget.cekmeceSayisi : 0,
      ));
      _allParts.addAll(engine.generateParts(mod, mat));
    }

    // Ust modullerden parca uret
    for (final m in ustPlacement.modules) {
      final mod = m.toModule(720, 320, params: ModuleParams(
        rafSayisi: 2,
        camli: widget.camli,
      ));
      _allParts.addAll(engine.generateParts(mod, mat));
    }

    // Donanim
    _hardware = {};
    for (final m in placement.modules) {
      final mod = m.toModule(740, 560);
      final hw = engine.generateHardware(mod);
      for (final e in hw.entries) {
        _hardware[e.key] = (_hardware[e.key] ?? 0) + e.value;
      }
    }
    for (final m in ustPlacement.modules) {
      final mod = m.toModule(720, 320);
      final hw = engine.generateHardware(mod);
      for (final e in hw.entries) {
        _hardware[e.key] = (_hardware[e.key] ?? 0) + e.value;
      }
    }

    // Optimize
    _sheets = optimizer.optimize(_allParts);

    // Bant metraj
    _bandingMetraj = BandingCalculator.totalMetrajWithFire(_allParts);

    // Maliyet
    final costCalc = cost.CostCalculator();
    _costReport = costCalc.calculate(
      allParts: _allParts,
      sheets: _sheets,
      hardware: _hardware,
      bodyMaterial: widget.govdeMalzeme,
      bodyColor: widget.govdeRenk,
      doorMaterial: widget.altKapakMalzeme,
      doorColor: widget.altKapakRenk,
      edgeBandThickness: 2,
      countertopType: 'Tezgah ${widget.tezgahTipi.toLowerCase()}',
      countertopLengthMtul: widget.wallLengthMm / 1000,
      wallLengthMtul: widget.wallLengthMm / 1000,
    );
  }

  Future<void> _pdfIndir() async {
    try {
      final file = await PdfReportGenerator.generate(
        sheets: _sheets,
        allParts: _allParts,
        projectName: widget.customerName,
        customerName: widget.customerName,
        outputPath: 'C:\\3matolye\\usta-yardimcisi\\kesim_plani_${widget.customerName.replaceAll(' ', '_')}.pdf',
      );
      setState(() => _pdfPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF kaydedildi: ${file.path}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF hatasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _excelIndir() async {
    try {
      final file = await ExcelReportGenerator.generate(
        allParts: _allParts,
        sheets: _sheets,
        projectName: widget.customerName,
        outputPath: 'C:\\3matolye\\usta-yardimcisi\\kesim_listesi_${widget.customerName.replaceAll(' ', '_')}.xlsx',
      );
      setState(() => _excelPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel kaydedildi: ${file.path}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel hatasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalParts = _allParts.fold<int>(0, (s, p) => s + p.qty);
    final avgWaste = _sheets.isEmpty ? 0.0
        : _sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / _sheets.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kesim Sonucu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Baslik
            Text('${widget.customerName} — Kesim Plani',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Ozet kartlari
            Row(
              children: [
                _ozetKart('Plaka', '${_sheets.length} adet', Icons.grid_view, Colors.blue),
                const SizedBox(width: 12),
                _ozetKart('Fire', '%${avgWaste.toStringAsFixed(1)}', Icons.delete_outline,
                    avgWaste <= 12 ? Colors.green : Colors.orange),
                const SizedBox(width: 12),
                _ozetKart('Parca', '$totalParts', Icons.category, Colors.teal),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ozetKart('Bant', '${_bandingMetraj.toStringAsFixed(1)} m', Icons.straighten, Colors.purple),
                const SizedBox(width: 12),
                _ozetKart('Maliyet', _costReport.formattedCustomerPrice, Icons.payment, Colors.red),
              ],
            ),
            const SizedBox(height: 24),

            // Plaka detay
            Text('Plaka Detayi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...(_sheets.asMap().entries.map((e) {
              final s = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(25),
                    child: Text('${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${s.widthMm.toInt()}×${s.lengthMm.toInt()} mm — ${s.partCount} parca'),
                  subtitle: Text('Fire: %${s.wastePct.toStringAsFixed(1)}'),
                  trailing: s.wastePct <= 12
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.warning, color: Colors.orange),
                ),
              );
            })),
            const SizedBox(height: 16),

            // Donanim listesi
            if (_hardware.isNotEmpty) ...[
              Text('Donanim', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(spacing: 12, runSpacing: 6, children:
                    _hardware.entries.map((e) => Chip(
                      avatar: CircleAvatar(backgroundColor: Colors.grey[200], child: Text('${e.value}')),
                      label: Text(e.key, style: const TextStyle(fontSize: 14)),
                    )).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Maliyet ozeti
            Text('Maliyet Ozeti', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _maliyetSatir('Toplam Maliyet', _costReport.subtotal.toStringAsFixed(0), false),
                    _maliyetSatir('Kar (%${_costReport.marginPct.toInt()})',
                        ( _costReport.customerPrice - _costReport.subtotal).toStringAsFixed(0), false),
                    const Divider(),
                    _maliyetSatir('Teklif Fiyati', _costReport.formattedCustomerPrice, true),
                    _maliyetSatir('KDV Dahil Toplam', _costReport.formattedTotal, true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Indirme butonlari
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pdfIndir,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF Indir'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _excelIndir,
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Excel Indir'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kayit bilgisi
            if (_pdfPath != null)
              Card(
                color: Colors.green.withAlpha(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('PDF: $_pdfPath', style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            if (_excelPath != null)
              Card(
                color: Colors.green.withAlpha(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Excel: $_excelPath', style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _ozetKart(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _maliyetSatir(String label, String value, bool bold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('$value TL', style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
