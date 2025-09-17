// lib/utils/document_utils.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

// Document type enumeration
enum DocumentType {
  photo,
  pdf,
  unknown;

  static DocumentType fromFile(File file) {
    final extension = file.path.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return DocumentType.photo;
      case 'pdf':
        return DocumentType.pdf;
      default:
        return DocumentType.unknown;
    }
  }
}

// Document metadata class
class DocumentMetadata {
  final String fileName;
  final String filePath;
  final int fileSize;
  final DocumentType type;
  final int pageCount;
  final Size? dimensions;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const DocumentMetadata({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.type,
    this.pageCount = 1,
    this.dimensions,
    required this.createdAt,
    required this.modifiedAt,
  });
}

// Print configuration class
class PrintConfiguration {
  final int copies;
  final bool isMonochromatic;
  final String paperSize;
  final String orientation;
  final double quality;
  final bool duplex;
  final List<int> selectedPages;

  const PrintConfiguration({
    this.copies = 1,
    this.isMonochromatic = false,
    this.paperSize = 'A4',
    this.orientation = 'portrait',
    this.quality = 1.0,
    this.duplex = false,
    this.selectedPages = const [],
  });

  PrintConfiguration copyWith({
    int? copies,
    bool? isMonochromatic,
    String? paperSize,
    String? orientation,
    double? quality,
    bool? duplex,
    List<int>? selectedPages,
  }) {
    return PrintConfiguration(
      copies: copies ?? this.copies,
      isMonochromatic: isMonochromatic ?? this.isMonochromatic,
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      quality: quality ?? this.quality,
      duplex: duplex ?? this.duplex,
      selectedPages: selectedPages ?? this.selectedPages,
    );
  }
}

// Document processing utilities
class DocumentUtils {
  // Get document metadata
  static Future<DocumentMetadata> getDocumentMetadata(File file) async {
    final stat = await file.stat();
    final type = DocumentType.fromFile(file);

    int pageCount = 1;
    Size? dimensions;

    try {
      if (type == DocumentType.pdf) {
        pageCount = await _getPdfPageCount(file);
      } else if (type == DocumentType.photo) {
        dimensions = await _getImageDimensions(file);
      }
    } catch (e) {
      debugPrint('Error getting document metadata: $e');
    }

    return DocumentMetadata(
      fileName: file.path.split('/').last,
      filePath: file.path,
      fileSize: stat.size,
      type: type,
      pageCount: pageCount,
      dimensions: dimensions,
      createdAt: stat.accessed,
      modifiedAt: stat.modified,
    );
  }

