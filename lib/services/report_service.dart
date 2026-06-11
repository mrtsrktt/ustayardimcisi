/// PDF and Excel report generator for MarangozAI.
///
/// Generates:
/// - PDF: plate schemas with labeled parts + cut list + banding summary
/// - Excel: cut list in format suitable for cutting shops

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import '../models/project.dart';
import '../modules/cut_optimizer.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

pw.TextStyle _headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
pw.TextStyle _cellStyle = pw.TextStyle(fontSize: 8);

// ─── PDF Generator ───────────────────────────────────────────────────────────

class PdfReportGenerator {
  /// Generate a complete PDF report with plate schemas and cut lists.
  static Future<File> generate({
    required List<SheetLayout> sheets,
    required List<Part> allParts,
    required String projectName,
    required String customerName,
    String? outputPath,
  }) async {
    final pdf = pw.Document();

    // Title page
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(level: 0, text: 'Kesim Plani'),
        pw.Paragraph(text: 'Proje: $projectName'),
        pw.Paragraph(text: 'Musteri: $customerName'),
        pw.Paragraph(text: 'Tarih: ${DateTime.now().toString().substring(0, 10)}'),
        pw.SizedBox(height: 20),
        pw.Header(level: 1, text: 'Ozet'),
        _buildTable(
          headers: ['Toplam Plaka', 'Fire %', 'Parca Sayisi'],
          rows: [[
            '${sheets.length}',
            '%${sheets.isEmpty ? 0 : (sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / sheets.length).toStringAsFixed(1)}',
            '${sheets.fold(0, (s, sh) => s + sh.partCount)}',
          ]],
        ),
      ],
    ));

    // Plate schema pages
    final pageW = PdfPageFormat.a4.width - 40;
    final maxDrawingH = PdfPageFormat.a4.height - 200; // leave room for header + table
    for (var i = 0; i < sheets.length; i++) {
      final sheet = sheets[i];
      final scale = (pageW * (sheet.lengthMm / sheet.widthMm) > maxDrawingH)
          ? maxDrawingH / (pageW * (sheet.lengthMm / sheet.widthMm))
          : 1.0;
      final drawingW = pageW * scale;
      final drawingH = pageW * (sheet.lengthMm / sheet.widthMm) * scale;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 1, text: 'Plaka ${i + 1}/${sheets.length} - ${sheet.material}'),
          pw.Paragraph(text: '${sheet.widthMm.toInt()}×${sheet.lengthMm.toInt()} mm | ${sheet.partCount} parca | Fire: %${sheet.wastePct.toStringAsFixed(1)}'),
          pw.Paragraph(
            text: 'Malzeme: ${sheet.material} | Parca: ${sheet.partCount} adet',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          // Plate drawing
          pw.Container(
            width: drawingW,
            height: drawingH,
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Stack(
              children: sheet.partsPlaced.map((p) {
                final rScale = drawingW / sheet.widthMm;
                return pw.Positioned(
                  left: p.xMm * rScale,
                  top: p.yMm * rScale,
                  child: pw.Container(
                    width: p.widthMm * rScale,
                    height: p.lengthMm * rScale,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Center(
                      child: pw.Text(p.label.split('-').last,
                          style: pw.TextStyle(fontSize: (6 * rScale).clamp(4, 8))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 10),
          _buildTable(
            headers: ['Etiket', 'En (mm)', 'Boy (mm)', 'Dondu'],
            rows: sheet.partsPlaced.map((p) => [
              p.label, p.widthMm.toStringAsFixed(0),
              p.lengthMm.toStringAsFixed(0),
              p.rotated ? 'Evet' : 'Hayir',
            ]).toList(),
          ),
        ],
      ));
    }

    // Full cut list (landscape)
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (ctx) => [
        pw.Header(level: 1, text: 'Kesim Listesi'),
        _buildTable(
          headers: ['Sira', 'Modul', 'Parca', 'Adet', 'KESIM EN', 'KESIM BOY',
            'Kalinlik', 'Malzeme', 'Bant (O/A/S/Sg)', 'Etiket'],
          rows: _buildCutListRows(allParts),
        ),
      ],
    ));

    // Banding list
    final bandingRows = _buildBandingRows(allParts);
    if (bandingRows.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 1, text: 'Bantlama Listesi'),
          _buildTable(
            headers: ['Etiket', 'Parca', 'Kenar', 'Uzunluk (m)', 'Bant (mm)', 'Renk'],
            rows: bandingRows,
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: 'Bant Ozeti'),
          _buildTable(
            headers: ['Renk + Kalinlik', 'Toplam (m)', '+%10 Fire (m)'],
            rows: _buildBandingSummary(allParts),
          ),
        ],
      ));
    }

    final outputFile = outputPath != null
        ? File(outputPath)
        : File('kesim_plani_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(),
      headerStyle: _headerStyle,
      cellStyle: _cellStyle,
    );
  }

  static List<List<String>> _buildCutListRows(List<Part> parts) {
    // Group parts by material for grouped output
    final groups = <String, List<Part>>{};
    for (final p in parts) {
      groups.putIfAbsent(p.material, () => []).add(p);
    }
    // Sort groups: govde → kapak → arkalik
    const roleOrder = ['govde', 'kapak', 'arkalik'];
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => roleOrder.indexOf(groups[a]!.first.role)
          .compareTo(roleOrder.indexOf(groups[b]!.first.role)));

    final rows = <List<String>>[];
    var sira = 1;
    for (final mat in sortedKeys) {
      final matParts = groups[mat]!;
      final partCount = matParts.fold<int>(0, (s, p) => s + p.qty);
      final totalM2 = matParts.fold<double>(0, (s, p) =>
          s + (p.netWidthMm * p.netLengthMm / 1e6) * p.qty);
      // Group header row
      rows.add(['── $mat — $partCount parca, ${totalM2.toStringAsFixed(2)} m² ──',
        '', '', '', '', '', '', '', '', '']);

      for (final p in matParts) {
        for (var q = 0; q < p.qty; q++) {
          rows.add([
            '$sira', p.moduleId, p.name, '1',
            p.cutWidthMm.toStringAsFixed(0),
            p.cutLengthMm.toStringAsFixed(0),
            '${p.thicknessMm.toInt()}',
            p.material,
            '${p.banding[0].toInt()}/${p.banding[1].toInt()}/${p.banding[2].toInt()}/${p.banding[3].toInt()}',
            p.label ?? '-',
          ]);
          sira++;
        }
      }
    }
    return rows;
  }

  static List<List<String>> _buildBandingRows(List<Part> parts) {
    final rows = <List<String>>[];
    const edges = ['On', 'Arka', 'Sol', 'Sag'];
    for (final p in parts) {
      for (var e = 0; e < 4; e++) {
        if (p.banding[e] > 0) {
          final length = e <= 1 ? p.netWidthMm : p.netLengthMm;
          rows.add([
            p.label ?? '-', p.name, edges[e],
            (length / 1000).toStringAsFixed(2),
            p.banding[e].toStringAsFixed(1),
            p.role == 'kapak' ? 'Kapak rengi' : 'Govde rengi',
          ]);
        }
      }
    }
    return rows;
  }

  static List<List<String>> _buildBandingSummary(List<Part> parts) {
    final groups = <String, double>{};
    for (final p in parts) {
      for (var e = 0; e < 4; e++) {
        if (p.banding[e] > 0) {
          final key = '${p.role == "kapak" ? "Kapak" : "Govde"} ${p.banding[e]}mm';
          final length = e <= 1 ? p.netWidthMm : p.netLengthMm;
          groups[key] = (groups[key] ?? 0) + length * p.qty;
        }
      }
    }
    return groups.entries.map((e) => [
      e.key,
      (e.value / 1000).toStringAsFixed(1),
      (e.value * 1.1 / 1000).toStringAsFixed(1),
    ]).toList();
  }
}

