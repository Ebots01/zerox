// lib/services/download_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/api_service.dart';
import 'document_service.dart';

class DownloadService extends ChangeNotifier {
  final ApiService _apiService;
  final DocumentService _documentService;
  Timer? _timer;
  final Set<String> _currentlyDownloading = <String>{};

  DownloadService({
    required ApiService apiService,
    required DocumentService documentService,
  }) : _apiService = apiService,
       _documentService = documentService;

  void startDownloading() {
    print("POLLING SERVICE: Initializing...");
    _fetchAndDownloadDocuments();
    // 1. Polling is now faster: changed from 30 to 15 seconds.
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchAndDownloadDocuments();
    });
  }

  // This function is now rewritten to handle concurrent downloads.
  Future<void> _fetchAndDownloadDocuments() async {
    print("POLLING SERVICE: Checking server for new documents...");
    try {
      final documentList = await _apiService.getDocumentList();
      if (documentList.isEmpty) return;

      // 2. Create a list of download tasks to run in parallel.
      List<Future<void>> downloadTasks = [];

      for (var item in documentList) {
        final pin = item[0] as String;
        final metadata = item[1] as Map<String, dynamic>;
        final fileName = metadata['fileName'] as String;

        // Check if the file needs to be downloaded.
        if (!await _documentService.documentExists(fileName) &&
            !_currentlyDownloading.contains(fileName)) {
          // Add a new download task to our list.
          downloadTasks.add(_downloadSingleFile(pin, fileName));
        }
      }

      // 3. If there are new files to download, run all tasks concurrently.
      if (downloadTasks.isNotEmpty) {
        print(
          "POLLING SERVICE: Starting ${downloadTasks.length} concurrent downloads.",
        );
        await Future.wait(downloadTasks);
        print("POLLING SERVICE: All concurrent downloads finished.");
      }
    } catch (e) {
      debugPrint('POLLING SERVICE ERROR: $e');
      _currentlyDownloading.clear();
    }
  }

  // This new helper function handles the logic for downloading one file.
  Future<void> _downloadSingleFile(String pin, String fileName) async {
    try {
      // Add to lock
      _currentlyDownloading.add(fileName);

      print("-> Starting download for: $fileName");
      final downloadLink = await _apiService.getDownloadLink(pin);
      final fileBytes = await _apiService.downloadFile(downloadLink);
      await _documentService.saveDocument(fileName, fileBytes);
    } catch (e) {
      debugPrint("-> Error downloading $fileName: $e");
    } finally {
      // IMPORTANT: Always remove from lock, even if the download failed.
      _currentlyDownloading.remove(fileName);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
