/// Kesim Sonucu Ekrani — Plaka semalari + detayli malzeme listesi + maliyet.

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../modules/module_engine.dart';
import '../modules/placement_engine.dart';
import '../modules/cut_optimizer.dart';
import '../services/report_service.dart';
import '../services/cost_service.dart' as cost;

class ResultScreen extends StatefulWidget {
  final double wallLengthMm;
  final String govdeMalzeme, govdeRenk;
  final String altKapakMalzeme, altKapakRenk;
  final String ustKapakMalzeme, ustKapakRenk;
  final String tezgahTipi, kulpTipi, customerName;
  final int cekmeceSayisi;
  final bool camli;

  const ResultScreen({
    super.key, required this.wallLengthMm,
    required this.govdeMalzeme, required this.govdeRenk,
    required this.altKapakMalzeme, required this.altKapakRenk,
    required this.ustKapakMalzeme, required this.ustKapakRenk,
    required this.tezgahTipi, required this.kulpTipi, required this.customerName,
    required this.cekmeceSayisi, required this.camli,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _tab = 0;
  String? _pdfPath, _excelPath;

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

    final placement = PlacementEngine.placeLower(PlacementInput(
        wallLengthMm: widget.wallLengthMm, isLower: true));
    final ustPlacement = PlacementEngine.placeUpper(PlacementInput(
        wallLengthMm: widget.wallLengthMm, isLower: false));

    _allParts = [];
    for (final m in placement.modules) {
      _allParts.addAll(engine.generateParts(m.toModule(740, 560, params: ModuleParams(
          rafSayisi: m.code == ModuleCode.a3 ? 0 : 1,
          cekmeceSayisi: m.code == ModuleCode.a3 ? widget.cekmeceSayisi : 0)), MaterialSpec()));
    }
    for (final m in ustPlacement.modules) {
      _allParts.addAll(engine.generateParts(m.toModule(720, 320, params: ModuleParams(
          rafSayisi: 2, camli: widget.camli)), MaterialSpec()));
    }

    _hardware = {};
    for (final m in [...placement.modules, ...ustPlacement.modules]) {
      final mod = m.toModule(m.code.name.startsWith('u') ? 720 : 740, m.code.name.startsWith('u') ? 320 : 560);
      for (final e in engine.generateHardware(mod).entries) {
        _hardware[e.key] = (_hardware[e.key] ?? 0) + e.value;
      }
    }

    _sheets = optimizer.optimize(_allParts);
    _bandingMetraj = BandingCalculator.totalMetrajWithFire(_allParts);

    final calc = cost.CostCalculator();
    _costReport = calc.calculate(
      allParts: _allParts, sheets: _sheets, hardware: _hardware,
      bodyMaterial: widget.govdeMalzeme, bodyColor: widget.govdeRenk,
      doorMaterial: widget.altKapakMalzeme, doorColor: widget.altKapakRenk,
      edgeBandThickness: 2,
      countertopType: 'Tezgah ${widget.tezgahTipi.toLowerCase()}',
      countertopLengthMtul: widget.wallLengthMm / 1000,
    );
  }

  Future<void> _pdfIndir() async {
    try {
      final file = await PdfReportGenerator.generate(
        sheets: _sheets, allParts: _allParts,
        projectName: widget.customerName, customerName: widget.customerName,
        outputPath: 'C:\\3matolye\\usta-yardimcisi\\kesim_plani_${widget.customerName.replaceAll(' ', '_')}.pdf',
      );
      setState(() => _pdfPath = file.path);
      _mesaj('PDF kaydedildi: ${file.path}');
    } catch (e) { _mesaj('PDF hatasi: $e', true); }
  }

  Future<void> _excelIndir() async {
    try {
      final file = await ExcelReportGenerator.generate(
        allParts: _allParts, sheets: _sheets, projectName: widget.customerName,
        outputPath: 'C:\\3matolye\\usta-yardimcisi\\kesim_listesi_${widget.customerName.replaceAll(' ', '_')}.xlsx',
      );
      setState(() => _excelPath = file.path);
      _mesaj('Excel kaydedildi: ${file.path}');
    } catch (e) { _mesaj('Excel hatasi: $e', true); }
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- MALZEME LISTESI ---
        Text('Malzeme Listesi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // Plakalar
        _section('Plakalar', Icons.grid_view, Colors.blue),
        ..._sheets.asMap().entries.map((e) {
          final s = e.value;
          return ListTile(
            dense: true,
            leading: CircleAvatar(radius: 14, backgroundColor: Colors.blue.withAlpha(25),
                child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            title: Text('${s.widthMm.toInt()}×${s.lengthMm.toInt()} mm', style: const TextStyle(fontSize: 15)),
            subtitle: Text('${s.partCount} parca — Fire %${s.wastePct.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 13)),
          );
        }),
        const Divider(height: 24),

        // Bant
        _section('Kenar Bandi', Icons.straighten, Colors.purple),
        ...metraj.entries.map((e) => ListTile(
          dense: true, title: Text(e.key, style: const TextStyle(fontSize: 15)),
          trailing: Text('${e.value.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        )),
        ListTile(dense: true,
          title: const Text('TOPLAM (+%10 fire)', style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text('${_bandingMetraj.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
        ),
        const Divider(height: 24),

        // Donanim
        _section('Donanim', Icons.build, Colors.teal),
        ..._hardware.entries.map((e) => ListTile(
          dense: true, title: Text(e.key, style: const TextStyle(fontSize: 15)),
          trailing: Text('${e.value} adet', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        )),
        const Divider(height: 24),

        // Tezgah
        _section('Tezgah', Icons.table_bar, Colors.brown),
        ListTile(dense: true,
          title: Text('Tezgah ${widget.tezgahTipi}', style: const TextStyle(fontSize: 15)),
          trailing: Text('${(widget.wallLengthMm / 1000).toStringAsFixed(1)} mtul', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const Divider(height: 24),

        // --- MALIYET DETAYI ---
        Text('Maliyet Detayi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1)},
              children: [
                _tableHeader(['Kalem', 'Miktar', 'Birim Fiyat', 'Tutar']),
                ..._costReport.lines.map((l) => TableRow(
                  children: [
                    _cell(l.item, align: TextAlign.left),
                    _cell('${l.qty.toStringAsFixed(l.unit == 'm' ? 1 : 0)} ${l.unit}'),
                    _cell('${l.unitPrice.toInt()} TL'),
                    _cell('${l.total.toInt()} TL', bold: true),
                  ],
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Toplam
        Card(
          color: Colors.blue.withAlpha(15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _toplamSatir('Ara Toplam', _costReport.subtotal),
                _toplamSatir('Kar (%${_costReport.marginPct.toInt()})', _costReport.customerPrice - _costReport.subtotal),
                const Divider(),
                _toplamSatir('Teklif Fiyati', _costReport.customerPrice, bold: true, color: Colors.blue),
                _toplamSatir('KDV Dahil', _costReport.total, color: Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
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

  Widget _toplamSatir(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('${value.toInt()} TL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }

  // ─── TAB 2: Indir ─────────────────────────────────────────────────────

  Widget _tabIndir() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.download, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Raporlari Indir', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('PDF plaka semalari ve Excel kesim listesi',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 32),
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
  // label format: P-MODUL-ParcaAdi-idx/count
  final parts = label.split('-');
  final name = parts.length > 2 ? parts[2] : '';
  final modul = parts.length > 1 ? parts[1] : '';

  // Arkalik parts
  if (name.startsWith('Ark')) {
    return light ? const Color(0xFFFFF3E0) : const Color(0xFFFFCC80); // orange
  }
  // Door/front parts
  if (name.startsWith('Kap') || name.startsWith('Cek') || name.startsWith('On panel') ||
      name.startsWith('Gorunur') || name.startsWith('Kor') || name.startsWith('Alt kap') || name.startsWith('Ust kap') ||
      name.startsWith('Cam kap')) {
    return light ? const Color(0xFFE3F2FD) : const Color(0xFF90CAF9); // blue
  }
  // Body parts
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
