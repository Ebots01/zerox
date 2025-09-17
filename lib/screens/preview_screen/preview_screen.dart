// lib/screens/preview_screen/preview_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
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

// Model for individual page data
class PageData {
  final int originalIndex;
  final String type; // 'photo' or 'pdf'
  Offset position;
  Size size;
  double rotation;
  Rect cropRect;

  PageData({
    required this.originalIndex,
    required this.type,
    this.position = Offset.zero,
    this.size = const Size(300, 400),
    this.rotation = 0.0,
    this.cropRect = const Rect.fromLTWH(0, 0, 1, 1),
  });

  PageData copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    Rect? cropRect,
  }) {
    return PageData(
      originalIndex: originalIndex,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      cropRect: cropRect ?? this.cropRect,
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
  late List<PageData> _pages;
  int _currentPageIndex = 0;
  int? _selectedPageIndex;

  @override
  void initState() {
    super.initState();
    _initializePages();
  }

  void _initializePages() {
    final filePath = widget.documentFile.path.toLowerCase();
    if (_isPhotoFile) {
      // Single photo
      _pages = [
        PageData(
          originalIndex: 0,
          type: 'photo',
          position: const Offset(50, 50),
          size: const Size(300, 400),
        ),
      ];
    } else {
      // PDF - initialize with estimated page count (you might want to get actual count)
      _pages = List.generate(
        5,
        (index) => PageData(
          originalIndex: index,
          type: 'pdf',
          position: const Offset(50, 50),
          size: const Size(300, 400),
        ),
      );
    }
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
    return ChangeNotifierProvider(
      create: (_) => PreviewViewModel(),
      child: Consumer<PreviewViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: _buildAppBar(),
            body: Row(
              children: [
                // Left side - Preview area
                Expanded(flex: 3, child: _buildPreviewArea(viewModel)),
                // Right side - Controls
                _buildControlPanel(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
        // Page counter
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51), // 20% opacity
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_currentPageIndex + 1} / ${_pages.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(PreviewViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Page navigation header
          _buildPageNavigationHeader(),
          // Main preview area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                  _selectedPageIndex = null;
                });
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _buildSingleA4Sheet(viewModel, index);
              },
            ),
          ),
          // Page thumbnails for reordering
          _buildPageThumbnails(),
        ],
      ),
    );
  }

  Widget _buildPageNavigationHeader() {
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
            child: Center(
              child: Text(
                'Page ${_currentPageIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPageIndex < _pages.length - 1
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

  Widget _buildSingleA4Sheet(PreviewViewModel viewModel, int pageIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate A4 dimensions
        const double a4Ratio = 210.0 / 297.0;
        double sheetWidth = constraints.maxWidth - 64;
        double sheetHeight = sheetWidth / a4Ratio;

        if (sheetHeight > constraints.maxHeight - 64) {
          sheetHeight = constraints.maxHeight - 64;
          sheetWidth = sheetHeight * a4Ratio;
        }

        return Center(
          child: Container(
            width: sheetWidth,
            height: sheetHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Grid lines
                  _buildGridLines(sheetWidth, sheetHeight),
                  // Document content
                  _buildEditableDocument(
                    viewModel,
                    pageIndex,
                    sheetWidth,
                    sheetHeight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridLines(double width, double height) {
    return Positioned.fill(child: CustomPaint(painter: GridPainter()));
  }

  Widget _buildEditableDocument(
    PreviewViewModel viewModel,
    int pageIndex,
    double sheetWidth,
    double sheetHeight,
  ) {
    final page = _pages[pageIndex];
    final isSelected = _selectedPageIndex == pageIndex;

    return Positioned(
      left: page.position.dx.clamp(0, sheetWidth - page.size.width),
      top: page.position.dy.clamp(0, sheetHeight - page.size.height),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPageIndex = pageIndex;
          });
        },
        onPanStart: (details) {
          setState(() {
            _selectedPageIndex = pageIndex;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _pages[pageIndex] = page.copyWith(
              position: Offset(
                (page.position.dx + details.delta.dx).clamp(
                  0,
                  sheetWidth - page.size.width,
                ),
                (page.position.dy + details.delta.dy).clamp(
                  0,
                  sheetHeight - page.size.height,
                ),
              ),
            );
          });
        },
        child: Stack(
          children: [
            // Document content
            Transform.rotate(
              angle: page.rotation * pi / 180,
              child: Container(
                width: page.size.width,
                height: page.size.height,
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : Border.all(color: Colors.transparent),
                ),
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
            // Selection handles
            if (isSelected)
              ..._buildSelectionHandles(
                page,
                pageIndex,
                sheetWidth,
                sheetHeight,
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
        width: page.size.width,
        height: page.size.height,
        filterQuality: FilterQuality.high,
      );
    } else {
      return SfPdfViewer.file(
        widget.documentFile,
        enableDoubleTapZooming: false,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        canShowPaginationDialog: false,
        initialPageNumber: page.originalIndex + 1,
      );
    }
  }

  List<Widget> _buildSelectionHandles(
    PageData page,
    int pageIndex,
    double sheetWidth,
    double sheetHeight,
  ) {
    const handleSize = 24.0;
    final handles = <Widget>[];

    // Corner resize handles
    final cornerPositions = [
      {
        'pos': const Offset(-handleSize / 2, -handleSize / 2),
        'cursor': SystemMouseCursors.resizeUpLeft,
        'type': 'resize_tl',
      },
      {
        'pos': Offset(page.size.width - handleSize / 2, -handleSize / 2),
        'cursor': SystemMouseCursors.resizeUpRight,
        'type': 'resize_tr',
      },
      {
        'pos': Offset(-handleSize / 2, page.size.height - handleSize / 2),
        'cursor': SystemMouseCursors.resizeDownLeft,
        'type': 'resize_bl',
      },
      {
        'pos': Offset(
          page.size.width - handleSize / 2,
          page.size.height - handleSize / 2,
        ),
        'cursor': SystemMouseCursors.resizeDownRight,
        'type': 'resize_br',
      },
    ];

    for (final handle in cornerPositions) {
      handles.add(
        Positioned(
          left: (handle['pos'] as Offset).dx,
          top: (handle['pos'] as Offset).dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              _handleResize(details.delta, handle['type'] as String, pageIndex);
            },
            child: MouseRegion(
              cursor: handle['cursor'] as SystemMouseCursor,
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(handleSize / 2),
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
        top: -handleSize * 2,
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

    // Crop handles (on edges)
    final cropPositions = [
      {'pos': Offset(page.size.width / 4, -handleSize / 2), 'type': 'crop_top'},
      {
        'pos': Offset(3 * page.size.width / 4, -handleSize / 2),
        'type': 'crop_top',
      },
      {
        'pos': Offset(page.size.width + handleSize / 2, page.size.height / 4),
        'type': 'crop_right',
      },
      {
        'pos': Offset(
          page.size.width + handleSize / 2,
          3 * page.size.height / 4,
        ),
        'type': 'crop_right',
      },
      {
        'pos': Offset(page.size.width / 4, page.size.height + handleSize / 2),
        'type': 'crop_bottom',
      },
      {
        'pos': Offset(
          3 * page.size.width / 4,
          page.size.height + handleSize / 2,
        ),
        'type': 'crop_bottom',
      },
      {
        'pos': Offset(-handleSize / 2, page.size.height / 4),
        'type': 'crop_left',
      },
      {
        'pos': Offset(-handleSize / 2, 3 * page.size.height / 4),
        'type': 'crop_left',
      },
    ];

    for (final handle in cropPositions) {
      handles.add(
        Positioned(
          left: (handle['pos'] as Offset).dx,
          top: (handle['pos'] as Offset).dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              _handleCrop(details.delta, handle['type'] as String, pageIndex);
            },
            child: Container(
              width: handleSize * 0.7,
              height: handleSize * 0.7,
              decoration: BoxDecoration(
                color: Colors.green,
                border: Border.all(color: Colors.white, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.crop, size: 8, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return handles;
  }

  void _handleResize(Offset delta, String handleType, int pageIndex) {
    final page = _pages[pageIndex];
    const minSize = Size(50, 50);
    const maxSize = Size(500, 700);

    Size newSize = page.size;
    Offset newPosition = page.position;

    switch (handleType) {
      case 'resize_br':
        newSize = Size(
          (page.size.width + delta.dx).clamp(minSize.width, maxSize.width),
          (page.size.height + delta.dy).clamp(minSize.height, maxSize.height),
        );
        break;
      case 'resize_bl':
        newSize = Size(
          (page.size.width - delta.dx).clamp(minSize.width, maxSize.width),
          (page.size.height + delta.dy).clamp(minSize.height, maxSize.height),
        );
        newPosition = Offset(page.position.dx + delta.dx, page.position.dy);
        break;
      case 'resize_tr':
        newSize = Size(
          (page.size.width + delta.dx).clamp(minSize.width, maxSize.width),
          (page.size.height - delta.dy).clamp(minSize.height, maxSize.height),
        );
        newPosition = Offset(page.position.dx, page.position.dy + delta.dy);
        break;
      case 'resize_tl':
        newSize = Size(
          (page.size.width - delta.dx).clamp(minSize.width, maxSize.width),
          (page.size.height - delta.dy).clamp(minSize.height, maxSize.height),
        );
        newPosition = Offset(
          page.position.dx + delta.dx,
          page.position.dy + delta.dy,
        );
        break;
    }

    setState(() {
      _pages[pageIndex] = page.copyWith(size: newSize, position: newPosition);
    });
  }

  void _handleRotation(Offset delta, int pageIndex) {
    final page = _pages[pageIndex];
    final rotationSensitivity = 2.0;
    final newRotation = (page.rotation + delta.dx * rotationSensitivity) % 360;

    setState(() {
      _pages[pageIndex] = page.copyWith(rotation: newRotation);
    });
  }

  void _handleCrop(Offset delta, String cropType, int pageIndex) {
    final page = _pages[pageIndex];
    final cropSensitivity = 0.002;
    Rect newCropRect = page.cropRect;

    switch (cropType) {
      case 'crop_top':
        newCropRect = Rect.fromLTRB(
          page.cropRect.left,
          (page.cropRect.top + delta.dy * cropSensitivity).clamp(
            0.0,
            page.cropRect.bottom - 0.1,
          ),
          page.cropRect.right,
          page.cropRect.bottom,
        );
        break;
      case 'crop_bottom':
        newCropRect = Rect.fromLTRB(
          page.cropRect.left,
          page.cropRect.top,
          page.cropRect.right,
          (page.cropRect.bottom + delta.dy * cropSensitivity).clamp(
            page.cropRect.top + 0.1,
            1.0,
          ),
        );
        break;
      case 'crop_left':
        newCropRect = Rect.fromLTRB(
          (page.cropRect.left + delta.dx * cropSensitivity).clamp(
            0.0,
            page.cropRect.right - 0.1,
          ),
          page.cropRect.top,
          page.cropRect.right,
          page.cropRect.bottom,
        );
        break;
      case 'crop_right':
        newCropRect = Rect.fromLTRB(
          page.cropRect.left,
          page.cropRect.top,
          (page.cropRect.right + delta.dx * cropSensitivity).clamp(
            page.cropRect.left + 0.1,
            1.0,
          ),
          page.cropRect.bottom,
        );
        break;
    }

    setState(() {
      _pages[pageIndex] = page.copyWith(cropRect: newCropRect);
    });
  }

  Widget _buildPageThumbnails() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pages.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final page = _pages.removeAt(oldIndex);
            _pages.insert(newIndex, page);
          });
        },
        itemBuilder: (context, index) {
          final isActive = index == _currentPageIndex;
          return Container(
            key: ValueKey(index),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive ? Colors.blue : Colors.grey.shade300,
                width: isActive ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: InkWell(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: 56,
                height: 64,
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      _pages[index].type == 'photo'
                          ? Icons.image
                          : Icons.picture_as_pdf,
                      size: 12,
                      color: isActive ? Colors.blue : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(PreviewViewModel viewModel) {
    return Container(
      width: 350,
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildEditingControls(viewModel),
            const SizedBox(height: 20),
            _buildPrintOptions(viewModel, context),
          ],
        ),
      ),
    );
  }

  Widget _buildEditingControls(PreviewViewModel viewModel) {
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
              Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Editing Tools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick actions for selected page
          if (_selectedPageIndex != null) ...[
            const Text(
              'Selected Page Actions',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  Icons.rotate_90_degrees_ccw,
                  'Rotate Left',
                  () => _quickRotateLeft(),
                ),
                _buildControlButton(
                  Icons.crop,
                  'Reset Crop',
                  () => _resetCrop(),
                ),
                _buildControlButton(
                  Icons.aspect_ratio,
                  'Reset Size',
                  () => _resetSize(),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Color mode
          const Text(
            'Color Mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  'Color',
                  Icons.color_lens,
                  !viewModel.isMonochromatic,
                  () => viewModel.setIsMonochromatic(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleButton(
                  'B&W',
                  Icons.filter_b_and_w,
                  viewModel.isMonochromatic,
                  () => viewModel.setIsMonochromatic(true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Reset button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                viewModel.resetSettings();
                _resetAllPages();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All'),
            ),
          ),
        ],
      ),
    );
  }

  void _quickRotateLeft() {
    if (_selectedPageIndex != null) {
      final page = _pages[_selectedPageIndex!];
      setState(() {
        _pages[_selectedPageIndex!] = page.copyWith(
          rotation: (page.rotation - 90) % 360,
        );
      });
    }
  }

  void _resetCrop() {
    if (_selectedPageIndex != null) {
      final page = _pages[_selectedPageIndex!];
      setState(() {
        _pages[_selectedPageIndex!] = page.copyWith(
          cropRect: const Rect.fromLTWH(0, 0, 1, 1),
        );
      });
    }
  }

  void _resetSize() {
    if (_selectedPageIndex != null) {
      final page = _pages[_selectedPageIndex!];
      setState(() {
        _pages[_selectedPageIndex!] = page.copyWith(
          size: const Size(300, 400),
          position: const Offset(50, 50),
        );
      });
    }
  }

  void _resetAllPages() {
    setState(() {
      for (int i = 0; i < _pages.length; i++) {
        _pages[i] = _pages[i].copyWith(
          position: const Offset(50, 50),
          size: const Size(300, 400),
          rotation: 0.0,
          cropRect: const Rect.fromLTWH(0, 0, 1, 1),
        );
      }
      _selectedPageIndex = null;
    });
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue.shade600, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
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
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOptions(PreviewViewModel viewModel, BuildContext context) {
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

          // Number of Copies
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Copies:',
                style: TextStyle(fontWeight: FontWeight.w600),
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

          // Total pages info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Pages:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_pages.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cost Display
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
                    Text(
                      'Pages (${_pages.length} × ${viewModel.numberOfCopies}):',
                    ),
                    Text(
                      '₹${(_pages.length * viewModel.numberOfCopies).toDouble()}',
                    ),
                  ],
                ),
                if (!viewModel.isMonochromatic) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Color Surcharge:'),
                      Text(
                        '₹${(_pages.length * viewModel.numberOfCopies * 0.5).toStringAsFixed(1)}',
                      ),
                    ],
                  ),
                ],
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
                      '₹${(_pages.length * viewModel.numberOfCopies * (viewModel.isMonochromatic ? 1.0 : 1.5)).toStringAsFixed(2)}',
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

          // QR Code
          Center(
            child: Column(
              children: [
                const Text(
                  'Scan to Pay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                QrCodeWidget(
                  data:
                      'upi://pay?pa=merchant@paytm&pn=PrintShop&am=${(_pages.length * viewModel.numberOfCopies * (viewModel.isMonochromatic ? 1.0 : 1.5)).toStringAsFixed(2)}&cu=INR&tn=Document Print Payment',
                  showCopyButton: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Payment and Print buttons
          if (!viewModel.isPaymentVerified) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    : const Icon(Icons.payment),
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
                  Icon(Icons.check_circle, color: Colors.green.shade600),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

      final pdf = pw.Document();

      // Process each page
      for (int i = 0; i < _pages.length; i++) {
        // Create individual page screenshots
        // This would need to be implemented based on your specific requirements
        for (int copy = 0; copy < viewModel.numberOfCopies; copy++) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Text('Page ${i + 1} - Copy ${copy + 1}'),
                );
              },
            ),
          );
        }
      }

      Navigator.of(context).pop();

      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/printed_document_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Print Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Document has been processed and sent to printer.'),
                const SizedBox(height: 8),
                Text('Pages: ${_pages.length}'),
                Text('Copies: ${viewModel.numberOfCopies}'),
                Text(
                  'Color: ${viewModel.isMonochromatic ? "Black & White" : "Full Color"}',
                ),
                Text(
                  'Total cost: ₹${(_pages.length * viewModel.numberOfCopies * (viewModel.isMonochromatic ? 1.0 : 1.5)).toStringAsFixed(2)}',
                ),
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
                child: const Text('View/Download PDF'),
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
            content: Text('Error processing document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

// Grid painter for guidelines
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
          .withAlpha(51) // 20% opacity
      ..strokeWidth = 0.5;

    const gridSpacing = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
