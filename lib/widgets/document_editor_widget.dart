// lib/widgets/document_editor_widget.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Enhanced page transformation data
class PageTransformation {
  final Offset position;
  final Size size;
  final double rotation;
  final Rect cropRect;
  final double scale;
  final bool isSelected;

  const PageTransformation({
    this.position = Offset.zero,
    this.size = const Size(300, 400),
    this.rotation = 0.0,
    this.cropRect = const Rect.fromLTWH(0, 0, 1, 1),
    this.scale = 1.0,
    this.isSelected = false,
  });

  PageTransformation copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    Rect? cropRect,
    double? scale,
    bool? isSelected,
  }) {
    return PageTransformation(
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      cropRect: cropRect ?? this.cropRect,
      scale: scale ?? this.scale,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class EnhancedDocumentEditorWidget extends StatefulWidget {
  final File documentFile;
  final int pageIndex;
  final PageTransformation transformation;
  final bool isMonochromatic;
  final double brightness;
  final double contrast;
  final Size containerSize;
  final Function(PageTransformation)? onTransformationChanged;
  final Function(GlobalKey)? onKeyGenerated;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const EnhancedDocumentEditorWidget({
    super.key,
    required this.documentFile,
    required this.pageIndex,
    this.transformation = const PageTransformation(),
    this.isMonochromatic = false,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.containerSize = const Size(400, 566),
    this.onTransformationChanged,
    this.onKeyGenerated,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  State<EnhancedDocumentEditorWidget> createState() =>
      _EnhancedDocumentEditorWidgetState();
}

class _EnhancedDocumentEditorWidgetState
    extends State<EnhancedDocumentEditorWidget> {
  final GlobalKey _contentKey = GlobalKey();
  late PageTransformation _currentTransformation;
  bool _isDragging = false;
  bool _isResizing = false;
  bool _isRotating = false;
  String? _activeHandle;
  Offset? _lastPanPosition;
  double? _initialRotation;

  @override
  void initState() {
    super.initState();
    _currentTransformation = widget.transformation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onKeyGenerated?.call(_contentKey);
    });
  }

  @override
  void didUpdateWidget(EnhancedDocumentEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformation != widget.transformation) {
      _currentTransformation = widget.transformation;
    }
  }

  bool get _isPhotoFile {
    final path = widget.documentFile.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.bmp');
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _contentKey,
      child: Container(
        width: widget.containerSize.width,
        height: widget.containerSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main document content
            _buildDocumentContent(),

            // Selection handles and controls
            if (_currentTransformation.isSelected)
              ..._buildInteractionHandles(),

            // Transformation info overlay (debug mode)
            if (_currentTransformation.isSelected) _buildInfoOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentContent() {
    return Positioned(
      left: _currentTransformation.position.dx,
      top: _currentTransformation.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Transform.scale(
          scale: _currentTransformation.scale,
          child: Transform.rotate(
            angle: _currentTransformation.rotation * math.pi / 180,
            child: Container(
              width: _currentTransformation.size.width,
              height: _currentTransformation.size.height,
              decoration: BoxDecoration(
                border: _currentTransformation.isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(4),
                boxShadow: _currentTransformation.isSelected
                    ? [
                        BoxShadow(
                          color: Colors.blue.withAlpha(51),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ClipRect(
                  clipper: CropClipper(_currentTransformation.cropRect),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                    child: _buildFileContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent() {
    if (_isPhotoFile) {
      return Image.file(
        widget.documentFile,
        fit: BoxFit.cover,
        width: _currentTransformation.size.width,
        height: _currentTransformation.size.height,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
      );
    } else {
      return SfPdfViewer.file(
        widget.documentFile,
        enableDoubleTapZooming: false,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        canShowPaginationDialog: false,
        enableTextSelection: false,
        canShowPasswordDialog: false,
        pageSpacing: 0,
        initialPageNumber: widget.pageIndex + 1,
      );
    }
  }

  Widget _buildErrorPlaceholder() {
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
            'Failed to load content',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<double> _buildColorMatrix() {
    final brightness = widget.brightness;
    final contrast = 1.0 + widget.contrast;

    if (widget.isMonochromatic) {
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

  List<Widget> _buildInteractionHandles() {
    const handleSize = 24.0;
    final handles = <Widget>[];

    // Corner resize handles
    final corners = [
      {
        'pos': const Offset(-handleSize / 2, -handleSize / 2),
        'handle': 'tl',
        'cursor': SystemMouseCursors.resizeUpLeft,
        'color': Colors.blue,
      },
      {
        'pos': Offset(
          _currentTransformation.size.width - handleSize / 2,
          -handleSize / 2,
        ),
        'handle': 'tr',
        'cursor': SystemMouseCursors.resizeUpRight,
        'color': Colors.blue,
      },
      {
        'pos': Offset(
          -handleSize / 2,
          _currentTransformation.size.height - handleSize / 2,
        ),
        'handle': 'bl',
        'cursor': SystemMouseCursors.resizeDownLeft,
        'color': Colors.blue,
      },
      {
        'pos': Offset(
          _currentTransformation.size.width - handleSize / 2,
          _currentTransformation.size.height - handleSize / 2,
        ),
        'handle': 'br',
        'cursor': SystemMouseCursors.resizeDownRight,
        'color': Colors.blue,
      },
    ];

    for (final corner in corners) {
      handles.add(
        _buildHandle(
          position: corner['pos'] as Offset,
          size: handleSize,
          color: corner['color'] as Color,
          cursor: corner['cursor'] as SystemMouseCursor,
          icon: Icons.open_with,
          handleType: corner['handle'] as String,
        ),
      );
    }

    // Edge handles for cropping
    final edges = [
      {
        'pos': Offset(
          _currentTransformation.size.width / 2 - handleSize / 4,
          -handleSize / 3,
        ),
        'handle': 'crop_top',
        'color': Colors.green,
      },
      {
        'pos': Offset(
          _currentTransformation.size.width + handleSize / 3,
          _currentTransformation.size.height / 2 - handleSize / 4,
        ),
        'handle': 'crop_right',
        'color': Colors.green,
      },
      {
        'pos': Offset(
          _currentTransformation.size.width / 2 - handleSize / 4,
          _currentTransformation.size.height + handleSize / 3,
        ),
        'handle': 'crop_bottom',
        'color': Colors.green,
      },
      {
        'pos': Offset(
          -handleSize / 3,
          _currentTransformation.size.height / 2 - handleSize / 4,
        ),
        'handle': 'crop_left',
        'color': Colors.green,
      },
    ];

    for (final edge in edges) {
      handles.add(
        _buildHandle(
          position: edge['pos'] as Offset,
          size: handleSize * 0.6,
          color: edge['color'] as Color,
          cursor: SystemMouseCursors.precise,
          icon: Icons.crop,
          handleType: edge['handle'] as String,
        ),
      );
    }

    // Rotation handle
    handles.add(
      _buildHandle(
        position: Offset(
          _currentTransformation.size.width / 2 - handleSize / 2,
          -handleSize * 2,
        ),
        size: handleSize,
        color: Colors.orange,
        cursor: SystemMouseCursors.grabbing,
        icon: Icons.rotate_right,
        handleType: 'rotate',
      ),
    );

    // Scale handle
    handles.add(
      _buildHandle(
        position: Offset(
          _currentTransformation.size.width + handleSize,
          -handleSize,
        ),
        size: handleSize,
        color: Colors.purple,
        cursor: SystemMouseCursors.resizeUpDown,
        icon: Icons.zoom_out_map,
        handleType: 'scale',
      ),
    );

    return handles;
  }

  Widget _buildHandle({
    required Offset position,
    required double size,
    required Color color,
    required SystemMouseCursor cursor,
    required IconData icon,
    required String handleType,
  }) {
    final isActive = _activeHandle == handleType;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanStart: (details) => _handleStart(handleType, details),
          onPanUpdate: (details) => _handleUpdate(handleType, details),
          onPanEnd: (details) => _handleEnd(handleType, details),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive ? color.withAlpha(204) : color,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(size / 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: isActive ? 6 : 3,
                  offset: Offset(0, isActive ? 3 : 1),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.5, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      left: _currentTransformation.position.dx,
      top: _currentTransformation.position.dy - 30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(179),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${_currentTransformation.size.width.round()}×${_currentTransformation.size.height.round()} • ${_currentTransformation.rotation.round()}° • ${(_currentTransformation.scale * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_currentTransformation.isSelected) return;

    _isDragging = true;
    _lastPanPosition = details.localPosition;
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final newPosition = Offset(
      (_currentTransformation.position.dx + details.delta.dx).clamp(
        0,
        widget.containerSize.width - _currentTransformation.size.width,
      ),
      (_currentTransformation.position.dy + details.delta.dy).clamp(
        0,
        widget.containerSize.height - _currentTransformation.size.height,
      ),
    );

    _updateTransformation(
      _currentTransformation.copyWith(position: newPosition),
    );
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    _lastPanPosition = null;
    setState(() {});
  }

  void _handleStart(String handleType, DragStartDetails details) {
    _activeHandle = handleType;

    switch (handleType) {
      case 'rotate':
        _isRotating = true;
        _initialRotation = _currentTransformation.rotation;
        break;
      default:
        _isResizing = true;
    }

    setState(() {});
    HapticFeedback.selectionClick();
  }

  void _handleUpdate(String handleType, DragUpdateDetails details) {
    switch (handleType) {
      case 'tl':
      case 'tr':
      case 'bl':
      case 'br':
        _handleResize(handleType, details.delta);
        break;
      case 'crop_top':
      case 'crop_right':
      case 'crop_bottom':
      case 'crop_left':
        _handleCrop(handleType, details.delta);
        break;
      case 'rotate':
        _handleRotate(details.delta);
        break;
      case 'scale':
        _handleScale(details.delta);
        break;
    }
  }

  void _handleEnd(String handleType, DragEndDetails details) {
    _activeHandle = null;
    _isResizing = false;
    _isRotating = false;
    _initialRotation = null;
    setState(() {});
    HapticFeedback.lightImpact();
  }

  void _handleResize(String handle, Offset delta) {
    const minSize = Size(50, 50);
    final maxSize = Size(
      widget.containerSize.width * 0.8,
      widget.containerSize.height * 0.8,
    );

    Size newSize = _currentTransformation.size;
    Offset newPosition = _currentTransformation.position;

    switch (handle) {
      case 'br':
        newSize = Size(
          (_currentTransformation.size.width + delta.dx).clamp(
            minSize.width,
            maxSize.width,
          ),
          (_currentTransformation.size.height + delta.dy).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        break;
      case 'bl':
        newSize = Size(
          (_currentTransformation.size.width - delta.dx).clamp(
            minSize.width,
            maxSize.width,
          ),
          (_currentTransformation.size.height + delta.dy).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        newPosition = Offset(
          _currentTransformation.position.dx + delta.dx,
          _currentTransformation.position.dy,
        );
        break;
      case 'tr':
        newSize = Size(
          (_currentTransformation.size.width + delta.dx).clamp(
            minSize.width,
            maxSize.width,
          ),
          (_currentTransformation.size.height - delta.dy).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        newPosition = Offset(
          _currentTransformation.position.dx,
          _currentTransformation.position.dy + delta.dy,
        );
        break;
      case 'tl':
        newSize = Size(
          (_currentTransformation.size.width - delta.dx).clamp(
            minSize.width,
            maxSize.width,
          ),
          (_currentTransformation.size.height - delta.dy).clamp(
            minSize.height,
            maxSize.height,
          ),
        );
        newPosition = Offset(
          _currentTransformation.position.dx + delta.dx,
          _currentTransformation.position.dy + delta.dy,
        );
        break;
    }

    _updateTransformation(
      _currentTransformation.copyWith(size: newSize, position: newPosition),
    );
  }

  void _handleCrop(String handle, Offset delta) {
    const cropSensitivity = 0.003;
    Rect newCropRect = _currentTransformation.cropRect;

    switch (handle) {
      case 'crop_top':
        newCropRect = Rect.fromLTRB(
          _currentTransformation.cropRect.left,
          (_currentTransformation.cropRect.top + delta.dy * cropSensitivity)
              .clamp(0.0, _currentTransformation.cropRect.bottom - 0.1),
          _currentTransformation.cropRect.right,
          _currentTransformation.cropRect.bottom,
        );
        break;
      case 'crop_bottom':
        newCropRect = Rect.fromLTRB(
          _currentTransformation.cropRect.left,
          _currentTransformation.cropRect.top,
          _currentTransformation.cropRect.right,
          (_currentTransformation.cropRect.bottom + delta.dy * cropSensitivity)
              .clamp(_currentTransformation.cropRect.top + 0.1, 1.0),
        );
        break;
      case 'crop_left':
        newCropRect = Rect.fromLTRB(
          (_currentTransformation.cropRect.left + delta.dx * cropSensitivity)
              .clamp(0.0, _currentTransformation.cropRect.right - 0.1),
          _currentTransformation.cropRect.top,
          _currentTransformation.cropRect.right,
          _currentTransformation.cropRect.bottom,
        );
        break;
      case 'crop_right':
        newCropRect = Rect.fromLTRB(
          _currentTransformation.cropRect.left,
          _currentTransformation.cropRect.top,
          (_currentTransformation.cropRect.right + delta.dx * cropSensitivity)
              .clamp(_currentTransformation.cropRect.left + 0.1, 1.0),
          _currentTransformation.cropRect.bottom,
        );
        break;
    }

    _updateTransformation(
      _currentTransformation.copyWith(cropRect: newCropRect),
    );
  }

  void _handleRotate(Offset delta) {
    const rotationSensitivity = 2.0;
    final newRotation =
        (_currentTransformation.rotation + delta.dx * rotationSensitivity) %
        360;

    _updateTransformation(
      _currentTransformation.copyWith(rotation: newRotation),
    );
  }

  void _handleScale(Offset delta) {
    const scaleSensitivity = 0.01;
    final newScale =
        (_currentTransformation.scale + delta.dy * scaleSensitivity).clamp(
          0.2,
          3.0,
        );

    _updateTransformation(_currentTransformation.copyWith(scale: newScale));
  }

  void _updateTransformation(PageTransformation newTransformation) {
    setState(() {
      _currentTransformation = newTransformation;
    });
    widget.onTransformationChanged?.call(newTransformation);
  }
}

// Custom clipper for cropping functionality
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

// Document preview header with enhanced functionality
class EnhancedDocumentPreviewHeader extends StatelessWidget {
  final String fileName;
  final bool isMonochromatic;
  final int currentPage;
  final int totalPages;
  final String documentType;
  final VoidCallback? onResetSettings;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final Function(int)? onPageSelect;

  const EnhancedDocumentPreviewHeader({
    super.key,
    required this.fileName,
    required this.isMonochromatic,
    required this.currentPage,
    required this.totalPages,
    required this.documentType,
    this.onResetSettings,
    this.onPreviousPage,
    this.onNextPage,
    this.onPageSelect,
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
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Document type icon and info
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              documentType == 'photo' ? Icons.image : Icons.picture_as_pdf,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Preview',
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

          // Page navigation
          if (totalPages > 1) ...[
            IconButton(
              onPressed: currentPage > 0 ? onPreviousPage : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              visualDensity: VisualDensity.compact,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentPage + 1}/$totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: currentPage < totalPages - 1 ? onNextPage : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              visualDensity: VisualDensity.compact,
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
              tooltip: 'Reset All Settings',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
