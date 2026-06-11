/// Customer offer PDF generator for MarangozAI.
///
/// Generates a clean, professional offer PDF for the customer.
/// Per CLAUDE.md: NO cut details, NO brand-only pricing, VAT as separate line.
/// Includes: company logo, customer name, project summary, total price, terms.

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'cost_service.dart';

class OfferPdfGenerator {
  /// Generate offer PDF for customer.
  static Future<File> generate({
    required String customerName,
    required String projectSummary,
    required CostReport costReport,
    String? companyName,
    String? companyPhone,
    String? notes,
    String? outputPath,
  }) async {
    final pdf = pw.Document();
    final company = companyName ?? 'Usta Yardimcisi';
    final phone = companyPhone ?? '';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        // Header
        pw.Header(level: 0, text: company, textStyle: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
        if (phone.isNotEmpty) pw.Paragraph(text: 'Tel: $phone'),
        pw.Divider(),
        pw.SizedBox(height: 20),

        // Customer & Date
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Musteri:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(customerName),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tarih:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(DateTime.now().toString().substring(0, 10)),
            ]),
          ],
        ),
        pw.SizedBox(height: 24),

        // Project summary
        pw.Header(level: 1, text: 'Proje Ozeti'),
        pw.Paragraph(text: projectSummary),
        pw.SizedBox(height: 24),

        // Price table (simplified — no cut details)
        pw.Header(level: 1, text: 'Fiyat Teklifi'),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Kalem', 'Birim', 'Tutar (TL)'],
          data: [
            ['Malzeme (plaka, bant, donanim)', '', costReport.lines
                .where((l) => ['plaka', 'm', 'adet', 'cift', 'mtul'].contains(l.unit))
                .fold<double>(0, (s, l) => s + l.total)
                .toStringAsFixed(0)],
            ['Tezgah', '', costReport.lines
                .where((l) => l.item.contains('Tezgah'))
                .fold<double>(0, (s, l) => s + l.total)
                .toStringAsFixed(0)],
            ['Isçilik ve montaj', '', costReport.lines
                .where((l) => l.item.contains('iscilik'))
                .fold<double>(0, (s, l) => s + l.total)
                .toStringAsFixed(0)],
            ['TOPLAM (KDV haric)', '', costReport.subtotal.toStringAsFixed(0)],
            ['KDV (%${(costReport.vatRate * 100).toStringAsFixed(0)})', '', costReport.vat.toStringAsFixed(0)],
            ['Kâr marji (%${costReport.marginPct.toStringAsFixed(0)})', '', (costReport.customerPrice - costReport.subtotal).toStringAsFixed(0)],
          ],
          border: pw.TableBorder.all(),
          columnWidths: {0: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(2)},
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          cellStyle: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 16),

        // Total (large)
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 2),
            color: PdfColors.grey100,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TEKLIF EDILEN FIYAT (KDV DAHIL)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(costReport.formattedTotal,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 24),

        // Terms
        pw.Header(level: 1, text: 'Notlar'),
        pw.Paragraph(text: notes ?? ''),
        pw.SizedBox(height: 16),
        pw.Paragraph(text: '- Fiyatlara KDV dahildir.'),
        pw.Paragraph(text: '- Olçu ve kesim hatalarina karsi garanti verilir.'),
        pw.Paragraph(text: '- Montaj sureci planlamaya dahildir.'),
        pw.Paragraph(text: '- Bu teklif ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year} '
            'tarihine kadar gecerlidir.'),
        pw.SizedBox(height: 16),
        pw.Paragraph(text: 'Temsili gorseldir — uretim olculeri kesim listesindedir.'),
        pw.SizedBox(height: 30),

        // Signature area
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(children: [
              pw.Container(width: 150, child: pw.Divider()),
              pw.Text('Musteri Imza'),
            ]),
            pw.Column(children: [
              pw.Container(width: 150, child: pw.Divider()),
              pw.Text('Usta Imza'),
            ]),
          ],
        ),
      ],
    ));

    final outputFile = outputPath != null
        ? File(outputPath)
        : File('teklif_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  /// Build project summary text from wizard selections.
  static String buildSummary({
    required String wallInfo,
    required String doorMaterial,
    required String doorColor,
    required String bodyColor,
    required String countertopType,
    required int drawerCount,
    required bool hasGlass,
    required String handleType,
    required int moduleCount,
    required int plateCount,
  }) {
    final parts = <String>[
      '$moduleCount adet dolap modulu',
      '$plateCount plaka malzeme',
      'Kapak: $doorMaterial — $doorColor',
      'Govde: $bodyColor',
      'Tezgah: $countertopType',
      if (drawerCount > 0) '$drawerCount cekmeceli modul',
      if (hasGlass) 'Camli kapak',
      'Kulp: $handleType',
      'Duvar: $wallInfo',
    ];
    return parts.join('\n');
  }
}
