// lib/services/document_service.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class DocumentService {
  Future<String?> get _downloadsPath async {
    if (await Permission.manageExternalStorage.isGranted) {
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }
      return downloadsDirectory.path;
    }
    return null;
  }

  Future<File?> saveDocument(String fileName, List<int> bytes) async {
    final downloadsPath = await _downloadsPath;
    if (downloadsPath == null) {
      print(
        "TROUBLESHOOT_ERROR: Cannot save file because downloads path is null (permission issue).",
      );
      return null;
    }

    final filePath = path.join(downloadsPath, fileName);
    final file = File(filePath);

    try {
      print('TROUBLESHOOT: Writing ${bytes.length} bytes to $filePath');
      await file.writeAsBytes(bytes);

      if (await file.exists()) {
        print(
          'TROUBLESHOOT_SUCCESS: Verified that file now exists at $filePath',
        );
        return file;
      } else {
        print(
          'TROUBLESHOOT_CRITICAL_ERROR: Wrote file but it does NOT exist. This is an OS-level issue.',
        );
        return null;
      }
    } catch (e) {
      print('TROUBLESHOOT_CRITICAL_ERROR: Failed to write file. Error: $e');
      return null;
    }
  }

  // This is the full implementation for getDocumentByPin
  Future<File?> getDocumentByPin(String pin) async {
    final downloadsPath = await _downloadsPath;
    if (downloadsPath == null) return null;

    final directory = Directory(downloadsPath);
    if (!await directory.exists()) {
      return null;
    }

    final files = directory.listSync();
    for (var fileEntity in files) {
      if (fileEntity is File) {
        final fileNameWithoutExt = path.basenameWithoutExtension(
          fileEntity.path,
        );
        if (fileNameWithoutExt == pin) {
          return fileEntity;
        }
      }
    }
    return null;
  }

  // This is the full implementation for documentExists
  Future<bool> documentExists(String fileName) async {
    final downloadsPath = await _downloadsPath;
    if (downloadsPath == null) return false;

    final filePath = path.join(downloadsPath, fileName);
    return await File(filePath).exists();
  }
}
