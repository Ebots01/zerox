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

  // This helper widget checks the file type and returns the correct viewer
  Widget _buildDocumentViewer() {
    final filePath = documentFile.path.toLowerCase();

    if (filePath.endsWith('.pdf')) {
      // If it's a PDF, use the PDF viewer
      return SfPdfViewer.file(documentFile);
    } else {
      // Otherwise, assume it's an image and use the Image viewer
      return Image.file(documentFile, fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PreviewViewModel(),
      child: Consumer<PreviewViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(documentFile.path.split('/').last),
            ),
            body: Row(
              children: [
                // Document Preview Area
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.black.withOpacity(0.1),
                    child: _buildDocumentViewer(), // Use the helper widget here
                  ),
                ),
                // Printing Options Area
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Print Options',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('Copies:'),
                            const SizedBox(width: 10),
                            DropdownButton<int>(
                              value: viewModel.numberOfCopies,
                              onChanged: (value) {
                                if (value != null) {
                                  viewModel.setNumberOfCopies(value);
                                }
                              },
                              items: List.generate(
                                10,
                                    (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1}'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          title: const Text('Monochromatic'),
                          value: viewModel.isMonochromatic,
                          onChanged: viewModel.setIsMonochromatic,
                        ),
                        const Spacer(),
                        Center(
                          child: Column(
                            children: [
                              QrCodeWidget(
                                data:
                                'copies=${viewModel.numberOfCopies}&cost=${viewModel.totalCost}',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Total Cost: ₹${viewModel.totalCost.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            onPressed: () {
                              // TODO: Implement actual printing logic here
                            },
                            label: const Text('Print'),
                          ),
                        ),
                      ],
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