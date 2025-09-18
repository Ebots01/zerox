// lib/screens/complete_printing_screen.dart

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Import the simplified QR code widget
import '../widgets/qr_code_widget.dart';

// Simple data models to avoid dependency issues
class PrintSettings {
  final int copies;
  final bool isMonochromatic;
  final int pagesPerSheet; // Added pages per sheet
  final String pageOrientation;

  const PrintSettings({
    this.copies = 1,
    this.isMonochromatic = false,
    this.pagesPerSheet = 1, // Default to 1 page per sheet
    this.pageOrientation = 'portrait',
  });

  PrintSettings copyWith({
    int? copies,
    bool? isMonochromatic,
    int? pagesPerSheet,
    String? pageOrientation,
  }) {
    return PrintSettings(
      copies: copies ?? this.copies,
      isMonochromatic: isMonochromatic ?? this.isMonochromatic,
      pagesPerSheet: pagesPerSheet ?? this.pagesPerSheet,
      pageOrientation: pageOrientation ?? this.pageOrientation,
    );
  }

  double calculateCost({required int totalPages}) {
    final baseCost = totalPages * copies * (isMonochromatic ? 1.0 : 1.5);
    return baseCost;
  }
}

class DocumentMetadata {
  final String fileName;
  final int pageCount;
  final String type; // 'photo' or 'pdf'

  const DocumentMetadata({
    required this.fileName,
    required this.pageCount,
    required this.type,
  });
}

class PageItem {
  final int id;
  final int originalIndex;
  final String type;
  final File sourceFile;

  const PageItem({
    required this.id,
    required this.originalIndex,
    required this.type,
    required this.sourceFile,
  });
}

// Main application model
class PrintingAppModel extends ChangeNotifier {
  // Document state
  File? _documentFile;
  DocumentMetadata? _documentMetadata;
  List<PageItem> _pages = [];
  int _currentPageIndex = 0;
  int? _selectedPageIndex;

  // Print settings
  PrintSettings _printSettings = const PrintSettings();

  // Payment state
  bool _isPaymentVerified = false;
  bool _isVerifyingPayment = false;
  String? _paymentOrderId;

  // UI state
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  File? get documentFile => _documentFile;
  DocumentMetadata? get documentMetadata => _documentMetadata;
  List<PageItem> get pages => List.unmodifiable(_pages);
  int get currentPageIndex => _currentPageIndex;
  int? get selectedPageIndex => _selectedPageIndex;
  PrintSettings get printSettings => _printSettings;
  bool get isPaymentVerified => _isPaymentVerified;
  bool get isVerifyingPayment => _isVerifyingPayment;
  String? get paymentOrderId => _paymentOrderId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalCost {
    if (_documentMetadata == null) return 0.0;
    return _printSettings.calculateCost(
      totalPages: _documentMetadata!.pageCount,
    );
  }

  bool get canPrint => _isPaymentVerified && !_isLoading && _pages.isNotEmpty;

