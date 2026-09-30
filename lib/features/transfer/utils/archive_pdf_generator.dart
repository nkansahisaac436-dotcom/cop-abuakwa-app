import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models/tenure_archive_model.dart';

class ArchivePdfGenerator {
  ArchivePdfGenerator._();

  static Future<Uint8List> generateArchivePdf(TenureArchiveModel archive) async {
    final pdf = pw.Document();

    final title = archive.title;
    final pastorName = archive.pastorName;
    final districtName = archive.districtName;
    final totalProjects = archive.totalProjects;
    final totalEvents = archive.totalEvents;
    final totalUpdates = archive.totalUpdates;
    final totalThoughts = archive.totalThoughts;

    final primaryColor = PdfColor.fromHex('#1F3A5F');
    final goldColor = PdfColor.fromHex('#B8860B');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'THE CHURCH OF PENTECOST - ABUAKWA AREA',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Official Pastoral Tenure Archive & Ministry Record',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Archive Title Heading
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Minister: $pastorName | District: $districtName',
                style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              ),
              pw.Divider(thickness: 1, color: goldColor),
              pw.SizedBox(height: 14),

              // Summary Stats Table
              pw.Text(
                'Ministry Summary Overview',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Count', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total District Projects Initiated')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalProjects')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total District Events & Rallies')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalEvents')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Project Progress Updates Recorded')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalUpdates')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pastoral Thoughts & Reflections Shared')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$totalThoughts')),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Verification Note
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: goldColor),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Permanent Record Certification: This archive was securely generated upon Area Head transfer approval. All projects remain permanently attached to $districtName for incoming pastoral continuation.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Certified by Area Head Office', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Generated via Abuakwa Area Connect', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printOrShareArchivePdf(TenureArchiveModel archive) async {
    final pdfBytes = await generateArchivePdf(archive);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${archive.title}.pdf',
    );
  }
}
