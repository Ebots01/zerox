// lib/screens/preview_screen/preview_view_model.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class PreviewViewModel extends ChangeNotifier {
  // Print settings
  int _numberOfCopies = 1;
  bool _isMonochromatic = false;
  int _pagesPerSheet = 1; // Pages per sheet support

  // Advanced settings
  String _pageOrientation = 'portrait';
  bool _autoFit = true;
  double _brightness = 0.0;
  double _contrast = 0.0;

  // Payment settings
  bool _isPaymentVerified = false;
  bool _isVerifyingPayment = false;

  // Document info
  int _totalPages = 1;
  List<bool> _pageSelections = [];
  String _documentType = 'photo';

  // Performance optimization
  bool _isUpdating = false;

  // Constants
  static const double _baseCostPerPage = 1.0;
  static const double _colorSurcharge = 0.5;

  // Getters
  int get numberOfCopies => _numberOfCopies;
  bool get isMonochromatic => _isMonochromatic;
  int get pagesPerSheet => _pagesPerSheet;
  String get pageOrientation => _pageOrientation;
  bool get autoFit => _autoFit;
  double get brightness => _brightness;
  double get contrast => _contrast;
  bool get isPaymentVerified => _isPaymentVerified;
  bool get isVerifyingPayment => _isVerifyingPayment;
  bool get isUpdating => _isUpdating;
  int get totalPages => _totalPages;
  List<bool> get pageSelections => List.unmodifiable(_pageSelections);
  String get documentType => _documentType;

  // Total cost calculation with volume discounts
  double get totalCost {
    final effectivePages = selectedPagesCount > 0
        ? selectedPagesCount
        : _totalPages;
    final baseCost = effectivePages * _numberOfCopies * _baseCostPerPage;
    final colorCost = _isMonochromatic
        ? 0.0
        : effectivePages * _numberOfCopies * _colorSurcharge;

    // Volume discount
    double discount = 0.0;
    if (effectivePages > 10) {
      discount = baseCost * 0.10;
    } else if (effectivePages > 5) {
      discount = baseCost * 0.05;
    }

    return (baseCost + colorCost - discount).clamp(0.0, double.infinity);
  }

  int get selectedPagesCount =>
      _pageSelections.where((selected) => selected).length;

  bool get canPrint =>
      _isPaymentVerified &&
      _numberOfCopies > 0 &&
      !_isVerifyingPayment &&
      _totalPages > 0;

  // Document setup
  void setDocumentInfo({
    required int totalPages,
    required String documentType,
  }) {
    if (totalPages != _totalPages || documentType != _documentType) {
      _totalPages = totalPages;
      _documentType = documentType;
      _pageSelections = List.filled(totalPages, false);
      notifyListeners();
    }
  }

  // Pages per sheet setter
  void setPagesPerSheet(int value) {
    if (value > 0 && value <= 4 && value != _pagesPerSheet) {
      _pagesPerSheet = value;
      notifyListeners();
    }
  }

  // Print option setters
  void setNumberOfCopies(int value) {
    if (value > 0 && value <= 100 && value != _numberOfCopies) {
      _numberOfCopies = value;
      notifyListeners();
    }
  }

  void setIsMonochromatic(bool value) {
    if (value != _isMonochromatic) {
      _isMonochromatic = value;
      notifyListeners();
    }
  }

  void setPageOrientation(String orientation) {
    if (orientation != _pageOrientation &&
        ['portrait', 'landscape'].contains(orientation)) {
      _pageOrientation = orientation;
      notifyListeners();
    }
  }

  void setAutoFit(bool value) {
    if (value != _autoFit) {
      _autoFit = value;
      notifyListeners();
    }
  }

  void setBrightness(double value) {
    final clampedValue = value.clamp(-1.0, 1.0);
    if (clampedValue != _brightness) {
      _brightness = clampedValue;
      notifyListeners();
    }
  }

  void setContrast(double value) {
    final clampedValue = value.clamp(-1.0, 1.0);
    if (clampedValue != _contrast) {
      _contrast = clampedValue;
      notifyListeners();
    }
  }

  // Page selection methods
  void togglePageSelection(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _pageSelections.length) {
      _pageSelections[pageIndex] = !_pageSelections[pageIndex];
      notifyListeners();
    }
  }

  void selectAllPages() {
    _pageSelections = List.filled(_totalPages, true);
    notifyListeners();
  }

  void deselectAllPages() {
    _pageSelections = List.filled(_totalPages, false);
    notifyListeners();
  }

  void setPageSelection(int pageIndex, bool isSelected) {
    if (pageIndex >= 0 && pageIndex < _pageSelections.length) {
      _pageSelections[pageIndex] = isSelected;
      notifyListeners();
    }
  }

  // Enhanced payment methods
  Future<void> verifyPayment() async {
    if (_isVerifyingPayment) return;

    _isVerifyingPayment = true;
    notifyListeners();

    try {
      // Simulate realistic payment verification
      await Future.delayed(
        Duration(milliseconds: 2000 + math.Random().nextInt(1000)),
      );

      final success = math.Random().nextDouble() > 0.05; // 95% success rate
      if (success) {
        _isPaymentVerified = true;
        debugPrint('✓ Payment verified successfully');
        debugPrint(' Amount: ₹${totalCost.toStringAsFixed(2)}');
        debugPrint(' Pages: $_totalPages');
        debugPrint(' Pages per sheet: $_pagesPerSheet');
        debugPrint(' Copies: $_numberOfCopies');
        debugPrint(' Mode: ${_isMonochromatic ? "B&W" : "Color"}');
      } else {
        throw Exception('Payment verification failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Payment verification error: $e');
      _isPaymentVerified = false;
      rethrow;
    } finally {
      _isVerifyingPayment = false;
      notifyListeners();
    }
  }

  void resetPayment() {
    if (_isPaymentVerified || _isVerifyingPayment) {
      _isPaymentVerified = false;
      _isVerifyingPayment = false;
      notifyListeners();
    }
  }

  // Manual payment verification (for testing)
  void forceVerifyPayment() {
    _isPaymentVerified = true;
    _isVerifyingPayment = false;
    notifyListeners();
    debugPrint('✓ Payment manually verified');
  }

  // Reset settings
  void resetSettings() {
    _numberOfCopies = 1;
    _isMonochromatic = false;
    _pagesPerSheet = 1;
    _pageOrientation = 'portrait';
    _autoFit = true;
    _brightness = 0.0;
    _contrast = 0.0;
    _isPaymentVerified = false;
    _isVerifyingPayment = false;
    _pageSelections = List.filled(_totalPages, false);
    notifyListeners();
  }

  // Reset only print settings (keep document info)
  void resetPrintSettings() {
    _numberOfCopies = 1;
    _isMonochromatic = false;
    _pagesPerSheet = 1;
    _pageOrientation = 'portrait';
    _autoFit = true;
    _brightness = 0.0;
    _contrast = 0.0;
    notifyListeners();
  }

  // Enhanced cost breakdown
  Map<String, double> get enhancedCostBreakdown {
    final effectivePages = selectedPagesCount > 0
        ? selectedPagesCount
        : _totalPages;
    final baseCost = effectivePages * _numberOfCopies * _baseCostPerPage;
    final colorSurcharge = _isMonochromatic
        ? 0.0
        : effectivePages * _numberOfCopies * _colorSurcharge;

    double volumeDiscount = 0.0;
    if (effectivePages > 10) {
      volumeDiscount = baseCost * 0.10;
    } else if (effectivePages > 5) {
      volumeDiscount = baseCost * 0.05;
    }

    return {
      'baseCost': baseCost,
      'colorSurcharge': colorSurcharge,
      'volumeDiscount': volumeDiscount,
      'total': totalCost,
    };
  }

  // Cost per sheet calculation
  double get costPerSheet {
    if (_pagesPerSheet == 0) return 0.0;
    return totalCost / math.max(1, (_totalPages / _pagesPerSheet).ceil());
  }

  // Sheets count calculation
  int get totalSheets => math.max(1, (_totalPages / _pagesPerSheet).ceil());

  // Print job summary
  Map<String, dynamic> get printJobSummary => {
    'totalPages': _totalPages,
    'pagesPerSheet': _pagesPerSheet,
    'totalSheets': totalSheets,
    'copies': _numberOfCopies,
    'isMonochromatic': _isMonochromatic,
    'pageOrientation': _pageOrientation,
    'autoFit': _autoFit,
    'totalCost': totalCost,
    'costBreakdown': enhancedCostBreakdown,
  };

  // Validation methods
  bool get isValidForPrint => _totalPages > 0 && _numberOfCopies > 0;

  String? get printValidationError {
    if (_totalPages <= 0) return 'No pages to print';
    if (_numberOfCopies <= 0) return 'Number of copies must be greater than 0';
    if (!_isPaymentVerified) return 'Payment not verified';
    return null;
  }

  // State management helpers
  void startUpdate() {
    if (!_isUpdating) {
      _isUpdating = true;
      notifyListeners();
    }
  }

  void endUpdate() {
    if (_isUpdating) {
      _isUpdating = false;
      notifyListeners();
    }
  }

  void batchUpdate(Function() updates) {
    startUpdate();
    try {
      updates();
    } finally {
      endUpdate();
    }
  }

  // Debug information
  Map<String, dynamic> get debugInfo => {
    'numberOfCopies': _numberOfCopies,
    'isMonochromatic': _isMonochromatic,
    'pagesPerSheet': _pagesPerSheet,
    'pageOrientation': _pageOrientation,
    'autoFit': _autoFit,
    'brightness': _brightness,
    'contrast': _contrast,
    'isPaymentVerified': _isPaymentVerified,
    'isVerifyingPayment': _isVerifyingPayment,
    'totalPages': _totalPages,
    'selectedPagesCount': selectedPagesCount,
    'documentType': _documentType,
    'totalCost': totalCost,
    'isUpdating': _isUpdating,
  };

  @override
  void dispose() {
    debugPrint('Enhanced PreviewViewModel disposed');
    super.dispose();
  }
}