  // Initialize with document
  Future<void> initializeWithDocument(File file) async {
    _setLoading(true);
    _clearError();

    try {
      // Simple document analysis
      final fileName = file.path.split('/').last;
      final isPhoto =
          fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg') ||
          fileName.toLowerCase().endsWith('.png');

      final metadata = DocumentMetadata(
        fileName: fileName,
        pageCount: isPhoto ? 1 : 5, // Simulate PDF with 5 pages
        type: isPhoto ? 'photo' : 'pdf',
      );

      // Initialize pages
      final pages = <PageItem>[];
      for (int i = 0; i < metadata.pageCount; i++) {
        pages.add(
          PageItem(
            id: i,
            originalIndex: i,
            type: metadata.type,
            sourceFile: file,
          ),
        );
      }

      _documentFile = file;
      _documentMetadata = metadata;
      _pages = pages;
      _currentPageIndex = 0;
      _selectedPageIndex = null;

      debugPrint('✓ Document initialized: ${metadata.fileName}');
      debugPrint(' Type: ${metadata.type}');
      debugPrint(' Pages: ${metadata.pageCount}');
    } catch (e) {
      _setError('Failed to load document: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Page management
  void setCurrentPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _currentPageIndex = index;
      notifyListeners();
    }
  }

  void selectPage(int? index) {
    _selectedPageIndex = index;
    notifyListeners();
  }

  // Print settings
  void updatePrintSettings(PrintSettings settings) {
    _printSettings = settings;
    notifyListeners();
  }

  void resetPrintSettings() {
    _printSettings = const PrintSettings();
    notifyListeners();
  }

  // Pages per sheet methods
  void setPagesPerSheet(int value) {
    if (value > 0 && value <= 4) {
      _printSettings = _printSettings.copyWith(pagesPerSheet: value);
      notifyListeners();
    }
  }

  void setNumberOfCopies(int copies) {
    if (copies > 0 && copies <= 50) {
      _printSettings = _printSettings.copyWith(copies: copies);
      notifyListeners();
    }
  }

  void setIsMonochromatic(bool value) {
    _printSettings = _printSettings.copyWith(isMonochromatic: value);
    notifyListeners();
  }

  // Payment processing
  Future<void> verifyPayment() async {
    if (_isVerifyingPayment) return;

    _isVerifyingPayment = true;
    _paymentOrderId = 'DOC${DateTime.now().millisecondsSinceEpoch}';
    notifyListeners();

    try {
      // Simulate payment verification
      await Future.delayed(
        Duration(milliseconds: 1500 + Random().nextInt(1000)),
      );

      final success = Random().nextDouble() > 0.05; // 95% success rate
      if (success) {
        _isPaymentVerified = true;
        debugPrint('✓ Payment verified: Order #$_paymentOrderId');
        debugPrint(' Amount: ₹${totalCost.toStringAsFixed(2)}');
      } else {
        throw Exception('Payment verification failed');
      }
    } catch (e) {
      _setError('Payment verification failed: $e');
      _isPaymentVerified = false;
      _paymentOrderId = null;
    } finally {
      _isVerifyingPayment = false;
      notifyListeners();
    }
  }

  // Print execution
  Future<void> executePrint() async {
    if (!canPrint) return;

    _setLoading(true);
    _clearError();

    try {
      debugPrint('✓ Print job submitted');
      debugPrint(' Document: ${_documentMetadata!.fileName}');
      debugPrint(' Pages: ${_pages.length}');
      debugPrint(' Copies: ${_printSettings.copies}');
      debugPrint(' Pages per sheet: ${_printSettings.pagesPerSheet}');
      debugPrint(' Cost: ₹${totalCost.toStringAsFixed(2)}');

      // Simulate processing
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      _setError('Print job failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Public method to clear error (fix the access issue)
  void clearError() {
    _clearError();
  }
}

// Main printing screen
class CompletePrintingScreen extends StatefulWidget {
  final File documentFile;

  const CompletePrintingScreen({super.key, required this.documentFile});

  @override
  State<CompletePrintingScreen> createState() => _CompletePrintingScreenState();
}

class _CompletePrintingScreenState extends State<CompletePrintingScreen> {
  late PrintingAppModel _model;

  @override
  void initState() {
    super.initState();
    _model = PrintingAppModel();
    _initializeDocument();
  }

  Future<void> _initializeDocument() async {
    await _model.initializeWithDocument(widget.documentFile);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _model,
      child: Consumer<PrintingAppModel>(
        builder: (context, model, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: _buildAppBar(model),
            body: _buildBody(model),
            floatingActionButton: _buildFloatingActionButton(model),
            bottomSheet: model.errorMessage != null
                ? _buildErrorSheet(model)
                : null,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(PrintingAppModel model) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            model.documentMetadata?.type == 'photo'
                ? Icons.image
                : Icons.picture_as_pdf,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              model.documentMetadata?.fileName ?? 'Loading...',
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
        if (model.pages.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${model.currentPageIndex + 1} / ${model.pages.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(PrintingAppModel model) {
    if (model.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document...'),
          ],
        ),
      );
    }

    if (model.pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No document loaded',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a document to print',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Left panel - Document preview
        Expanded(flex: 3, child: _buildDocumentPreview(model)),
        // Right panel - Controls
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 8,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: _buildControlPanel(model),
        ),
      ],
    );
  }

  Widget _buildDocumentPreview(PrintingAppModel model) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Preview header
          _buildPreviewHeader(model),
          // Main preview area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildA4Preview(model),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(PrintingAppModel model) {
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
            onPressed: model.currentPageIndex > 0
                ? () => model.setCurrentPage(model.currentPageIndex - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page ${model.currentPageIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: model.currentPageIndex < model.pages.length - 1
                ? () => model.setCurrentPage(model.currentPageIndex + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildA4Preview(PrintingAppModel model) {
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
                  // Grid background
                  Positioned.fill(child: CustomPaint(painter: GridPainter())),
                  // Document preview
                  if (model.pages.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              model.pages[model.currentPageIndex].type ==
                                      'photo'
                                  ? Icons.image
                                  : Icons.picture_as_pdf,
                              size: 100,
                              color: Colors.blue.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Page ${model.currentPageIndex + 1}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              model.pages[model.currentPageIndex].type
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(PrintingAppModel model) {
    return SingleChildScrollView(
      child: Column(
        children: [_buildPrintSettings(model), _buildPaymentSection(model)],
      ),
    );
  }

  Widget _buildPrintSettings(PrintingAppModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Print Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
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
                    onPressed: model.printSettings.copies > 1
                        ? () => model.setNumberOfCopies(
                            model.printSettings.copies - 1,
                          )
                        : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '${model.printSettings.copies}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: model.printSettings.copies < 50
                        ? () => model.setNumberOfCopies(
                            model.printSettings.copies + 1,
                          )
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pages Per Sheet Selector
          _buildPagesPerSheetSelector(model),

          const SizedBox(height: 16),

          // Color Mode
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
                  !model.printSettings.isMonochromatic,
                  () => model.setIsMonochromatic(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleButton(
                  'B&W',
                  Icons.filter_b_and_w,
                  model.printSettings.isMonochromatic,
                  () => model.setIsMonochromatic(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagesPerSheetSelector(PrintingAppModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pages per Sheet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3, 4].map((pages) {
            return Expanded(
              child: GestureDetector(
                onTap: () => model.setPagesPerSheet(pages),
                child: Container(
                  margin: EdgeInsets.only(right: pages < 4 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: model.printSettings.pagesPerSheet == pages
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: model.printSettings.pagesPerSheet == pages
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    '$pages',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: model.printSettings.pagesPerSheet == pages
                          ? Colors.white
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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

  Widget _buildPaymentSection(PrintingAppModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Cost summary
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
                  children: [
                    Icon(
                      Icons.receipt,
                      color: Colors.orange.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Cost Summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${model.pages.length} pages × ${model.printSettings.copies} copies',
                    ),
                    Text(
                      '₹${model.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment section
          if (!model.isPaymentVerified) ...[
            // Dynamic QR code
            Center(
              child: QrCodeWidget(
                data:
                    'upi://pay?pa=merchant@paytm&pn=PrintShop&am=${model.totalCost.toStringAsFixed(2)}&cu=INR&tn=Document Print Payment',
                showPaymentInfo: true,
                size: 180,
              ),
            ),
            const SizedBox(height: 16),

            // Verify payment button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: model.isVerifyingPayment
                    ? null
                    : model.verifyPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: model.isVerifyingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  model.isVerifyingPayment ? 'Verifying...' : 'Verify Payment',
                ),
              ),
            ),
          ] else ...[
            // Payment verified
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Payment Verified ✓',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(PrintingAppModel model) {
    if (!model.canPrint) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: model.isLoading ? null : model.executePrint,
      backgroundColor: Colors.green.shade600,
      icon: model.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.print),
      label: Text(model.isLoading ? 'Processing...' : 'PRINT'),
    );
  }

  Widget _buildErrorSheet(PrintingAppModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              model.errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          TextButton(
            onPressed: () => model.clearError(), // Fixed: removed underscore
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

// Grid painter for A4 preview background
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha(51)
      ..strokeWidth = 0.5;

    const gridSpacing = 20.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