// ─── Excel Generator ─────────────────────────────────────────────────────────

class ExcelReportGenerator {
  static Future<File> generate({
    required List<Part> allParts,
    required List<SheetLayout> sheets,
    required String projectName,
    String? outputPath,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Kesim Listesi'];

    final headers = ['Sira', 'Modul', 'Parca Adi', 'Adet', 'KESIM EN (mm)',
      'KESIM BOY (mm)', 'Kalinlik', 'Malzeme', 'Bant On', 'Bant Arka',
      'Bant Sol', 'Bant Sag', 'Damar Kilitli', 'Etiket'];

    // Header
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        ..value = TextCellValue(headers[c])
        ..cellStyle = CellStyle(bold: true);
    }

    // Data — grouped by material
    final groups = <String, List<Part>>{};
    for (final p in allParts) {
      groups.putIfAbsent(p.material, () => []).add(p);
    }
    const roleOrder = ['govde', 'kapak', 'arkalik'];
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => roleOrder.indexOf(groups[a]!.first.role)
          .compareTo(roleOrder.indexOf(groups[b]!.first.role)));

    var row = 1;
    for (final mat in sortedKeys) {
      final matParts = groups[mat]!;
      final partCount = matParts.fold<int>(0, (s, p) => s + p.qty);
      final totalM2 = matParts.fold<double>(0, (s, p) =>
          s + (p.netWidthMm * p.netLengthMm / 1e6) * p.qty);

      // Group header row
      for (var c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          ..value = TextCellValue(c == 0 ? '── $mat ($partCount parca, ${totalM2.toStringAsFixed(2)} m²)' : '')
          ..cellStyle = CellStyle(bold: true);
      }
      row++;

      for (final p in matParts) {
        for (var q = 0; q < p.qty; q++) {
          final vals = [
            row, p.moduleId, p.name, 1,
            p.cutWidthMm.toInt(), p.cutLengthMm.toInt(),
            p.thicknessMm.toInt(), p.material,
            p.banding[0].toInt(), p.banding[1].toInt(),
            p.banding[2].toInt(), p.banding[3].toInt(),
            p.grainLocked ? 'Evet' : 'Hayir', p.label ?? '-',
          ];
          for (var c = 0; c < vals.length; c++) {
            final v = vals[c];
            if (v is int) {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
                ..value = IntCellValue(v);
            } else {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
                ..value = TextCellValue(v.toString());
            }
          }
          row++;
        }
      }
    }

