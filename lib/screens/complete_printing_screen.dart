// lib/screens/complete_printing_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Import all the components we created
import '../widgets/document_editor_widget.dart';
import '../widgets/page_management_widget.dart';
import '../widgets/print_settings_widget.dart';
import '../widgets/qr_code_widget.dart';
import '../utils/document_utils.dart';

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
  bool _showAdvancedSettings = false;

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
  bool get showAdvancedSettings => _showAdvancedSettings;

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
      // Validate document
      final validation = await DocumentUtils.validateDocumentForPrinting(file);
      if (!validation.isValid) {
        throw Exception(validation.issues.join('\n'));
      }

      // Get metadata
      final metadata = await DocumentUtils.getDocumentMetadata(file);

      // Initialize pages
      final pages = <PageItem>[];
      for (int i = 0; i < metadata.pageCount; i++) {
        pages.add(
          PageItem(
            id: i,
            originalIndex: i,
            type: metadata.type == DocumentType.photo ? 'photo' : 'pdf',
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
      debugPrint('  Type: ${metadata.type.name}');
      debugPrint('  Pages: ${metadata.pageCount}');
      debugPrint('  Size: ${DocumentUtils.formatFileSize(metadata.fileSize)}');
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

  void reorderPages(List<PageItem> newOrder) {
    _pages = newOrder;
    if (_currentPageIndex >= _pages.length) {
      _currentPageIndex = _pages.length - 1;
    }
    notifyListeners();
  }

  void duplicatePage(int index) {
    if (index >= 0 && index < _pages.length) {
      final originalPage = _pages[index];
      final newPage = PageItem(
        id: DateTime.now().millisecondsSinceEpoch,
        originalIndex: originalPage.originalIndex,
        type: originalPage.type,
        sourceFile: originalPage.sourceFile,
        transformations: Map.from(originalPage.transformations),
      );

      _pages.insert(index + 1, newPage);
      notifyListeners();
    }
  }

  void deletePage(int index) {
    if (index >= 0 && index < _pages.length && _pages.length > 1) {
      _pages.removeAt(index);

      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
      if (_selectedPageIndex == index) {
        _selectedPageIndex = null;
      } else if (_selectedPageIndex != null && _selectedPageIndex! > index) {
        _selectedPageIndex = _selectedPageIndex! - 1;
      }

      notifyListeners();
    }
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

  void toggleAdvancedSettings() {
    _showAdvancedSettings = !_showAdvancedSettings;
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
        debugPrint('  Amount: ₹${totalCost.toStringAsFixed(2)}');
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

  void resetPayment() {
    _isPaymentVerified = false;
    _isVerifyingPayment = false;
    _paymentOrderId = null;
    notifyListeners();
  }

  // Print execution
  Future<void> executePrint() async {
    if (!canPrint) return;

    _setLoading(true);
    _clearError();

    try {
      // Create print job
      final printJob = PrintJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        documentName: _documentMetadata!.fileName,
        configuration: PrintConfiguration(
          copies: _printSettings.copies,
          isMonochromatic: _printSettings.isMonochromatic,
          paperSize: _printSettings.paperSize,
          orientation: _printSettings.orientation,
          quality: _printSettings.quality,
          duplex: _printSettings.duplex,
          selectedPages: _printSettings.printRange == 'all'
              ? []
              : _printSettings.customPages,
        ),
        createdAt: DateTime.now(),
      );

      // Add to print queue
      final queueManager = PrintQueueManager();
      final jobId = queueManager.addJob(printJob);

      debugPrint('✓ Print job submitted: $jobId');
      debugPrint('  Document: ${_documentMetadata!.fileName}');
      debugPrint('  Pages: ${_pages.length}');
      debugPrint('  Copies: ${_printSettings.copies}');
      debugPrint('  Cost: ₹${totalCost.toStringAsFixed(2)}');

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

  void reset() {
    _documentFile = null;
    _documentMetadata = null;
    _pages.clear();
    _currentPageIndex = 0;
    _selectedPageIndex = null;
    _printSettings = const PrintSettings();
    _isPaymentVerified = false;
    _isVerifyingPayment = false;
    _paymentOrderId = null;
    _isLoading = false;
    _errorMessage = null;
    _showAdvancedSettings = false;
    notifyListeners();
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
            key: _scaffoldKey,
            backgroundColor: Colors.grey.shade100,
            appBar: _buildAppBar(model),
            body: _buildBody(model),
            endDrawer: _buildSettingsDrawer(model),
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
            model.documentMetadata?.type == DocumentType.photo
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
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
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

        // Settings menu
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          icon: const Icon(Icons.settings),
          tooltip: 'Print Settings',
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

        // Right panel - Page management and controls
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
          EnhancedDocumentPreviewHeader(
            fileName: model.documentMetadata?.fileName ?? 'Unknown',
            isMonochromatic: model.printSettings.isMonochromatic,
            currentPage: model.currentPageIndex,
            totalPages: model.pages.length,
            documentType: model.documentMetadata?.type.name ?? 'unknown',
            onPreviousPage: model.currentPageIndex > 0
                ? () => model.setCurrentPage(model.currentPageIndex - 1)
                : null,
            onNextPage: model.currentPageIndex < model.pages.length - 1
                ? () => model.setCurrentPage(model.currentPageIndex + 1)
                : null,
            onResetSettings: model.resetPrintSettings,
          ),

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

                  // Document editor
                  if (model.pages.isNotEmpty)
                    EnhancedDocumentEditorWidget(
                      documentFile:
                          model.pages[model.currentPageIndex].sourceFile,
                      pageIndex: model.currentPageIndex,
                      transformation: PageTransformation(
                        isSelected:
                            model.selectedPageIndex == model.currentPageIndex,
                      ),
                      isMonochromatic: model.printSettings.isMonochromatic,
                      containerSize: Size(sheetWidth, sheetHeight),
                      onTap: () => model.selectPage(
                        model.selectedPageIndex == model.currentPageIndex
                            ? null
                            : model.currentPageIndex,
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
    return Column(
      children: [
        // Page management
        Expanded(
          flex: 2,
          child: PageManagementWidget(
            pages: model.pages,
            selectedPageIndex: model.selectedPageIndex,
            onPagesReordered: model.reorderPages,
            onPageSelected: (index) {
              model.setCurrentPage(index);
              model.selectPage(index);
            },
            onPageDuplicated: model.duplicatePage,
            onPageDeleted: model.deletePage,
            itemHeight: 70,
          ),
        ),

        // Payment section
        Expanded(flex: 1, child: _buildPaymentSection(model)),
      ],
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
            // QR code
            Center(
              child: PrintShopQrWidget(
                amount: model.totalCost,
                pages: model.pages.length,
                copies: model.printSettings.copies,
                isColor: !model.printSettings.isMonochromatic,
                orderId: model.paymentOrderId,
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

  Widget _buildSettingsDrawer(PrintingAppModel model) {
    return Drawer(
      width: 400,
      child: PrintSettingsWidget(
        settings: model.printSettings,
        totalPages: model.pages.length,
        onSettingsChanged: model.updatePrintSettings,
        onResetSettings: model.resetPrintSettings,
        showAdvancedOptions: model.showAdvancedSettings,
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
            onPressed: () => model._clearError(),
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

// Usage example in main app
class PrintingApp extends StatelessWidget {
  const PrintingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Print Shop',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DocumentSelectionScreen(),
    );
  }
}

class DocumentSelectionScreen extends StatelessWidget {
  const DocumentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Document'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Select a document to print',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _selectDocument(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDocument(BuildContext context) {
    // In a real app, you would use file_picker package here
    // For this example, we'll simulate selecting a file

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demo Mode'),
        content: const Text(
          'In a real application, this would open a file picker. '
          'For this demo, we\'ll simulate loading a document.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openPrintingScreen(context);
            },
            child: const Text('Continue with Demo'),
          ),
        ],
      ),
    );
  }

  void _openPrintingScreen(BuildContext context) {
    // Create a dummy file for demo purposes
    // In a real app, this would be the selected file
    final demoFile = File('/demo/sample_document.pdf');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompletePrintingScreen(documentFile: demoFile),
      ),
    );
  }
}
