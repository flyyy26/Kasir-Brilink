// lib/services/pdf_export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class PdfExportService {
  static Future<Uint8List> generateTagihanPdf({
    required String peminjamName,
    required List<dynamic> piutangList,
    required double totalPiutang,
    required double totalSisa,
    required String outletName,
    required String tanggalCetak,
    required String Function(dynamic) formatIdr,
  }) async {
    final pdf = pw.Document();

    // Load font dengan fallback
    pw.Font? fontRegular;
    pw.Font? fontBold;
    
    try {
      final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
      fontRegular = pw.Font.ttf(fontData);
      fontBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      print("Font not found, using default font");
    }

    // Filter hanya piutang yang belum lunas
    final tagihanList = piutangList.where((p) {
      String status = p['status'] ?? '';
      double sisa = double.tryParse(p['sisa_hutang']?.toString() ?? '0') ?? 0;
      return status != 'lunas' && sisa > 0;
    }).toList();

    if (tagihanList.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                'Tidak ada tagihan yang perlu dibayar',
                style: pw.TextStyle(
                  fontSize: 18,
                  color: PdfColors.grey700,
                ),
              ),
            );
          },
        ),
      );
      return pdf.save();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // ============ HEADER ============
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blue900, width: 3),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TAGIHAN PIUTANG',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 24,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Tagihan kepada: $peminjamName',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 16,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Tanggal Cetak: $tanggalCetak',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                              color: PdfColors.grey500,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.orange100,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'BELUM LUNAS',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 12,
                                color: PdfColors.orange800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // ============ SUMMARY ============
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Total Piutang',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Rp ${formatIdr(totalPiutang)}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 1,
                    height: 40,
                    color: PdfColors.grey300,
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Sisa Piutang',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Rp ${formatIdr(totalSisa)}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 1,
                    height: 40,
                    color: PdfColors.grey300,
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Jumlah Tagihan',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        '${tagihanList.length}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 18,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ============ TABLE ============
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200),
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header Table
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'No',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Nama Piutang',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Tanggal',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Jatuh Tempo',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Nominal',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Sisa',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),

                // Data Rows
                ...tagihanList.asMap().entries.map((entry) {
                  int index = entry.key;
                  var item = entry.value;
                  
                  String tanggal = '';
                  if (item['created_at'] != null) {
                    try {
                      DateTime date = DateTime.parse(item['created_at']);
                      tanggal = DateFormat('dd MMM yyyy').format(date);
                    } catch (e) {
                      tanggal = item['created_at'] ?? '';
                    }
                  }

                  String jatuhTempo = '-';
                  if (item['tanggal_jatuh_tempo'] != null && item['tanggal_jatuh_tempo'].toString().isNotEmpty) {
                    try {
                      DateTime date = DateTime.parse(item['tanggal_jatuh_tempo']);
                      jatuhTempo = DateFormat('dd MMM yyyy').format(date);
                    } catch (e) {
                      jatuhTempo = item['tanggal_jatuh_tempo'].toString();
                    }
                  }

                  double nominal = double.tryParse(item['nominal']?.toString() ?? '0') ?? 0;
                  double sisa = double.tryParse(item['sisa_hutang']?.toString() ?? '0') ?? 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item['nama_piutang'] ?? '-',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          tanggal,
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          jatuhTempo,
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rp ${formatIdr(nominal)}',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rp ${formatIdr(sisa)}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: sisa > 0 ? PdfColors.red700 : PdfColors.green700,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),

                // Footer Total
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: const pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey300, width: 2),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Container(),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Container(),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Container(),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rp ${formatIdr(totalPiutang)}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rp ${formatIdr(totalSisa)}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          color: PdfColors.red700,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // ============ FOOTER ============
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Informasi Penting',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.orange800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Mohon segera melunasi tagihan sebelum jatuh tempo. '
                    'Hubungi admin untuk informasi lebih lanjut.',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ============ SAVE PDF KE DOWNLOADS ============
  static Future<String> savePdfToDownloads(Uint8List pdfBytes, String fileName) async {
    try {
      // Coba dapatkan direktori Downloads
      Directory? downloadsDir;
      
      if (Platform.isWindows) {
        // Windows: C:\Users\[User]\Downloads
        final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
        downloadsDir = Directory('$userProfile\\Downloads');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isMacOS) {
        // macOS: /Users/[User]/Downloads
        final home = Platform.environment['HOME'] ?? '';
        downloadsDir = Directory('$home/Downloads');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isLinux) {
        // Linux: /home/[User]/Downloads
        final home = Platform.environment['HOME'] ?? '';
        downloadsDir = Directory('$home/Downloads');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else {
        // Android/iOS: Gunakan application documents
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      print("PDF saved to: ${file.path}");
      return file.path;
      
    } catch (e) {
      print("Error saving PDF: $e");
      
      // Fallback: Simpan di Documents
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      print("PDF saved to (fallback): ${file.path}");
      return file.path;
    }
  }

  // ============ OPEN PDF ============
  static Future<void> openPdf(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      } else {
        // Android/iOS
        print("File saved at: $filePath");
      }
    } catch (e) {
      print("Error opening PDF: $e");
      rethrow;
    }
  }

  // ============ DOWNLOAD PDF (Main) ============
  static Future<void> downloadPdf(Uint8List pdfBytes, String fileName) async {
    try {
      final filePath = await savePdfToDownloads(pdfBytes, fileName);
      await openPdf(filePath);
    } catch (e) {
      print("Error in downloadPdf: $e");
      rethrow;
    }
  }
}