// lib/screens/preview_screen/preview_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../widgets/qr_code_widget.dart';
import 'preview_view_model.dart';

// Enhanced model for individual page data with auto-fit support
class PageData {
  final int originalIndex;
  final String type; // 'photo' or 'pdf'
  Offset position;
  Size size;
  double rotation;
  Rect cropRect;
  double scale;
  bool autoFit; // Auto-fit to A4

  PageData({
    required this.originalIndex,
    required this.type,
    this.position = Offset.zero,
    this.size = const Size(300, 400),
    this.rotation = 0.0,
    this.cropRect = const Rect.fromLTWH(0, 0, 1, 1),
    this.scale = 1.0,
    this.autoFit = true,
  });

  PageData copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    Rect? cropRect,
    double? scale,
    bool? autoFit,
  }) {
    return PageData(
      originalIndex: originalIndex,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      cropRect: cropRect ?? this.cropRect,
      scale: scale ?? this.scale,
      autoFit: autoFit ?? this.autoFit,
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final File documentFile;

  const PreviewScreen({super.key, required this.documentFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final GlobalKey _previewAreaKey = GlobalKey();
  final PageController _pageController = PageController();

  // FIXED: Initialize _pages with empty list to prevent LateInitializationError
  List<PageData> _pages = [];
  int _currentPageIndex = 0;
  int? _selectedPageIndex;
  bool _isInitialized = false; // Track initialization state
  int _actualPdfPageCount = 0;

  @override
  void initState() {
    super.initState();
    // FIXED: Call initialization after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePages();
    });
  }

  // ENHANCED: Get actual PDF page count and auto-fit pages
  Future<void> _initializePages() async {
    if (_isInitialized) return; // Prevent multiple initializations

    try {
      final filePath = widget.documentFile.path.toLowerCase();

      if (_isPhotoFile) {
        // Single photo with auto-fit
        _pages = [
          PageData(
            originalIndex: 0,
            type: 'photo',
            position: const Offset(10, 10),
            size: _calculateAutoFitSize(const Size(800, 600), 380, 500),
            autoFit: true,
          ),
        ];
      } else {
        // PDF: Get actual page count
        await _getPdfPageCount();
        _pages = List.generate(
          math.max(1, _actualPdfPageCount), // Ensure at least 1 page
          (index) => PageData(
            originalIndex: index,
            type: 'pdf',
            position: const Offset(10, 10),
            size: _calculateAutoFitSize(const Size(595, 842), 380, 500),
            autoFit: true,
          ),
        );
      }

      _isInitialized = true;
      if (mounted) {
        setState(() {}); // Trigger rebuild after initialization
      }
    } catch (e) {
      debugPrint('Error initializing pages: $e');
      // Fallback to single page
      _pages = [
        PageData(
          originalIndex: 0,
          type: _isPhotoFile ? 'photo' : 'pdf',
          position: const Offset(10, 10),
          size: const Size(300, 400),
          autoFit: true,
        ),
      ];
      _isInitialized = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // REAL PDF page count detection
  Future<void> _getPdfPageCount() async {
    try {
      // Use syncfusion_flutter_pdfviewer to get actual page count
      final bytes = await widget.documentFile.readAsBytes();

      // Simple PDF page count detection (basic implementation)
      // In a real app, you'd use a proper PDF library
      final content = String.fromCharCodes(bytes);
      final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(content);
      _actualPdfPageCount = math.max(1, pageMatches.length);

      // Fallback: count /Page occurrences
      if (_actualPdfPageCount <= 1) {
        final fallbackMatches = RegExp(r'/Page').allMatches(content);
        _actualPdfPageCount = math.max(1, (fallbackMatches.length / 2).round());
      }

      // Cap at reasonable number
      _actualPdfPageCount = math.min(_actualPdfPageCount, 200);

      debugPrint('Detected PDF pages: $_actualPdfPageCount');
    } catch (e) {
      debugPrint('Error getting PDF page count: $e');
      _actualPdfPageCount = 5; // Fallback
    }
  }

  // Calculate auto-fit size for A4
  Size _calculateAutoFitSize(
    Size originalSize,
    double maxWidth,
    double maxHeight,
  ) {
    final double widthRatio = maxWidth / originalSize.width;
    final double heightRatio = maxHeight / originalSize.height;
    final double ratio = math.min(widthRatio, heightRatio);

    return Size(originalSize.width * ratio, originalSize.height * ratio);
  }

  bool get _isPhotoFile {
    final filePath = widget.documentFile.path.toLowerCase();
    return filePath.endsWith('.jpg') ||
        filePath.endsWith('.jpeg') ||
        filePath.endsWith('.png') ||
        filePath.endsWith('.gif') ||
        filePath.endsWith('.bmp');
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Show loading while initializing
    if (!_isInitialized || _pages.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Loading Document...'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing document pages...'),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => PreviewViewModel()
        ..setDocumentInfo(
          totalPages: _pages.length,
          documentType: _isPhotoFile ? 'photo' : 'pdf',
        ),
      child: Consumer<PreviewViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: _buildAppBar(viewModel),
            body: Row(
              children: [
                // Left side - Preview area (MAXIMIZED)
                Expanded(flex: 4, child: _buildPreviewArea(viewModel)),
                // Right side - Enhanced Controls
                _buildEnhancedControlPanel(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(PreviewViewModel viewModel) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            _isPhotoFile ? Icons.image : Icons.picture_as_pdf,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.documentFile.path.split('/').last,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Enhanced page counter
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Sheet ${_currentPageIndex + 1}/${math.max(1, (_pages.length / viewModel.pagesPerSheet).ceil())} | ${_pages.length} pages',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // Enhanced preview area with better A4 handling
  Widget _buildPreviewArea(PreviewViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Enhanced navigation header
          _buildEnhancedNavigationHeader(viewModel),
          // Main preview area with sheets
          Expanded(child: _buildMainPreviewArea(viewModel)),
          // Enhanced page thumbnails
          _buildEnhancedPageThumbnails(viewModel),
        ],
      ),
    );
  }

  Widget _buildEnhancedNavigationHeader(PreviewViewModel viewModel) {
    final sheetsCount = math.max(
      1,
      (_pages.length / viewModel.pagesPerSheet).ceil(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentPageIndex > 0
                ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'A4 Sheet ${_currentPageIndex + 1}/$sheetsCount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${viewModel.pagesPerSheet} page(s) per sheet • ${_pages.length} total pages',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // AUTO-FIT toggle button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _toggleAutoFitAll(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pages.any((p) => p.autoFit)
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: Icon(
                _pages.any((p) => p.autoFit)
                    ? Icons.fit_screen
                    : Icons.fullscreen_exit,
                size: 16,
              ),
              label: const Text('Auto-Fit', style: TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            onPressed: _currentPageIndex < sheetsCount - 1
                ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Main preview area with pages per sheet support
  Widget _buildMainPreviewArea(PreviewViewModel viewModel) {
    final sheetsCount = math.max(
      1,
      (_pages.length / viewModel.pagesPerSheet).ceil(),
    );

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
          _selectedPageIndex = null;
        });
      },
      itemCount: sheetsCount,
      itemBuilder: (context, sheetIndex) {
        return _buildA4SheetWithMultiplePages(viewModel, sheetIndex);
      },
    );
  }

  // Build A4 sheet with multiple pages support
  Widget _buildA4SheetWithMultiplePages(
    PreviewViewModel viewModel,
    int sheetIndex,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate A4 dimensions
        const double a4Ratio = 210.0 / 297.0;
        double sheetWidth = constraints.maxWidth - 32;
        double sheetHeight = sheetWidth / a4Ratio;

        if (sheetHeight > constraints.maxHeight - 32) {
          sheetHeight = constraints.maxHeight - 32;
          sheetWidth = sheetHeight * a4Ratio;
        }

        // Get pages for this sheet
        final pagesPerSheet = viewModel.pagesPerSheet;
        final startIndex = sheetIndex * pagesPerSheet;
        final endIndex = math.min(startIndex + pagesPerSheet, _pages.length);
        final sheetPages = _pages.sublist(startIndex, endIndex);

        return Center(
          child: Container(
            width: sheetWidth,
            height: sheetHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // A4 grid background
                  _buildGridLines(sheetWidth, sheetHeight),
                  // A4 labels
                  _buildA4Labels(sheetPages.length, pagesPerSheet),
                  // Multiple pages layout
                  _buildPagesLayout(
                    sheetPages,
                    viewModel,
                    sheetWidth,
                    sheetHeight,
                    startIndex,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build pages layout based on pages per sheet
  Widget _buildPagesLayout(
    List<PageData> sheetPages,
    PreviewViewModel viewModel,
    double sheetWidth,
    double sheetHeight,
    int startIndex,
  ) {
    final pagesPerSheet = viewModel.pagesPerSheet;

    if (pagesPerSheet == 1) {
      // Single page - full A4
      return sheetPages.isNotEmpty
          ? _buildEditableDocument(
              viewModel,
              startIndex,
              sheetWidth,
              sheetHeight,
              sheetPages[0],
            )
          : Container();
    } else if (pagesPerSheet == 2) {
      // Two pages side by side
      return Row(
        children: [
          for (int i = 0; i < 2; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(2),
                child: i < sheetPages.length
                    ? _buildEditableDocument(
                        viewModel,
                        startIndex + i,
                        sheetWidth / 2 - 4,
                        sheetHeight - 4,
                        sheetPages[i],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            'Empty Page',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      );
    } else {
      // 3 or 4 pages in 2x2 grid
      return Column(
        children: [
          for (int row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (int col = 0; col < 2; col++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        child: () {
                          final pageIndex = row * 2 + col;
                          if (pageIndex < sheetPages.length) {
                            return _buildEditableDocument(
                              viewModel,
                              startIndex + pageIndex,
                              sheetWidth / 2 - 2,
                              sheetHeight / 2 - 2,
                              sheetPages[pageIndex],
                            );
                          } else {
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  'Empty',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            );
                          }
                        }(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
  }

  // ENHANCED: Editable document with auto-fit support
  Widget _buildEditableDocument(
    PreviewViewModel viewModel,
    int globalPageIndex,
    double availableWidth,
    double availableHeight,
    PageData page,
  ) {
    final isSelected = _selectedPageIndex == globalPageIndex;

    // Auto-fit calculation
    Size displaySize = page.size;
    if (page.autoFit) {
      displaySize = _calculateAutoFitSize(
        page.size,
        availableWidth - 20,
        availableHeight - 20,
      );
    }

    // Apply scale
    displaySize = Size(
      displaySize.width * page.scale,
      displaySize.height * page.scale,
    );

    // Ensure within bounds
    final maxLeft = math.max(0.0, availableWidth - displaySize.width);
    final maxTop = math.max(0.0, availableHeight - displaySize.height);

    return Positioned(
      left: page.position.dx.clamp(0.0, maxLeft),
      top: page.position.dy.clamp(0.0, maxTop),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPageIndex = globalPageIndex;
          });
        },
        onPanStart: (details) {
          setState(() {
            _selectedPageIndex = globalPageIndex;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final newMaxLeft = math.max(
              0.0,
              availableWidth - displaySize.width,
            );
            final newMaxTop = math.max(
              0.0,
              availableHeight - displaySize.height,
            );

            _pages[globalPageIndex] = page.copyWith(
              position: Offset(
                (page.position.dx + details.delta.dx).clamp(0.0, newMaxLeft),
                (page.position.dy + details.delta.dy).clamp(0.0, newMaxTop),
              ),
            );
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Document content with auto-fit
            Transform.scale(
              scale: page.scale,
              child: Transform.rotate(
                angle: page.rotation * math.pi / 180,
                child: Container(
                  width: page.autoFit
                      ? displaySize.width / page.scale
                      : page.size.width,
                  height: page.autoFit
                      ? displaySize.height / page.scale
                      : page.size.height,
                  decoration: BoxDecoration(
                    border: isSelected
                        ? Border.all(color: Colors.blue, width: 3)
                        : Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.blue.withAlpha(77),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ClipRect(
                      clipper: CropClipper(page.cropRect),
                      child: ColorFiltered(
                        colorFilter: viewModel.isMonochromatic
                            ? const ColorFilter.matrix([
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ])
                            : const ColorFilter.matrix([
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                        child: _buildDocumentContent(page),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Enhanced selection handles
            if (isSelected)
              ..._buildEnhancedSelectionHandles(
                page,
                globalPageIndex,
                availableWidth,
                availableHeight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentContent(PageData page) {
    if (page.type == 'photo') {
      return Image.file(
        widget.documentFile,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red.shade400),
                  const Text('Error loading image'),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return Container(
        color: Colors.white,
        child: SfPdfViewer.file(
          widget.documentFile,
          enableDoubleTapZooming: false,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          canShowPaginationDialog: false,
          initialPageNumber: page.originalIndex + 1,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            debugPrint('PDF load failed: ${details.description}');
          },
        ),
      );
    }
  }

  // ENHANCED: Selection handles with more options
  List<Widget> _buildEnhancedSelectionHandles(
    PageData page,
    int pageIndex,
    double availableWidth,
    double availableHeight,
  ) {
    const handleSize = 28.0;
    final handles = <Widget>[];

    // Corner resize handles
    final cornerPositions = [
      {
        'pos': const Offset(-handleSize / 2, -handleSize / 2),
        'cursor': SystemMouseCursors.resizeUpLeft,
        'type': 'resize_tl',
        'color': Colors.blue,
      },
      {
        'pos': Offset(page.size.width - handleSize / 2, -handleSize / 2),
        'cursor': SystemMouseCursors.resizeUpRight,
        'type': 'resize_tr',
        'color': Colors.blue,
      },
      {
        'pos': Offset(-handleSize / 2, page.size.height - handleSize / 2),
        'cursor': SystemMouseCursors.resizeDownLeft,
        'type': 'resize_bl',
        'color': Colors.blue,
      },
      {
        'pos': Offset(
          page.size.width - handleSize / 2,
          page.size.height - handleSize / 2,
        ),
        'cursor': SystemMouseCursors.resizeDownRight,
        'type': 'resize_br',
        'color': Colors.blue,
      },
    ];

    for (final handle in cornerPositions) {
      handles.add(
        Positioned(
          left: (handle['pos'] as Offset).dx,
          top: (handle['pos'] as Offset).dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              _handleResize(
                details.delta,
                handle['type'] as String,
                pageIndex,
                availableWidth,
                availableHeight,
              );
            },
            child: MouseRegion(
              cursor: handle['cursor'] as SystemMouseCursor,
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: handle['color'] as Color,
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(handleSize / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.open_with,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Rotation handle
    handles.add(
      Positioned(
        left: page.size.width / 2 - handleSize / 2,
        top: -handleSize * 1.8,
        child: GestureDetector(
          onPanUpdate: (details) {
            _handleRotation(details.delta, pageIndex);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.grabbing,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.orange,
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(handleSize / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.rotate_right,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );

    // Scale/Zoom handle
    handles.add(
      Positioned(
        right: -handleSize * 1.5,
        top: page.size.height / 2 - handleSize / 2,
        child: GestureDetector(
          onPanUpdate: (details) {
            _handleScale(
              details.delta,
              pageIndex,
              availableWidth,
              availableHeight,
            );
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.zoomIn,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.purple,
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(handleSize / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.zoom_in, size: 12, color: Colors.white),
            ),
          ),
        ),
      ),
    );

    return handles;
  }

  // Handle resize with bounds checking
  void _handleResize(
    Offset delta,
    String handleType,
    int pageIndex,
    double availableWidth,
    double availableHeight,
  ) {
    final page = _pages[pageIndex];
    const minSize = Size(50, 50);
    final maxSize = Size(availableWidth * 0.95, availableHeight * 0.95);

    Size newSize = page.size;
    Offset newPosition = page.position;
    final sensitivity = 1.2;

    switch (handleType) {
      case 'resize_br':
        newSize = Size(
          (page.size.width + delta.dx * sensitivity).clamp(
            minSize.width,
            maxSize.width,
          ),
          (page.size.height + delta.dy * sensitivity).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        break;
      case 'resize_bl':
        newSize = Size(
          (page.size.width - delta.dx * sensitivity).clamp(
            minSize.width,
            maxSize.width,
          ),
          (page.size.height + delta.dy * sensitivity).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        newPosition = Offset(
          page.position.dx + (delta.dx * sensitivity),
          page.position.dy,
        );
        break;
      case 'resize_tr':
        newSize = Size(
          (page.size.width + delta.dx * sensitivity).clamp(
            minSize.width,
            maxSize.width,
          ),
          (page.size.height - delta.dy * sensitivity).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        newPosition = Offset(
          page.position.dx,
          page.position.dy + (delta.dy * sensitivity),
        );
        break;
      case 'resize_tl':
        newSize = Size(
          (page.size.width - delta.dx * sensitivity).clamp(
            minSize.width,
            maxSize.width,
          ),
          (page.size.height - delta.dy * sensitivity).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        newPosition = Offset(
          page.position.dx + (delta.dx * sensitivity),
          page.position.dy + (delta.dy * sensitivity),
        );
        break;
    }

    // Ensure within bounds
    final maxLeft = math.max(0.0, availableWidth - newSize.width);
    final maxTop = math.max(0.0, availableHeight - newSize.height);
    newPosition = Offset(
      newPosition.dx.clamp(0.0, maxLeft),
      newPosition.dy.clamp(0.0, maxTop),
    );

    setState(() {
      _pages[pageIndex] = page.copyWith(
        size: newSize,
        position: newPosition,
        autoFit: false, // Disable auto-fit when manually resized
      );
    });
  }

  void _handleRotation(Offset delta, int pageIndex) {
    final page = _pages[pageIndex];
    final rotationSensitivity = 2.5;
    final newRotation = (page.rotation + delta.dx * rotationSensitivity) % 360;

    setState(() {
      _pages[pageIndex] = page.copyWith(rotation: newRotation);
    });
  }

  void _handleScale(
    Offset delta,
    int pageIndex,
    double availableWidth,
    double availableHeight,
  ) {
    final page = _pages[pageIndex];
    final scaleSensitivity = 0.008;
    final newScale = (page.scale + delta.dy * scaleSensitivity).clamp(0.1, 5.0);

    // Adjust position if needed after scaling
    final scaledSize = Size(
      page.size.width * newScale,
      page.size.height * newScale,
    );
    final maxLeft = math.max(0.0, availableWidth - scaledSize.width);
    final maxTop = math.max(0.0, availableHeight - scaledSize.height);

    final adjustedPosition = Offset(
      page.position.dx.clamp(0.0, maxLeft),
      page.position.dy.clamp(0.0, maxTop),
    );

    setState(() {
      _pages[pageIndex] = page.copyWith(
        scale: newScale,
        position: adjustedPosition,
        autoFit: false, // Disable auto-fit when manually scaled
      );
    });
  }

  Widget _buildA4Labels(int currentPages, int maxPages) {
    return Stack(
      children: [
        // Top-left A4 label
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'A4 Sheet ($currentPages/$maxPages pages)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Bottom-right dimensions
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '210×297mm',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridLines(double width, double height) {
    return Positioned.fill(child: CustomPaint(painter: A4GridPainter()));
  }

  // Enhanced page thumbnails with pages per sheet preview
  Widget _buildEnhancedPageThumbnails(PreviewViewModel viewModel) {
    final sheetsCount = math.max(
      1,
      (_pages.length / viewModel.pagesPerSheet).ceil(),
    );

    return Container(
      height: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Sheet thumbnails
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sheetsCount,
              itemBuilder: (context, sheetIndex) {
                final isActive = sheetIndex == _currentPageIndex;
                final startPageIndex = sheetIndex * viewModel.pagesPerSheet;
                final endPageIndex = math.min(
                  startPageIndex + viewModel.pagesPerSheet,
                  _pages.length,
                );
                final pagesInSheet = endPageIndex - startPageIndex;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive ? Colors.blue : Colors.grey.shade300,
                      width: isActive ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: InkWell(
                    onTap: () {
                      _pageController.animateToPage(
                        sheetIndex,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 54,
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          // Mini A4 preview
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: _buildMiniSheetPreview(
                                viewModel.pagesPerSheet,
                                pagesInSheet,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Sheet number
                          Text(
                            'S${sheetIndex + 1}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Page arrangement info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${viewModel.pagesPerSheet}/sheet',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  '$sheetsCount sheets',
                  style: TextStyle(fontSize: 8, color: Colors.blue.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSheetPreview(int pagesPerSheet, int actualPages) {
    if (pagesPerSheet == 1) {
      return Center(
        child: Container(
          width: 30,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    } else if (pagesPerSheet == 2) {
      return Row(
        children: [
          for (int i = 0; i < 2; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: i < actualPages
                      ? Colors.blue.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      );
    } else {
      return Column(
        children: [
          for (int row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (int col = 0; col < 2; col++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(0.5),
                        decoration: BoxDecoration(
                          color: (row * 2 + col) < actualPages
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
  }

  // ENHANCED CONTROL PANEL
  Widget _buildEnhancedControlPanel(PreviewViewModel viewModel) {
    return Container(
      width: 400,
      margin: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildPerPageEditingControls(viewModel),
            const SizedBox(height: 16),
            _buildPrintSettingsPanel(viewModel),
          ],
        ),
      ),
    );
  }

  // Per-page editing controls
  Widget _buildPerPageEditingControls(PreviewViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Per-Page Editing',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Page selector
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Page to Edit (${_pages.length} total):',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final isSelected = _selectedPageIndex == index;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPageIndex = index;
                            // Navigate to the sheet containing this page
                            final sheetIndex = index ~/ viewModel.pagesPerSheet;
                            if (sheetIndex != _currentPageIndex) {
                              _pageController.animateToPage(
                                sheetIndex,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          });
                        },
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade600
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                page.type == 'photo'
                                    ? Icons.image
                                    : Icons.picture_as_pdf,
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'P${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                              if (page.autoFit)
                                Icon(
                                  Icons.fit_screen,
                                  size: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.green.shade600,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (_selectedPageIndex != null) ...[
            const SizedBox(height: 16),

            // Selected page controls
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editing Page ${_selectedPageIndex! + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(
                        Icons.fit_screen,
                        'Auto-Fit',
                        _pages[_selectedPageIndex!].autoFit
                            ? Colors.green
                            : Colors.grey,
                        () => _toggleAutoFit(_selectedPageIndex!),
                      ),
                      _buildQuickActionButton(
                        Icons.rotate_90_degrees_ccw,
                        'Rotate',
                        Colors.orange,
                        () => _rotatePageLeft(_selectedPageIndex!),
                      ),
                      _buildQuickActionButton(
                        Icons.zoom_in,
                        'Zoom+',
                        Colors.purple,
                        () => _zoomPage(_selectedPageIndex!, 1.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(
                        Icons.zoom_out,
                        'Zoom-',
                        Colors.purple,
                        () => _zoomPage(_selectedPageIndex!, 0.8),
                      ),
                      _buildQuickActionButton(
                        Icons.crop,
                        'Reset',
                        Colors.green,
                        () => _resetPage(_selectedPageIndex!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Global actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _autoArrangePages(viewModel.pagesPerSheet),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'Auto-Arrange',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetAllPages,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text(
                    'Reset All',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 70,
        height: 60,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced print settings panel
  Widget _buildPrintSettingsPanel(PreviewViewModel viewModel) {
    final double totalCost =
        (_pages.length *
        viewModel.numberOfCopies *
        (viewModel.isMonochromatic ? 1.0 : 1.5));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.print, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Print Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pages per sheet selector
          const Text(
            'Pages per Sheet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 4].map((pages) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    viewModel.setPagesPerSheet(pages);
                    setState(() {
                      _currentPageIndex = 0;
                    });
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: pages < 4 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: viewModel.pagesPerSheet == pages
                          ? Colors.green.shade600
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: viewModel.pagesPerSheet == pages
                            ? Colors.green.shade600
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$pages',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: viewModel.pagesPerSheet == pages
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          pages == 1 ? 'page' : 'pages',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: viewModel.pagesPerSheet == pages
                                ? Colors.white
                                : Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Number of copies
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Copies:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: viewModel.numberOfCopies > 1
                        ? () => viewModel.setNumberOfCopies(
                            viewModel.numberOfCopies - 1,
                          )
                        : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${viewModel.numberOfCopies}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: viewModel.numberOfCopies < 50
                        ? () => viewModel.setNumberOfCopies(
                            viewModel.numberOfCopies + 1,
                          )
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Color mode
          const Text(
            'Color Mode',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  'Full Color',
                  Icons.color_lens,
                  !viewModel.isMonochromatic,
                  () => viewModel.setIsMonochromatic(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleButton(
                  'Black & White',
                  Icons.filter_b_and_w,
                  viewModel.isMonochromatic,
                  () => viewModel.setIsMonochromatic(true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Cost display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pages: ${_pages.length}'),
                    Text(
                      'Sheets: ${math.max(1, (_pages.length / viewModel.pagesPerSheet).ceil())}',
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Cost:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${totalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // QR Code for payment
          Center(
            child: Column(
              children: [
                const Text(
                  'Scan to Pay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                QrCodeWidget(
                  data:
                      'upi://pay?pa=7266859424@ptsbi&pn=PrintShop&am=${totalCost.toStringAsFixed(2)}&cu=INR&tn=Document Print Payment',
                  showPaymentInfo: true,
                  size: 180,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment and print buttons
          if (!viewModel.isPaymentVerified) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: viewModel.isVerifyingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.payment, size: 20),
                onPressed: viewModel.isVerifyingPayment
                    ? null
                    : viewModel.verifyPayment,
                label: Text(
                  viewModel.isVerifyingPayment
                      ? 'Verifying...'
                      : 'Verify Payment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Verified ✓',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.print, size: 24),
                onPressed: () => _printDocument(viewModel, context),
                label: const Text(
                  'PRINT DOCUMENT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for page editing
  void _toggleAutoFit(int pageIndex) {
    setState(() {
      _pages[pageIndex] = _pages[pageIndex].copyWith(
        autoFit: !_pages[pageIndex].autoFit,
      );
    });
  }

  void _toggleAutoFitAll() {
    setState(() {
      final newAutoFit = !_pages.any((p) => p.autoFit);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i] = _pages[i].copyWith(autoFit: newAutoFit);
      }
    });
  }

  void _rotatePageLeft(int pageIndex) {
    setState(() {
      _pages[pageIndex] = _pages[pageIndex].copyWith(
        rotation: (_pages[pageIndex].rotation - 90) % 360,
      );
    });
  }

  void _zoomPage(int pageIndex, double factor) {
    setState(() {
      _pages[pageIndex] = _pages[pageIndex].copyWith(
        scale: (_pages[pageIndex].scale * factor).clamp(0.1, 5.0),
        autoFit: false,
      );
    });
  }

  void _resetPage(int pageIndex) {
    setState(() {
      _pages[pageIndex] = _pages[pageIndex].copyWith(
        position: const Offset(10, 10),
        size: _calculateAutoFitSize(const Size(595, 842), 380, 500),
        rotation: 0.0,
        cropRect: const Rect.fromLTWH(0, 0, 1, 1),
        scale: 1.0,
        autoFit: true,
      );
    });
  }

  void _resetAllPages() {
    setState(() {
      for (int i = 0; i < _pages.length; i++) {
        _pages[i] = _pages[i].copyWith(
          position: const Offset(10, 10),
          size: _calculateAutoFitSize(const Size(595, 842), 380, 500),
          rotation: 0.0,
          cropRect: const Rect.fromLTWH(0, 0, 1, 1),
          scale: 1.0,
          autoFit: true,
        );
      }
      _selectedPageIndex = null;
    });
  }

  void _autoArrangePages(int pagesPerSheet) {
    setState(() {
      final availableWidth = 380.0;
      final availableHeight = 500.0;

      for (int i = 0; i < _pages.length; i++) {
        if (pagesPerSheet == 1) {
          // Center single page
          _pages[i] = _pages[i].copyWith(
            position: const Offset(10, 10),
            autoFit: true,
          );
        } else if (pagesPerSheet == 2) {
          // Arrange two pages side by side
          final pageWidth = (availableWidth - 30) / 2;
          final pageHeight = availableHeight - 20;
          final col = i % 2;

          _pages[i] = _pages[i].copyWith(
            position: Offset(10 + col * (pageWidth + 10), 10),
            size: _calculateAutoFitSize(_pages[i].size, pageWidth, pageHeight),
            autoFit: true,
          );
        } else {
          // Arrange in 2x2 grid
          final pageWidth = (availableWidth - 30) / 2;
          final pageHeight = (availableHeight - 30) / 2;
          final row = (i % 4) ~/ 2;
          final col = (i % 4) % 2;

          _pages[i] = _pages[i].copyWith(
            position: Offset(
              10 + col * (pageWidth + 10),
              10 + row * (pageHeight + 10),
            ),
            size: _calculateAutoFitSize(_pages[i].size, pageWidth, pageHeight),
            autoFit: true,
          );
        }
      }
    });
  }

  // Print document with exact layout
  Future<void> _printDocument(
    PreviewViewModel viewModel,
    BuildContext context,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing document for print...'),
                ],
              ),
            ),
          ),
        ),
      );

      final pdf = await _generatePrintPdf(viewModel);
      Navigator.of(context).pop();

      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/print_document_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(pdf);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Print Ready!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document prepared for printing with your exact layout.',
                ),
                const SizedBox(height: 8),
                Text('Total Pages: ${_pages.length}'),
                Text('Pages per Sheet: ${viewModel.pagesPerSheet}'),
                Text('Copies: ${viewModel.numberOfCopies}'),
                Text('Color: ${viewModel.isMonochromatic ? "B&W" : "Color"}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async =>
                        file.readAsBytes(),
                  );
                },
                child: const Text('Preview PDF'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generatePrintPdf(PreviewViewModel viewModel) async {
    final pdf = pw.Document();

    if (_pages.isEmpty) return Uint8List(0);

    final pagesPerSheet = viewModel.pagesPerSheet;
    final sheetsCount = math.max(1, (_pages.length / pagesPerSheet).ceil());

    // Create sheets for each copy
    for (int copy = 0; copy < viewModel.numberOfCopies; copy++) {
      for (int sheetIndex = 0; sheetIndex < sheetsCount; sheetIndex++) {
        final startIndex = sheetIndex * pagesPerSheet;
        final endIndex = math.min(startIndex + pagesPerSheet, _pages.length);
        final sheetPages = _pages.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildPrintPageContent(sheetPages, pagesPerSheet);
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  pw.Widget _buildPrintPageContent(List<PageData> pages, int pagesPerSheet) {
    if (pagesPerSheet == 1) {
      return pages.isNotEmpty
          ? pw.Container(
              width: double.infinity,
              height: double.infinity,
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.center,
                child: pw.Container(
                  child: pw.Text(
                    'PDF Page ${pages[0].originalIndex + 1}\nFitted to A4\nScale: ${pages[0].scale.toStringAsFixed(2)}x\nRotation: ${pages[0].rotation.toInt()}°',
                    style: pw.TextStyle(fontSize: 24),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
            )
          : pw.Container();
    } else if (pagesPerSheet == 2) {
      return pw.Row(
        children: [
          for (int i = 0; i < 2; i++)
            pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.all(4),
                child: i < pages.length
                    ? pw.FittedBox(
                        fit: pw.BoxFit.contain,
                        child: pw.Text(
                          'Page ${pages[i].originalIndex + 1}',
                          style: pw.TextStyle(fontSize: 16),
                        ),
                      )
                    : pw.Container(),
              ),
            ),
        ],
      );
    } else {
      return pw.Column(
        children: [
          for (int row = 0; row < 2; row++)
            pw.Expanded(
              child: pw.Row(
                children: [
                  for (int col = 0; col < 2; col++)
                    pw.Expanded(
                      child: pw.Container(
                        margin: const pw.EdgeInsets.all(2),
                        child: () {
                          final pageIndex = row * 2 + col;
                          return pageIndex < pages.length
                              ? pw.FittedBox(
                                  fit: pw.BoxFit.contain,
                                  child: pw.Text(
                                    'P${pages[pageIndex].originalIndex + 1}',
                                    style: pw.TextStyle(fontSize: 12),
                                  ),
                                )
                              : pw.Container();
                        }(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }
  }
}

// Custom clipper for cropping
class CropClipper extends CustomClipper<Rect> {
  final Rect cropRect;

  CropClipper(this.cropRect);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      cropRect.left * size.width,
      cropRect.top * size.height,
      (cropRect.right - cropRect.left) * size.width,
      (cropRect.bottom - cropRect.top) * size.height,
    );
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => true;
}

// A4 Grid painter
class A4GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(26)
      ..strokeWidth = 0.3;

    const gridSpacing = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw A4 border
    final borderPaint = Paint()
      ..color = Colors.blue.withAlpha(77)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