  // Get PDF page count
  static Future<int> _getPdfPageCount(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();
      return pageCount;
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      return 1;
    }
  }

  // Get image dimensions
  static Future<Size> _getImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return const Size(800, 600); // Default size
    }
  }

  // Validate file for printing
  static Future<ValidationResult> validateDocumentForPrinting(File file) async {
    final issues = <String>[];

    // Check file existence
    if (!await file.exists()) {
      issues.add('File does not exist');
      return ValidationResult(isValid: false, issues: issues);
    }

    // Check file size (limit to 50MB)
    final stat = await file.stat();
    if (stat.size > 50 * 1024 * 1024) {
      issues.add('File size exceeds 50MB limit');
    }

    // Check file type
    final type = DocumentType.fromFile(file);
    if (type == DocumentType.unknown) {
      issues.add('Unsupported file format');
    }

    // Additional PDF validation
    if (type == DocumentType.pdf) {
      try {
        final pageCount = await _getPdfPageCount(file);
        if (pageCount > 100) {
          issues.add('PDF has more than 100 pages');
        }
      } catch (e) {
        issues.add('Invalid or corrupted PDF file');
      }
    }

    return ValidationResult(isValid: issues.isEmpty, issues: issues);
  }

  // Generate print preview
  static Future<File> generatePrintPreview({
    required List<GlobalKey> pageKeys,
    required PrintConfiguration config,
    String? outputPath,
  }) async {
    try {
      final pdf = PdfDocument();

      for (int i = 0; i < pageKeys.length; i++) {
        final key = pageKeys[i];
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

        if (boundary != null) {
          // Generate copies
          for (int copy = 0; copy < config.copies; copy++) {
            final image = await boundary.toImage(pixelRatio: 2.0);
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );

            if (byteData != null) {
              final pngBytes = byteData.buffer.asUint8List();
              final page = pdf.pages.add();

              // Apply transformations based on configuration
              final graphics = page.graphics;
              final pdfImage = PdfBitmap(pngBytes);

              // Calculate image placement
              final pageRect = Rect.fromLTWH(
                0,
                0,
                page.size.width,
                page.size.height,
              );
              final imageRect = _calculateImagePlacement(
                imageSize: Size(
                  pdfImage.width.toDouble(),
                  pdfImage.height.toDouble(),
                ),
                pageSize: Size(page.size.width, page.size.height),
                orientation: config.orientation,
              );

              graphics.drawImage(pdfImage, imageRect);
            }
          }
        }
      }

      // Save to file
      final directory = outputPath != null
          ? Directory(outputPath)
          : await getTemporaryDirectory();
      final file = File(
        '${directory.path}/print_preview_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      pdf.dispose();
      return file;
    } catch (e) {
      debugPrint('Error generating print preview: $e');
      rethrow;
    }
  }

  // Calculate optimal image placement on page
  static Rect _calculateImagePlacement({
    required Size imageSize,
    required Size pageSize,
    required String orientation,
  }) {
    double targetWidth = pageSize.width;
    double targetHeight = pageSize.height;

    // Apply orientation
    if (orientation == 'landscape') {
      final temp = targetWidth;
      targetWidth = targetHeight;
      targetHeight = temp;
    }

    // Calculate scale to fit
    final scaleX = targetWidth / imageSize.width;
    final scaleY = targetHeight / imageSize.height;
    final scale = math.min(scaleX, scaleY);

    final scaledWidth = imageSize.width * scale;
    final scaledHeight = imageSize.height * scale;

    // Center the image
    final x = (targetWidth - scaledWidth) / 2;
    final y = (targetHeight - scaledHeight) / 2;

    return Rect.fromLTWH(x, y, scaledWidth, scaledHeight);
  }

  // Calculate print cost
  static double calculatePrintCost({
    required int pageCount,
    required int copies,
    required bool isColor,
    Map<String, double>? customRates,
  }) {
    final rates =
        customRates ??
        {
          'base_bw': 1.0, // ₹1 per B&W page
          'color_surcharge': 0.5, // ₹0.50 extra for color
          'bulk_discount': 0.05, // 5% discount for 10+ pages
        };

    final totalPages = pageCount * copies;
    final baseCost = totalPages * rates['base_bw']!;
    final colorCost = isColor ? totalPages * rates['color_surcharge']! : 0.0;

    double discount = 0.0;
    if (totalPages >= 10) {
      discount = (baseCost + colorCost) * rates['bulk_discount']!;
    }

    return (baseCost + colorCost - discount).clamp(0.0, double.infinity);
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Generate unique filename
  static String generateUniqueFilename(String baseName, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${baseName}_$timestamp.$extension';
  }

  // Clean temporary files
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();

      for (final file in files) {
        if (file is File && file.path.contains('print_preview_')) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);

          // Delete files older than 1 hour
          if (age.inHours > 1) {
            await file.delete();
            debugPrint('Deleted old temp file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning temp files: $e');
    }
  }
}

// Validation result class
class ValidationResult {
  final bool isValid;
  final List<String> issues;

  const ValidationResult({required this.isValid, required this.issues});

  String get summary {
    if (isValid) return 'Document is valid for printing';
    return 'Found ${issues.length} issue${issues.length == 1 ? '' : 's'}: ${issues.join(', ')}';
  }
}

