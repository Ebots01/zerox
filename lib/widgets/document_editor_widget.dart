// lib/widgets/document_editor_widget.dart
import 'dart:io';
// import 'dart:ui' as ui; // <-- 1. REMOVED UNUSED IMPORT
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart'; // <-- 1. REMOVED UNNECESSARY IMPORT
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentEditorWidget extends StatefulWidget {
  final File documentFile;
  final double zoomLevel;
  final double rotationAngle;
  final bool isMonochromatic;
  final int pagesPerSheet;
  final double brightness;
  final double contrast;
  final Function(GlobalKey)? onKeyGenerated;

  const DocumentEditorWidget({
    super.key,
    required this.documentFile,
    this.zoomLevel = 1.0,
    this.rotationAngle = 0.0,
    this.isMonochromatic = false,
    this.pagesPerSheet = 1,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.onKeyGenerated,
  });

  @override
  State<DocumentEditorWidget> createState() => _DocumentEditorWidgetState();
}

class _DocumentEditorWidgetState extends State<DocumentEditorWidget> {
  final GlobalKey _documentKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onKeyGenerated?.call(_documentKey);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Build color filter matrix for brightness and contrast
  List<double> _buildColorMatrix() {
    final brightness = widget.brightness;
    final contrast = 1.0 + widget.contrast;

    if (widget.isMonochromatic) {
      // Grayscale with brightness and contrast
      return [
        0.2126 * contrast,
        0.7152 * contrast,
        0.0722 * contrast,
        0,
        brightness * 255,
        0.2126 * contrast,
        0.7152 * contrast,
        0.0722 * contrast,
        0,
        brightness * 255,
        0.2126 * contrast,
        0.7152 * contrast,
        0.0722 * contrast,
        0,
        brightness * 255,
        0,
        0,
        0,
        1,
        0,
      ];
    } else {
      // Color with brightness and contrast
      return [
        contrast,
        0,
        0,
        0,
        brightness * 255,
        0,
        contrast,
        0,
        0,
        brightness * 255,
        0,
        0,
        contrast,
        0,
        brightness * 255,
        0,
        0,
        0,
        1,
        0,
      ];
    }
  }

  Widget _buildA4Sheet({required Widget child, bool showBorder = true}) {
    const double a4Width = 210.0; // A4 width in mm
    const double a4Height = 297.0; // A4 height in mm
    // const double scale = 2.0; // <-- 2. REMOVED UNUSED 'scale' VARIABLE

    final screenWidth = MediaQuery.of(context).size.width * 0.6;
    final aspectRatio = a4Width / a4Height;
    final containerWidth = screenWidth - 32;
    final containerHeight = containerWidth / aspectRatio;

    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            // 3. FIXED DEPRECATED 'withOpacity'
            color: Colors.black.withAlpha(51), // This is 20% opacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: showBorder
            ? Border.all(color: Colors.grey.shade300, width: 1)
            : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
    );
  }

  Widget _buildSinglePageLayout() {
    return _buildA4Sheet(
      child: Transform.scale(
        scale: widget.zoomLevel,
        child: Transform.rotate(
          angle: widget.rotationAngle * 3.14159 / 180,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_buildColorMatrix()),
            child: _buildDocumentContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiPageLayout() {
    final pages = widget.pagesPerSheet;
    final columns = _getColumnsForPages(pages);
    // final rows = (pages / columns).ceil(); // <-- 2. REMOVED UNUSED 'rows' VARIABLE

    return _buildA4Sheet(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 210 / 297, // A4 aspect ratio
          ),
          itemCount: pages,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Transform.scale(
                  scale: widget.zoomLevel * _getScaleFactorForPages(pages),
                  child: Transform.rotate(
                    angle: widget.rotationAngle * 3.14159 / 180,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                      child: _buildDocumentContent(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  int _getColumnsForPages(int pages) {
    switch (pages) {
      case 2:
        return 2;
      case 4:
        return 2;
      case 6:
        return 2;
      case 9:
        return 3;
      default:
        return 1;
    }
  }

  double _getScaleFactorForPages(int pages) {
    switch (pages) {
      case 2:
        return 0.45;
      case 4:
        return 0.4;
      case 6:
        return 0.3;
      case 9:
        return 0.25;
      default:
        return 1.0;
    }
  }

  Widget _buildDocumentContent() {
    final filePath = widget.documentFile.path.toLowerCase();

    if (filePath.endsWith('.pdf')) {
      return SfPdfViewer.file(
        widget.documentFile,
        enableDoubleTapZooming: false,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        canShowPaginationDialog: false,
        enableTextSelection: false,
        canShowPasswordDialog: false,
        pageSpacing: 0,
      );
    } else {
      return Image.file(
        widget.documentFile,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _documentKey,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: widget.pagesPerSheet == 1
                ? _buildSinglePageLayout()
                : _buildMultiPageLayout(),
          ),
        ),
      ),
    );
  }
}

class DocumentPreviewHeader extends StatelessWidget {
  final String fileName;
  final bool isMonochromatic;
  final int pagesPerSheet;
  final VoidCallback? onResetSettings;

  const DocumentPreviewHeader({
    super.key,
    required this.fileName,
    required this.isMonochromatic,
    required this.pagesPerSheet,
    this.onResetSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            // 3. FIXED DEPRECATED 'withOpacity'
            color: Colors.black.withAlpha(13), // This is 5% opacity
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.preview, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A4 Preview',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Pages per sheet indicator
          if (pagesPerSheet > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view,
                    size: 12,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${pagesPerSheet}pp',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Color mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMonochromatic
                  ? Colors.grey.shade100
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMonochromatic
                    ? Colors.grey.shade300
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMonochromatic ? Icons.filter_b_and_w : Icons.color_lens,
                  size: 12,
                  color: isMonochromatic
                      ? Colors.grey.shade600
                      : Colors.blue.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  isMonochromatic ? 'B&W' : 'Color',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isMonochromatic
                        ? Colors.grey.shade600
                        : Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          if (onResetSettings != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onResetSettings,
              icon: Icon(Icons.refresh, size: 18, color: Colors.grey.shade600),
              tooltip: 'Reset Settings',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}
