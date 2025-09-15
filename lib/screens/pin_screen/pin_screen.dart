// lib/screens/pin_screen/pin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../preview_screen/preview_screen.dart';
import 'pin_view_model.dart';
// Import the download service
import '../../services/download_service.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  late final TextEditingController _controller;
  bool _isServiceStarted = false; // Add a flag to prevent multiple starts

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionAndStartService();
    });
  }

  Future<void> _requestPermissionAndStartService() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      print("PERMISSION: Requesting 'Manage External Storage' permission...");
      status = await Permission.manageExternalStorage.request();
    }

    if (status.isGranted) {
      print("PERMISSION: 'Manage External Storage' permission is granted.");
      // CRUCIAL STEP: Start the download service now that we have permission.
      // We use 'context.read' to get the service instance from the provider.
      // We also check the flag to ensure this only runs once.
      if (!_isServiceStarted && mounted) {
        print(
          "PIN_SCREEN: Permission granted. Starting the DownloadService now.",
        );
        context.read<DownloadService>().startDownloading();
        setState(() {
          _isServiceStarted = true;
        });
      }
    } else {
      print("PERMISSION: 'Manage External Storage' permission was denied.");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<PinViewModel>();
    final errorMessage = context.watch<PinViewModel>().errorMessage;
    final isLoading = context.watch<PinViewModel>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter Document PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              onChanged: viewModel.setPin,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Document PIN',
                errorText: errorMessage.isEmpty ? null : errorMessage,
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      final file = await viewModel.validatePin();
                      if (file != null && mounted) {
                        _controller.clear();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                PreviewScreen(documentFile: file),
                          ),
                        );
                      }
                    },
                    child: const Text('Submit'),
                  ),
          ],
        ),
      ),
    );
  }
}
