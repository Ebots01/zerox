// lib/screens/preview_screen/preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../widgets/qr_code_widget.dart';
import 'preview_view_model.dart';

class PreviewScreen extends StatelessWidget {
  final File documentFile;

  const PreviewScreen({super.key, required this.documentFile});

  Widget _buildDocumentViewer(PreviewViewModel viewModel) {
    final filePath = documentFile.path.toLowerCase();

    if (filePath.endsWith('.pdf')) {
      return Transform.scale(
        scale: viewModel.zoomLevel,
        child: Transform.rotate(
          angle: viewModel.rotationAngle * 3.14159 / 180,
          child: SfPdfViewer.file(documentFile),
        ),
      );
    } else {
      return Transform.scale(
        scale: viewModel.zoomLevel,
        child: Transform.rotate(
          angle: viewModel.rotationAngle * 3.14159 / 180,
          child: Image.file(documentFile, fit: BoxFit.contain),
        ),
      );
    }
  }

  Widget _buildEditControls(PreviewViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Page Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Size Control
          const Text(
            'Page Size:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Scale: '),
              Expanded(
                child: Slider(
                  value: viewModel.zoomLevel,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${(viewModel.zoomLevel * 100).round()}%',
                  onChanged: viewModel.setZoomLevel,
                ),
              ),
              Text('${(viewModel.zoomLevel * 100).round()}%'),
            ],
          ),

          const SizedBox(height: 16),

          // Rotation Control
          const Text(
            'Rotation:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRotationButton(
                Icons.rotate_left,
                'Left',
                () => viewModel.rotateLeft(),
              ),
              _buildRotationButton(
                Icons.refresh,
                'Reset',
                () => viewModel.resetRotation(),
              ),
              _buildRotationButton(
                Icons.rotate_right,
                'Right',
                () => viewModel.rotateRight(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Color Options
          const Text(
            'Color Options:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Color', style: TextStyle(fontSize: 14)),
                  value: false,
                  groupValue: viewModel.isMonochromatic,
                  onChanged: (value) =>
                      viewModel.setIsMonochromatic(value ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('B&W', style: TextStyle(fontSize: 14)),
                  value: true,
                  groupValue: viewModel.isMonochromatic,
                  onChanged: (value) =>
                      viewModel.setIsMonochromatic(value ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRotationButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blue.shade600),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOptions(PreviewViewModel viewModel, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.print, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Print Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Number of Copies
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
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
                    icon: const Icon(Icons.remove),
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
                    icon: const Icon(Icons.add),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Sheets per Page
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pages per Sheet:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              DropdownButton<int>(
                value: viewModel.pagesPerSheet,
                underline: const SizedBox(),
                items: [1, 2, 4, 6, 9].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    viewModel.setPagesPerSheet(value);
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Cost Display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
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
              const Divider(),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

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

        // Payment Verification
        if (!viewModel.isPaymentVerified) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.payment),
              onPressed: viewModel.isVerifyingPayment
                  ? null
                  : () {
                      viewModel.verifyPayment();
                    },
              label: viewModel.isVerifyingPayment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Verify Payment'),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Payment Verified',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
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
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.print),
              onPressed: () {
                viewModel.printDocument(documentFile);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document sent to printer!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PreviewViewModel(),
      child: Consumer<PreviewViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
              title: Text(
                documentFile.path.split('/').last,
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () {
                    viewModel.resetSettings();
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Settings',
                ),
              ],
            ),
            body: Row(
              children: [
                // Document Preview Area
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(8),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildDocumentViewer(viewModel),
                    ),
                  ),
                ),

                // Control Panel
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEditControls(viewModel),
                          const SizedBox(height: 20),
                          _buildPrintOptions(viewModel, context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
