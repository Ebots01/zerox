// lib/screens/pin_screen/pin_view_model.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../services/document_service.dart';

class PinViewModel extends ChangeNotifier {
  final DocumentService _documentService;
  String _pin = '';
  String _errorMessage = '';
  bool _isLoading = false;

  PinViewModel({required DocumentService documentService})
    : _documentService = documentService;

  String get pin => _pin;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  void setPin(String value) {
    _pin = value;
    notifyListeners();
  }

  Future<File?> validatePin() async {
    if (_pin.isEmpty) {
      _errorMessage = 'PIN cannot be empty';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final file = await _documentService.getDocumentByPin(_pin);
      if (file != null) {
        return file;
      } else {
        _errorMessage = 'Invalid PIN or document not found';
        return null;
      }
    } catch (e) {
      _errorMessage = 'An error occurred while validating the PIN';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
