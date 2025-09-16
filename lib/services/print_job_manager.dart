// lib/services/print_job_manager.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PrintJobSettings {
  final int numberOfCopies;
  final bool isMonochromatic;
  final int pagesPerSheet;
  final double zoomLevel;
  final double rotationAngle;
  final double brightness;
  final double contrast;
  final double totalCost;

  const PrintJobSettings({
    required this.numberOfCopies,
    required this.isMonochromatic,
    required this.pagesPerSheet,
    required this.zoomLevel,
    required this.rotationAngle,
    required this.brightness,
    required this.contrast,
    required this.totalCost,
  });

  Map<String, dynamic> toJson() => {
    'numberOfCopies': numberOfCopies,
    'isMonochromatic': isMonochromatic,
    'pagesPerSheet': pagesPerSheet,
    'zoomLevel': zoomLevel,
    'rotationAngle': rotationAngle,
    'brightness': brightness,
    'contrast': contrast,
    'totalCost': totalCost,
  };
}

class PrintJobResult {
  final bool success;
  final String? filePath;
  final String? error;
  final DateTime timestamp;

  const PrintJobResult({
    required this.success,
    this.filePath,
    this.error,
    required this.timestamp,
  });
}

class PrintJobManager {
  static const String _printJobPrefix = 'PrintShop_';

  static Future<PrintJobResult> createPrintJob({
    required File originalDocument,
    required PrintJobSettings settings,
    required GlobalKey documentKey,
  }) async {
    try {
      final timestamp = DateTime.now();
      final jobId = '${_printJobPrefix}${timestamp.millisecondsSinceEpoch}';

      // Create output directory
      final outputDir = await _getOutputDirectory();
      final outputFile = File('${outputDir.path}/$jobId.pdf');

      // Generate PDF with applied settings
      final pdfBytes = await _generatePrintPDF(
        originalDocument: originalDocument,
        settings: settings,
        documentKey: documentKey,
      );

      // Save the generated PDF
      await outputFile.writeAsBytes(pdfBytes);

      return PrintJobResult(
        success: true,
        filePath: outputFile.path,
        timestamp: timestamp,
      );
    } catch (e) {
      return PrintJobResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  static Future<Uint8List> _generatePrintPDF({
    required File originalDocument,
    required PrintJobSettings settings,
    required GlobalKey documentKey,
  }) async {
    final pdf = pw.Document(
      title: 'PrintShop Document',
      author: 'PrintShop App',
      creator: 'Flutter PrintShop',
    );

    // Capture the rendered document view
    final boundary =
        documentKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Could not capture document for printing');
    }

    // Convert to image with high quality
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final imageBytes = byteData!.buffer.asUint8List();

    // Process image based on settings
    final processedImage = await _processImageForPrint(imageBytes, settings);

    // Create pages based on number of copies
    for (int copy = 1; copy <= settings.numberOfCopies; copy++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              child: pw.Image(
                pw.MemoryImage(processedImage),
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    // Add metadata page for print shop
    pdf.addPage(_createMetadataPage(settings));

    return pdf.save();
  }

  static Future<Uint8List> _processImageForPrint(
    Uint8List imageBytes,
    PrintJobSettings settings,
  ) async {
    // In a real implementation, you would apply image processing here
    // For now, we return the original image
    // TODO: Implement actual image processing for brightness, contrast, etc.
    return imageBytes;
  }

  static pw.Page _createMetadataPage(PrintJobSettings settings) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Print Job Details',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 1)),
                ),
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Job Information',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              _buildDetailRow(
                'Job ID',
                '${_printJobPrefix}${DateTime.now().millisecondsSinceEpoch}',
              ),
              _buildDetailRow('Date & Time', DateTime.now().toString()),
              _buildDetailRow('Number of Copies', '${settings.numberOfCopies}'),
              _buildDetailRow(
                'Color Mode',
                settings.isMonochromatic ? 'Black & White' : 'Full Color',
              ),
              _buildDetailRow('Pages per Sheet', '${settings.pagesPerSheet}'),
              _buildDetailRow(
                'Zoom Level',
                '${(settings.zoomLevel * 100).round()}%',
              ),
              _buildDetailRow('Rotation', '${settings.rotationAngle.round()}°'),

              pw.SizedBox(height: 20),

              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 1)),
                ),
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Cost Breakdown',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              _buildDetailRow(
                'Base Cost (₹1/copy)',
                '₹${settings.numberOfCopies}',
              ),
              if (!settings.isMonochromatic)
                _buildDetailRow(
                  'Color Surcharge',
                  '₹${(settings.numberOfCopies * 0.5).toStringAsFixed(1)}',
                ),
              if (settings.pagesPerSheet > 1)
                _buildDetailRow(
                  'Multi-page Discount',
                  '-₹${(settings.numberOfCopies * 0.1).toStringAsFixed(1)}',
                ),

              pw.Divider(),

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Amount',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '₹${settings.totalCost.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for using PrintShop!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'For support, contact: support@printshop.com',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static Future<Directory> _getOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final printJobDir = Directory('${directory.path}/print_jobs');

    if (!await printJobDir.exists()) {
      await printJobDir.create(recursive: true);
    }

    return printJobDir;
  }

  static Future<void> sharePrintJob(String filePath) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Printed document from PrintShop');
    } catch (e) {
      throw Exception('Failed to share print job: $e');
    }
  }

  static Future<void> openPrintJob(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'PrintShop_Document.pdf',
      );
    } catch (e) {
      throw Exception('Failed to open print job: $e');
    }
  }

  static Future<List<File>> getRecentPrintJobs() async {
    try {
      final directory = await _getOutputDirectory();
      final files = await directory.list().toList();

      final pdfFiles = files
          .where((file) => file is File && file.path.endsWith('.pdf'))
          .cast<File>()
          .toList();

      // Sort by creation time (newest first)
      pdfFiles.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      return pdfFiles.take(10).toList(); // Return last 10 jobs
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearPrintJobHistory() async {
    try {
      final directory = await _getOutputDirectory();
      final files = await directory.list().toList();

      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to clear print job history: $e');
    }
  }

  static Future<PrintJobResult> simulatePrint({
    required File originalDocument,
    required PrintJobSettings settings,
    required GlobalKey documentKey,
  }) async {
    try {
      // Show realistic printing simulation
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await createPrintJob(
        originalDocument: originalDocument,
        settings: settings,
        documentKey: documentKey,
      );

      if (result.success) {
        // Simulate sending to printer
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      return result;
    } catch (e) {
      return PrintJobResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }
}