// Print job status
enum PrintJobStatus {
  pending,
  processing,
  printing,
  completed,
  failed,
  cancelled,
}

// Print job class
class PrintJob {
  final String id;
  final String documentName;
  final PrintConfiguration configuration;
  final DateTime createdAt;
  PrintJobStatus status;
  String? statusMessage;
  double progress;

  PrintJob({
    required this.id,
    required this.documentName,
    required this.configuration,
    required this.createdAt,
    this.status = PrintJobStatus.pending,
    this.statusMessage,
    this.progress = 0.0,
  });

  void updateStatus(
    PrintJobStatus newStatus, {
    String? message,
    double? progress,
  }) {
    status = newStatus;
    if (message != null) statusMessage = message;
    if (progress != null) this.progress = progress.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentName': documentName,
      'configuration': {
        'copies': configuration.copies,
        'isMonochromatic': configuration.isMonochromatic,
        'paperSize': configuration.paperSize,
        'orientation': configuration.orientation,
        'quality': configuration.quality,
        'selectedPages': configuration.selectedPages,
      },
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'statusMessage': statusMessage,
      'progress': progress,
    };
  }
}

// Print queue manager
class PrintQueueManager {
  static final PrintQueueManager _instance = PrintQueueManager._internal();
  factory PrintQueueManager() => _instance;
  PrintQueueManager._internal();

  final List<PrintJob> _queue = [];
  final ValueNotifier<int> queueLength = ValueNotifier(0);

  List<PrintJob> get queue => List.unmodifiable(_queue);

  String addJob(PrintJob job) {
    _queue.add(job);
    queueLength.value = _queue.length;
    _processQueue();
    return job.id;
  }

  bool removeJob(String jobId) {
    final index = _queue.indexWhere((job) => job.id == jobId);
    if (index != -1) {
      _queue.removeAt(index);
      queueLength.value = _queue.length;
      return true;
    }
    return false;
  }

  PrintJob? getJob(String jobId) {
    try {
      return _queue.firstWhere((job) => job.id == jobId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _processQueue() async {
    // Simple queue processing simulation
    while (_queue.isNotEmpty) {
      final job = _queue.first;

      if (job.status == PrintJobStatus.pending) {
        job.updateStatus(
          PrintJobStatus.processing,
          message: 'Preparing document...',
        );

        // Simulate processing time
        for (int i = 0; i <= 100; i += 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          job.updateStatus(PrintJobStatus.processing, progress: i / 100);
        }

        job.updateStatus(
          PrintJobStatus.completed,
          message: 'Print job completed successfully',
        );
        _queue.removeAt(0);
        queueLength.value = _queue.length;
      }
    }
  }

  void clearCompleted() {
    _queue.removeWhere(
      (job) =>
          job.status == PrintJobStatus.completed ||
          job.status == PrintJobStatus.failed ||
          job.status == PrintJobStatus.cancelled,
    );
    queueLength.value = _queue.length;
  }
}

// Image processing utilities
class ImageProcessingUtils {
  // Apply color filter to image bytes
  static Future<Uint8List?> applyColorFilter({
    required Uint8List imageBytes,
    required List<double> colorMatrix,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final paint = Paint()..colorFilter = ColorFilter.matrix(colorMatrix);

      canvas.drawImage(image, Offset.zero, paint);

      final picture = recorder.endRecording();
      final processedImage = await picture.toImage(image.width, image.height);

      final byteData = await processedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      image.dispose();
      processedImage.dispose();
      picture.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error applying color filter: $e');
      return null;
    }
  }

  // Resize image
  static Future<Uint8List?> resizeImage({
    required Uint8List imageBytes,
    required Size targetSize,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);

      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(
        targetSize.width.toInt(),
        targetSize.height.toInt(),
      );

      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      image.dispose();
      resizedImage.dispose();
      picture.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }
}
