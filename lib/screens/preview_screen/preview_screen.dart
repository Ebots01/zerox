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

class PreviewScreen extends StatefulWidget {
  final File documentFile;

  const PreviewScreen({super.key, required this.documentFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final GlobalKey _documentKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();

  // Drag and resize variables
  Offset _documentOffset = Offset.zero;
  Size _documentSize = const Size(400, 566); // A4 ratio: 210x297mm scaled
  bool _isDragging = false;
  // --- Removed unused _isResizing and _resizeHandle variables ---

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  bool get _isPhotoFile {
    final filePath = widget.documentFile.path.toLowerCase();
    return filePath.endsWith('.jpg') ||
        filePath.endsWith('.jpeg') ||
        filePath.endsWith('.png') ||
        filePath.endsWith('.gif') ||
        filePath.endsWith('.bmp');
  }

  Widget _buildFullA4Sheet(PreviewViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate A4 dimensions to fill screen
        const double a4Ratio = 210.0 / 297.0; // width/height
        double sheetWidth = constraints.maxWidth - 32;
        double sheetHeight = sheetWidth / a4Ratio;

        // Adjust if height exceeds available space
        if (sheetHeight > constraints.maxHeight - 32) {
          sheetHeight = constraints.maxHeight - 32;
          sheetWidth = sheetHeight * a4Ratio;
        }

        return Center(
          child: Container(
            width: sheetWidth,
            height: sheetHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  // --- CORRECTED DEPRECATED withOpacity ---
                  color: Colors.black.withAlpha(51), // 20% opacity
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Grid lines for alignment
                _buildGridLines(sheetWidth, sheetHeight),

                // Document content with drag and resize
                if (_isPhotoFile)
                  _buildDraggablePhoto(viewModel, sheetWidth, sheetHeight)
                else
                  _buildDraggablePDF(viewModel, sheetWidth, sheetHeight),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridLines(double width, double height) {
    return Positioned.fill(child: CustomPaint(painter: GridPainter()));
  }

  Widget _buildDraggablePhoto(
    PreviewViewModel viewModel,
    double sheetWidth,
    double sheetHeight,
  ) {
    // For photos, automatically fit one photo per A4 sheet
    final adjustedSize = Size(
      min(_documentSize.width, sheetWidth - 40),
      min(_documentSize.height, sheetHeight - 40),
    );

    return Positioned(
      left: _documentOffset.dx.clamp(0, sheetWidth - adjustedSize.width),
      top: _documentOffset.dy.clamp(0, sheetHeight - adjustedSize.height),
      child: GestureDetector(
        onPanStart: (details) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            _documentOffset += details.delta;
            _documentOffset = Offset(
              _documentOffset.dx.clamp(0, sheetWidth - adjustedSize.width),
              _documentOffset.dy.clamp(0, sheetHeight - adjustedSize.height),
            );
          });
        },
        onPanEnd: (details) {
          setState(() => _isDragging = false);
        },
        child: RepaintBoundary(
          key: _documentKey,
          child: Stack(
            children: [
              Container(
                width: adjustedSize.width,
                height: adjustedSize.height,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDragging ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Transform.rotate(
                  angle: viewModel.rotationAngle * 3.14159 / 180,
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
                    child: Image.file(
                      widget.documentFile,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              // Resize handles
              ..._buildResizeHandles(adjustedSize, viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggablePDF(
    PreviewViewModel viewModel,
    double sheetWidth,
    double sheetHeight,
  ) {
    // For PDFs, allow multiple pages per sheet based on user setting
    if (viewModel.pagesPerSheet == 1) {
      return _buildSinglePDFPage(viewModel, sheetWidth, sheetHeight);
    } else {
      return _buildMultiplePDFPages(viewModel, sheetWidth, sheetHeight);
    }
  }

  Widget _buildSinglePDFPage(
    PreviewViewModel viewModel,
    double sheetWidth,
    double sheetHeight,
  ) {
    final adjustedSize = Size(
      min(_documentSize.width, sheetWidth - 40),
      min(_documentSize.height, sheetHeight - 40),
    );

    return Positioned(
      left: _documentOffset.dx.clamp(0, sheetWidth - adjustedSize.width),
      top: _documentOffset.dy.clamp(0, sheetHeight - adjustedSize.height),
      child: GestureDetector(
        onPanStart: (details) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            _documentOffset += details.delta;
            _documentOffset = Offset(
              _documentOffset.dx.clamp(0, sheetWidth - adjustedSize.width),
              _documentOffset.dy.clamp(0, sheetHeight - adjustedSize.height),
            );
          });
        },
        onPanEnd: (details) {
          setState(() => _isDragging = false);
        },
        child: RepaintBoundary(
          key: _documentKey,
          child: Stack(
            children: [
              Container(
                width: adjustedSize.width,
                height: adjustedSize.height,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDragging ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Transform.rotate(
                  angle: viewModel.rotationAngle * 3.14159 / 180,
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
                    child: SfPdfViewer.file(
                      widget.documentFile,
                      enableDoubleTapZooming: false,
                      canShowScrollHead: false,
                      canShowScrollStatus: false,
                      canShowPaginationDialog: false,
                    ),
                  ),
                ),
              ),
              // Resize handles
              ..._buildResizeHandles(adjustedSize, viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplePDFPages(
    PreviewViewModel viewModel,
    double sheetWidth,
    double sheetHeight,
  ) {
    final pages = viewModel.pagesPerSheet;
    final columns = pages == 2
        ? 2
        : pages == 4
        ? 2
        : pages == 6
        ? 2
        : 3;
    final rows = (pages / columns).ceil();

    final pageWidth = (sheetWidth - 30) / columns - 10;
    final pageHeight = (sheetHeight - 30) / rows - 10;

    return Positioned(
      left: 15,
      top: 15,
      child: RepaintBoundary(
        key: _documentKey,
        child: SizedBox(
          width: sheetWidth - 30,
          height: sheetHeight - 30,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: pageWidth / pageHeight,
            ),
            itemCount: pages,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Transform.rotate(
                    angle: viewModel.rotationAngle * 3.14159 / 180,
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
                      child: SfPdfViewer.file(
                        widget.documentFile,
                        enableDoubleTapZooming: false,
                        canShowScrollHead: false,
                        canShowScrollStatus: false,
                        canShowPaginationDialog: false,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles(Size size, PreviewViewModel viewModel) {
    if (!_isPhotoFile && viewModel.pagesPerSheet > 1) return [];

    const handleSize = 12.0;
    final handles = <Widget>[];

    // Corner handles
    final positions = [
      {
        'position': Offset(-handleSize / 2, -handleSize / 2),
        'cursor': SystemMouseCursors.resizeUpLeft,
        'handle': 'tl',
      },
      {
        'position': Offset(size.width - handleSize / 2, -handleSize / 2),
        'cursor': SystemMouseCursors.resizeUpRight,
        'handle': 'tr',
      },
      {
        'position': Offset(-handleSize / 2, size.height - handleSize / 2),
        'cursor': SystemMouseCursors.resizeDownLeft,
        'handle': 'bl',
      },
      {
        'position': Offset(
          size.width - handleSize / 2,
          size.height - handleSize / 2,
        ),
        'cursor': SystemMouseCursors.resizeDownRight,
        'handle': 'br',
      },
    ];

    for (final pos in positions) {
      handles.add(
        Positioned(
          left: (pos['position'] as Offset).dx,
          top: (pos['position'] as Offset).dy,
          child: MouseRegion(
            cursor: pos['cursor'] as SystemMouseCursor,
            child: GestureDetector(
              onPanStart: (details) {
                // --- Removed setters for unused variables ---
              },
              onPanUpdate: (details) {
                setState(() {
                  _handleResize(details.delta, pos['handle'] as String);
                });
              },
              onPanEnd: (details) {
                // --- Removed setters for unused variables ---
              },
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(handleSize / 2),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return handles;
  }

  void _handleResize(Offset delta, String handle) {
    const minSize = Size(100, 100);

    switch (handle) {
      case 'br': // Bottom right
        _documentSize = Size(
          max(minSize.width, _documentSize.width + delta.dx),
          max(minSize.height, _documentSize.height + delta.dy),
        );
        break;
      case 'tr': // Top right
        _documentSize = Size(
          max(minSize.width, _documentSize.width + delta.dx),
          max(minSize.height, _documentSize.height - delta.dy),
        );
        _documentOffset = Offset(
          _documentOffset.dx,
          _documentOffset.dy + delta.dy,
        );
        break;
      case 'bl': // Bottom left
        _documentSize = Size(
          max(minSize.width, _documentSize.width - delta.dx),
          max(minSize.height, _documentSize.height + delta.dy),
        );
        _documentOffset = Offset(
          _documentOffset.dx + delta.dx,
          _documentOffset.dy,
        );
        break;
      case 'tl': // Top left
        _documentSize = Size(
          max(minSize.width, _documentSize.width - delta.dx),
          max(minSize.height, _documentSize.height - delta.dy),
        );
        _documentOffset = Offset(
          _documentOffset.dx + delta.dx,
          _documentOffset.dy + delta.dy,
        );
        break;
    }
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
            // --- CORRECTED DEPRECATED withOpacity ---
            color: Colors.black.withAlpha(26), // 10% opacity
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

          // Rotation controls
          const Text('Rotation', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                Icons.rotate_90_degrees_ccw,
                'Rotate Left',
                () => viewModel.rotateLeft(),
              ),
              _buildControlButton(
                Icons.refresh,
                'Reset',
                () => viewModel.resetRotation(),
              ),
              _buildControlButton(
                Icons.rotate_90_degrees_cw,
                'Rotate Right',
                () => viewModel.rotateRight(),
              ),
            ],
          ),

          const SizedBox(height: 16),

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

          if (!_isPhotoFile) ...[
            const SizedBox(height: 16),
            const Text(
              'Pages per Sheet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 4, 6, 9].map((value) {
                final isSelected = viewModel.pagesPerSheet == value;
                return ChoiceChip(
                  label: Text('$value'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) viewModel.setPagesPerSheet(value);
                  },
                  selectedColor: Colors.blue.shade600,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // Reset button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                viewModel.resetSettings();
                setState(() {
                  _documentOffset = Offset.zero;
                  _documentSize = const Size(400, 566);
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All'),
            ),
          ),
        ],
      ),
    );
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
            // --- CORRECTED DEPRECATED withOpacity ---
            color: Colors.black.withAlpha(26), // 10% opacity
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
                    const Text('Base Cost (₹1/copy):'),
                    Text('₹${viewModel.numberOfCopies}'),
                  ],
                ),
                if (!viewModel.isMonochromatic) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Color Surcharge:'),
                      Text(
                        '₹${(viewModel.numberOfCopies * 0.5).toStringAsFixed(1)}',
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
                      '₹${viewModel.totalCost.toStringAsFixed(2)}',
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

          // QR Code (without copy option)
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
                      'upi://pay?pa=merchant@paytm&pn=PrintShop&am=${viewModel.totalCost}&cu=INR&tn=Document Print Payment',
                  showCopyButton: false, // Remove copy option
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
      final boundary =
          _documentKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        for (int i = 0; i < viewModel.numberOfCopies; i++) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Image(
                  pw.MemoryImage(pngBytes),
                  fit: pw.BoxFit.contain,
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
                Text('Copies: ${viewModel.numberOfCopies}'),
                Text(
                  'Color: ${viewModel.isMonochromatic ? "Black & White" : "Full Color"}',
                ),
                if (!_isPhotoFile)
                  Text('Pages per sheet: ${viewModel.pagesPerSheet}'),
                Text('Total cost: ₹${viewModel.totalCost.toStringAsFixed(2)}'),
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

      viewModel.printDocument(widget.documentFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.print, color: Colors.white),
                SizedBox(width: 8),
                Text('Document sent to printer successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PreviewViewModel(),
      child: Consumer<PreviewViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                // Status indicator
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: viewModel.isMonochromatic
                        ? Colors.grey.shade700
                        : Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        viewModel.isMonochromatic
                            ? Icons.filter_b_and_w
                            : Icons.color_lens,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        viewModel.isMonochromatic ? 'B&W' : 'Color',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: Row(
              children: [
                // Full A4 Sheet Area (Left Side)
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildFullA4Sheet(viewModel),
                  ),
                ),

                // Control Panel (Right Side)
                _buildControlPanel(viewModel),
              ],
            ),
            floatingActionButton: viewModel.isPaymentVerified
                ? FloatingActionButton.extended(
                    onPressed: () => _printDocument(viewModel, context),
                    backgroundColor: Colors.green.shade600,
                    icon: const Icon(Icons.print),
                    label: const Text('PRINT'),
                  )
                : null,
          );
        },
      ),
    );
  }
}

// Custom painter for grid lines
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
          .withOpacity(0.2) // Deprecated
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