    // Summary sheet
    final sum = excel['Ozet'];
    sum.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Proje: $projectName');
    sum.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('Tarih: ${DateTime.now().toString().substring(0, 10)}');
    sum.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
      ..value = TextCellValue('Toplam Plaka: ${sheets.length}');
    final avgWaste = sheets.isEmpty ? 0.0 :
        sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / sheets.length;
    sum.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
      ..value = TextCellValue('Ortalama Fire: %${avgWaste.toStringAsFixed(1)}');

    final outputFile = outputPath != null
        ? File(outputPath)
        : File('kesim_listesi_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) await outputFile.writeAsBytes(bytes);
    return outputFile;
  }
}

// ─── Banding Calculator ──────────────────────────────────────────────────────

class BandingCalculator {
  static Map<String, double> calculateMetraj(List<Part> parts) {
    final groups = <String, double>{};
    for (final p in parts) {
      for (var e = 0; e < 4; e++) {
        if (p.banding[e] > 0) {
          final color = p.role == 'kapak' ? 'Kapak rengi' : 'Govde rengi';
          final key = '$color ${p.banding[e]}mm';
          final length = e <= 1 ? p.netWidthMm : p.netLengthMm;
          groups[key] = (groups[key] ?? 0) + length * p.qty / 1000;
        }
      }
    }
    return groups;
  }

  static double totalMetrajWithFire(List<Part> parts) {
    final metraj = calculateMetraj(parts);
    return metraj.values.fold(0.0, (s, v) => s + v) * 1.10;
  }
}

// ─── Material Calculator ─────────────────────────────────────────────────────

class MaterialCalculator {
  static Map<String, int> plateCounts(List<SheetLayout> sheets) {
    final counts = <String, int>{};
    for (final s in sheets) {
      counts[s.material] = (counts[s.material] ?? 0) + 1;
    }
    return counts;
  }

  static String summary(List<SheetLayout> sheets) {
    if (sheets.isEmpty) return 'Plaka kullanilmadi.';
    final counts = plateCounts(sheets);
    final avgWaste = sheets.map((s) => s.wastePct).reduce((a, b) => a + b) / sheets.length;
    final parts = [
      'Toplam: ${sheets.length} plaka',
      'Fire: %${avgWaste.toStringAsFixed(1)}',
      ...counts.entries.map((e) => '  ${e.key}: ${e.value} plaka'),
    ];
    return parts.join('\n');
  }
}
