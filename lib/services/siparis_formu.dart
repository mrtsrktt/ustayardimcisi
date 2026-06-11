/// Kesimci Siparis Formu — marangozlarin kullandigi gercek format.
/// Malzeme basina ayri sayfa, cm cinsinden, konsolide satirlar.

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../models/project.dart';
import '../modules/cut_optimizer.dart';

// ─── Siparis Satiri (konsolide) ────────────────────────────────────────────

class _SiparisRow {
  final double boyCm;
  final double enCm;
  int adet;
  final List<bool> bant; // [on, arka, sol, sag]
  final String renk;     // "Govde" | "Kapak"

  _SiparisRow({
    required this.boyCm,
    required this.enCm,
    required this.adet,
    required this.bant,
    required this.renk,
  });

  String get key => '${boyCm.toStringAsFixed(1)}_${enCm.toStringAsFixed(1)}_${bant.join()}_$renk';

  double get alanCm2 => boyCm * enCm;
}

// ─── Siparis Formu Generator ─────────────────────────────────────────────

class SiparisFormuGenerator {
  /// Generate PDF with per-material siparis formu pages + plate schemas.
  static Future<File> generatePdf({
    required List<Part> allParts,
    required List<SheetLayout> sheets,
    required String projectName,
    required String customerName,
    String? outputPath,
  }) async {
    final pdf = pw.Document();

    // Group parts by material
    final matGroups = <String, List<Part>>{};
    for (final p in allParts) {
      matGroups.putIfAbsent(p.material, () => []).add(p);
    }

    // Sort: govde → kapak → arkalik
    const roleOrder = ['govde', 'kapak', 'arkalik'];
    final sortedMats = matGroups.keys.toList()
      ..sort((a, b) => roleOrder.indexOf(matGroups[a]!.first.role)
          .compareTo(roleOrder.indexOf(matGroups[b]!.first.role)));

    // Siparis formu pages (one per material)
    for (final mat in sortedMats) {
      final parts = matGroups[mat]!;
      final rows = consolidate(parts);
      final sheetSize = _findSheetSize(sheets, mat);
      final totalAdet = rows.fold<int>(0, (s, r) => s + r.adet);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (ctx) => [
          // Header
          pw.Header(level: 0, text: 'KESIMCI SIPARIS FORMU',
              textStyle: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Malzeme: $mat', style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Plaka: $sheetSize', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Proje: $projectName', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Tarih: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Musteri: $customerName', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Toplam: $totalAdet parca', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.SizedBox(height: 8),

          // Table
          pw.TableHelper.fromTextArray(
            headers: ['NO', 'BOY (cm)', 'EN (cm)', 'ADET', 'B|B|E|E', 'RENK'],
            data: rows.asMap().entries.map((e) {
              final r = e.value;
              // Furkan standard: 4 fixed boxes B|B|E|E (Boy×2, En×2)
              final bantStr = '${r.bant[0]?"X":"."} ${r.bant[1]?"X":"."} ${r.bant[2]?"X":"."} ${r.bant[3]?"X":"."}';
              return [
                '${e.key + 1}',
                r.boyCm.toStringAsFixed(1),
                r.enCm.toStringAsFixed(1),
                '${r.adet}',
                bantStr,
                r.renk,
              ];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FixedColumnWidth(50),
              2: const pw.FixedColumnWidth(50),
              3: const pw.FixedColumnWidth(30),
              4: const pw.FixedColumnWidth(55),
              5: const pw.FixedColumnWidth(45),
            },
          ),
          pw.SizedBox(height: 12),

          // Bant Ozeti (sadece bu malzeme icin)
          pw.Header(level: 2, text: 'Bant Ozeti', textStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ..._buildBantOzeti(parts).map((row) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(row[0], style: const pw.TextStyle(fontSize: 9)),
                pw.Text(row[1], style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          )).toList(),
        ],
      ));
    }

    // Plate schema pages (keep existing)
    for (var i = 0; i < sheets.length; i++) {
      final sheet = sheets[i];
      final pageW = PdfPageFormat.a4.width - 40;
      final maxDrawingH = PdfPageFormat.a4.height - 200;
      final sheetH = pageW * (sheet.lengthMm / sheet.widthMm);
      final scale = sheetH > maxDrawingH ? maxDrawingH / sheetH : 1.0;
      final drawingW = pageW * scale;
      final drawingH = sheetH * scale;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 1, text: 'Plaka ${i + 1}/${sheets.length} - ${sheet.material}'),
          pw.Paragraph(text: '${sheet.widthMm.toInt()}x${sheet.lengthMm.toInt()} mm | ${sheet.partCount} parca | Fire: %${sheet.wastePct.toStringAsFixed(1)}'),
          pw.Paragraph(text: 'Malzeme: ${sheet.material} | Parca: ${sheet.partCount} adet',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Container(
            width: drawingW, height: drawingH,
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Stack(
              children: sheet.partsPlaced.map((p) {
                final rScale = drawingW / sheet.widthMm;
                return pw.Positioned(
                  left: p.xMm * rScale, top: p.yMm * rScale,
                  child: pw.Container(
                    width: p.widthMm * rScale, height: p.lengthMm * rScale,
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey100),
                    child: pw.Center(
                      child: pw.Text(p.label.split('-').last, style: pw.TextStyle(fontSize: (6 * rScale).clamp(4, 8))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Etiket', 'En (mm)', 'Boy (mm)'],
            data: sheet.partsPlaced.map((p) => [
              p.label, p.widthMm.toStringAsFixed(0), p.lengthMm.toStringAsFixed(0),
            ]).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ));
    }

    final outputFile = outputPath != null ? File(outputPath) : File('siparis_formu_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  /// Generate Excel with per-material sheets.
  static Future<File> generateExcel({
    required List<Part> allParts,
    required List<SheetLayout> sheets,
    required String projectName,
    String? outputPath,
  }) async {
    final excel = Excel.createExcel();

    final matGroups = <String, List<Part>>{};
    for (final p in allParts) {
      matGroups.putIfAbsent(p.material, () => []).add(p);
    }

    const roleOrder = ['govde', 'kapak', 'arkalik'];
    final sortedMats = matGroups.keys.toList()
      ..sort((a, b) => roleOrder.indexOf(matGroups[a]!.first.role)
          .compareTo(roleOrder.indexOf(matGroups[b]!.first.role)));

    for (final mat in sortedMats) {
      final sheetName = mat.length > 25 ? mat.substring(0, 25) : mat;
      final sheet = excel[sheetName];
      final parts = matGroups[mat]!;
      final rows = consolidate(parts);

      // Header info
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('KESIMCI SIPARIS FORMU') ..cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Malzeme: $mat');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        ..value = TextCellValue('Proje: $projectName  Tarih: ${DateTime.now().toString().substring(0, 10)}');

      // Table headers
      final headers = ['NO', 'BOY (cm)', 'EN (cm)', 'ADET', 'B|B|E|E', 'RENK'];
      for (var c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4))
          ..value = TextCellValue(headers[c]) ..cellStyle = CellStyle(bold: true);
      }

      var row = 5;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final bantStr = '${r.bant[0]?"✓":"·"} ${r.bant[1]?"✓":"·"} ${r.bant[2]?"✓":"·"} ${r.bant[3]?"✓":"·"}';
        final vals = [i + 1, r.boyCm.toStringAsFixed(1), r.enCm.toStringAsFixed(1), r.adet, bantStr, r.renk];
        for (var c = 0; c < vals.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
            ..value = TextCellValue(vals[c].toString());
        }
        row++;
      }
    }

    final outputFile = outputPath != null ? File(outputPath) : File('siparis_formu_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) await outputFile.writeAsBytes(bytes);
    return outputFile;
  }

  // ─── Consolidation ──────────────────────────────────────────────────────

  /// Consolidate parts: same (en,boy) + same band pattern → single row, adet++
  static List<_SiparisRow> consolidate(List<Part> parts) {
    final map = <String, _SiparisRow>{};
    for (final p in parts) {
      for (var q = 0; q < p.qty; q++) {
        // Convert mm → cm with 1 decimal
        final boyCm = p.cutLengthMm / 10.0; // BOY = length
        final enCm = p.cutWidthMm / 10.0;   // EN = width
        final bant = [
          p.banding[0] > 0, // on
          p.banding[1] > 0, // arka
          p.banding[2] > 0, // sol
          p.banding[3] > 0, // sag
        ];
        final renk = p.role == 'kapak' ? 'Kapak' : 'Govde';
        final row = _SiparisRow(boyCm: boyCm, enCm: enCm, adet: 1, bant: bant, renk: renk);
        if (map.containsKey(row.key)) {
          map[row.key]!.adet++;
        } else {
          map[row.key] = row;
        }
      }
    }
    // Sort largest to smallest by area
    final list = map.values.toList()..sort((a, b) => b.alanCm2.compareTo(a.alanCm2));
    return list;
  }

  /// Find sheet size for a material from sheet list.
  static String _findSheetSize(List<SheetLayout> sheets, String material) {
    for (final s in sheets) {
      if (s.material == material) {
        return '${s.widthMm.toInt()}x${s.lengthMm.toInt()} mm';
      }
    }
    return '2100x2800 mm';
  }

  /// Build bant ozeti for a material group.
  static List<List<String>> _buildBantOzeti(List<Part> parts) {
    final groups = <String, double>{};
    for (final p in parts) {
      for (var e = 0; e < 4; e++) {
        if (p.banding[e] > 0) {
          final key = '${p.role == "kapak" ? "Kapak" : "Govde"} ${p.banding[e]}mm';
          final length = e <= 1 ? p.netWidthMm : p.netLengthMm;
          groups[key] = (groups[key] ?? 0) + length * p.qty / 1000;
        }
      }
    }
    return groups.entries.map((e) => [
      e.key, '${e.value.toStringAsFixed(1)} m (+%10: ${(e.value * 1.1).toStringAsFixed(1)} m)',
    ]).toList();
  }
}
