// lib/screens/preview_screen/preview_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
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

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Widget _buildA4DocumentViewer(PreviewViewModel viewModel) {
    const double a4Width = 210.0; // A4 width in mm
    const double a4Height = 297.0; // A4 height in mm
    const double scale = 2.0; // Scale factor for screen display

    final screenWidth = MediaQuery.of(context).size.width * 0.6;
    final aspectRatio = a4Width / a4Height;
    final containerWidth = screenWidth - 32;
    final containerHeight = containerWidth / aspectRatio;

    return RepaintBoundary(
      key: _documentKey,
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildPageContent(viewModel, containerWidth, containerHeight),
        ),
      ),
    );
  }

  Widget _buildPageContent(
    PreviewViewModel viewModel,
    double width,
    double height,
  ) {
    if (viewModel.pagesPerSheet == 1) {
      return _buildSinglePageContent(viewModel, width, height);
    } else {
      return _buildMultiPageContent(viewModel, width, height);
    }
  }

  Widget _buildSinglePageContent(
    PreviewViewModel viewModel,
    double width,
    double height,
  ) {
    return Transform.scale(
      scale: viewModel.zoomLevel,
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
          child: _buildDocumentContent(),
        ),
      ),
    );
  }

  Widget _buildMultiPageContent(
    PreviewViewModel viewModel,
    double width,
    double height,
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

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
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
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Transform.scale(
              scale: viewModel.zoomLevel * 0.5, // Adjust for grid layout
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _buildDocumentContent(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
      );
    } else {
      return Image.file(
        widget.documentFile,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
  }

  Widget _buildAdvancedEditControls(PreviewViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Document Editor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  Icons.zoom_in,
                  'Fit Width',
                  () => viewModel.setZoomLevel(1.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  Icons.zoom_out,
                  'Fit Page',
                  () => viewModel.setZoomLevel(1.0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  Icons.refresh,
                  'Reset',
                  () => viewModel.resetSettings(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Zoom Control
          _buildControlSection(
            'Scale & Size',
            Icons.aspect_ratio,
            Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.zoom_out, size: 20),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.blue.shade600,
                          inactiveTrackColor: Colors.blue.shade100,
                          thumbColor: Colors.blue.shade600,
                          overlayColor: Colors.blue.shade100,
                        ),
                        child: Slider(
                          value: viewModel.zoomLevel,
                          min: 0.1,
                          max: 3.0,
                          divisions: 29,
                          label: '${(viewModel.zoomLevel * 100).round()}%',
                          onChanged: viewModel.setZoomLevel,
                        ),
                      ),
                    ),
                    const Icon(Icons.zoom_in, size: 20),
                  ],
                ),
                Text(
                  '${(viewModel.zoomLevel * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Rotation Control
          _buildControlSection(
            'Rotation',
            Icons.rotate_right,
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRotationButton(
                      Icons.rotate_90_degrees_ccw,
                      '90° Left',
                      () => viewModel.rotateLeft(),
                    ),
                    _buildRotationButton(
                      Icons.refresh,
                      'Reset',
                      () => viewModel.resetRotation(),
                    ),
                    _buildRotationButton(
                      Icons.rotate_90_degrees_cw,
                      '90° Right',
                      () => viewModel.rotateRight(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${viewModel.rotationAngle.round()}°',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Color Mode
          _buildControlSection(
            'Color Mode',
            Icons.palette,
            Row(
              children: [
                Expanded(
                  child: _buildColorModeButton(
                    'Full Color',
                    Icons.color_lens,
                    !viewModel.isMonochromatic,
                    () => viewModel.setIsMonochromatic(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColorModeButton(
                    'B&W',
                    Icons.filter_b_and_w,
                    viewModel.isMonochromatic,
                    () => viewModel.setIsMonochromatic(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.blue.shade600, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRotationButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.blue.shade600, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorModeButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
      ),
    );
  }

  Widget _buildPrintOptions(PreviewViewModel viewModel, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.print,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Print Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pages per Sheet
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pages per Sheet:',
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
                          selectedColor: Colors.green.shade600,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Number of Copies
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Copies:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: viewModel.numberOfCopies > 1
                                ? () => viewModel.setNumberOfCopies(
                                    viewModel.numberOfCopies - 1,
                                  )
                                : null,
                            icon: const Icon(Icons.remove, size: 18),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
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
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cost Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Cost Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

        // QR Code
        Center(
          child: Column(
            children: [
              const Text(
                'Scan to Pay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: QrCodeWidget(
                  data:
                      'upi://pay?pa=merchant@paytm&pn=PrintShop&am=${viewModel.totalCost}&cu=INR&tn=Document Print Payment',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Payment and Print Section
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
                elevation: 2,
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
                elevation: 2,
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
    );
  }

  Future<void> _printDocument(
    PreviewViewModel viewModel,
    BuildContext context,
  ) async {
    try {
      // Show loading
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

      // Create the PDF with all applied settings
      final pdf = pw.Document();

      // Capture the current document view as image
      final boundary =
          _documentKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        // Add pages based on settings
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

      Navigator.of(context).pop(); // Close loading dialog

      // Save and download the PDF
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/printed_document_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      // Show success dialog with download option
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
                Text('Pages per sheet: ${viewModel.pagesPerSheet}'),
                Text('Total cost: ₹${viewModel.totalCost.toStringAsFixed(2)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Open the generated PDF
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

      // Print the document (actual printing logic would go here)
      viewModel.printDocument(widget.documentFile);

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
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
      Navigator.of(context).pop(); // Close loading dialog if open
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
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(Icons.description, color: Colors.white, size: 20),
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
                IconButton(
                  onPressed: () => viewModel.resetSettings(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset All Settings',
                ),
                IconButton(
                  onPressed: () {
                    // Add help/info functionality
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Document Editor Help'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Use scale slider to zoom in/out'),
                            Text('• Rotate document in 90° increments'),
                            Text('• Switch between color and B&W preview'),
                            Text(
                              '• Adjust pages per sheet for efficient printing',
                            ),
                            Text('• Preview shows exactly how it will print'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Help',
                ),
              ],
            ),
            body: Row(
              children: [
                // Document Preview Area (Left Side)
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Preview Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.preview,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'A4 Preview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: viewModel.isMonochromatic
                                      ? Colors.grey.shade100
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: viewModel.isMonochromatic
                                        ? Colors.grey.shade300
                                        : Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      viewModel.isMonochromatic
                                          ? Icons.filter_b_and_w
                                          : Icons.color_lens,
                                      size: 14,
                                      color: viewModel.isMonochromatic
                                          ? Colors.grey.shade600
                                          : Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      viewModel.isMonochromatic
                                          ? 'B&W'
                                          : 'Color',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: viewModel.isMonochromatic
                                            ? Colors.grey.shade600
                                            : Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Preview Area
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: _buildA4DocumentViewer(viewModel),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Control Panel (Right Side)
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAdvancedEditControls(viewModel),
                          const SizedBox(height: 20),
                          _buildPrintOptions(viewModel, context),
                        ],
                      ),
                    ),
                  ),
                ),
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
