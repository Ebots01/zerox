// lib/screens/preview_screen/preview_view_model.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class PreviewViewModel extends ChangeNotifier {
  // Print settings
  int _numberOfCopies = 1;
  bool _isMonochromatic = false;

  // Advanced settings
  String _pageOrientation = 'portrait'; // portrait, landscape
  bool _autoFit = true;
  double _brightness = 0.0;
  double _contrast = 0.0;

  // Payment settings
  bool _isPaymentVerified = false;
  bool _isVerifyingPayment = false;

  // Performance optimization
  bool _isUpdating = false;

  // Constants
  static const double _baseCostPerPage = 1.0;
  static const double _colorSurcharge = 0.5;

  // New properties for enhanced functionality
  int _totalPages = 1;
  List<bool> _pageSelections = [];
  String _documentType = 'photo'; // 'photo' or 'pdf'

  // Getters
  int get numberOfCopies => _numberOfCopies;
  bool get isMonochromatic => _isMonochromatic;
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

  double get totalCost {
    double baseCost = _totalPages * _numberOfCopies * _baseCostPerPage;
    double colorCost = _isMonochromatic
        ? 0.0
        : _totalPages * _numberOfCopies * _colorSurcharge;

    // Volume discount for multiple pages
    double discount = 0.0;
    if (_totalPages > 5) {
      discount = baseCost * 0.05; // 5% discount for 6+ pages
    } else if (_totalPages > 10) {
      discount = baseCost * 0.10; // 10% discount for 11+ pages
    }

    return (baseCost + colorCost - discount).clamp(0.0, double.infinity);
  }

  // Performance optimized notification
  void _notifyListeners() {
    if (!_isUpdating) {
      notifyListeners();
    }
  }

  void _batchUpdate(VoidCallback updates) {
    _isUpdating = true;
    updates();
    _isUpdating = false;
    notifyListeners();
  }

  // Document setup
  void setDocumentInfo({
    required int totalPages,
    required String documentType,
  }) {
    if (totalPages != _totalPages || documentType != _documentType) {
      _totalPages = totalPages;
      _documentType = documentType;
      _pageSelections = List.filled(totalPages, false);
      _notifyListeners();
    }
  }

  void togglePageSelection(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _pageSelections.length) {
      _pageSelections[pageIndex] = !_pageSelections[pageIndex];
      _notifyListeners();
    }
  }

  void selectAllPages() {
    _pageSelections = List.filled(_totalPages, true);
    _notifyListeners();
  }

  void deselectAllPages() {
    _pageSelections = List.filled(_totalPages, false);
    _notifyListeners();
  }

  int get selectedPagesCount =>
      _pageSelections.where((selected) => selected).length;

  // Print option setters
  void setNumberOfCopies(int value) {
    if (value > 0 && value <= 100 && value != _numberOfCopies) {
      _numberOfCopies = value;
      _notifyListeners();
    }
  }

  void setIsMonochromatic(bool value) {
    if (value != _isMonochromatic) {
      _isMonochromatic = value;
      _notifyListeners();
    }
  }

  // Advanced setters
  void setPageOrientation(String orientation) {
    if (orientation != _pageOrientation &&
        ['portrait', 'landscape'].contains(orientation)) {
      _pageOrientation = orientation;
      _notifyListeners();
    }
  }

  void setAutoFit(bool value) {
    if (value != _autoFit) {
      _autoFit = value;
      _notifyListeners();
    }
  }

  void setBrightness(double value) {
    final clampedValue = value.clamp(-1.0, 1.0);
    if (clampedValue != _brightness) {
      _brightness = clampedValue;
      _notifyListeners();
    }
  }

  void setContrast(double value) {
    final clampedValue = value.clamp(-1.0, 1.0);
    if (clampedValue != _contrast) {
      _contrast = clampedValue;
      _notifyListeners();
    }
  }

  // Quick presets
  void applyPreset(String preset) {
    _batchUpdate(() {
      switch (preset) {
        case 'draft':
          _isMonochromatic = true;
          _brightness = -0.2;
          _contrast = -0.1;
          break;
        case 'normal':
          _isMonochromatic = false;
          _brightness = 0.0;
          _contrast = 0.0;
          break;
        case 'high_quality':
          _isMonochromatic = false;
          _brightness = 0.1;
          _contrast = 0.2;
          break;
        case 'economical':
          _isMonochromatic = true;
          _brightness = -0.1;
          _contrast = -0.2;
          break;
      }
    });
  }

  // Page manipulation methods
  void duplicatePage(int pageIndex) {
    // This would need to be handled in the UI layer
    // as it involves manipulating the page data list
    notifyListeners();
  }

  void deletePage(int pageIndex) {
    // This would need to be handled in the UI layer
    notifyListeners();
  }

  // Enhanced payment methods
  Future<void> verifyPayment() async {
    if (_isVerifyingPayment) return;

    _isVerifyingPayment = true;
    notifyListeners();

    try {
      // Simulate realistic payment verification with network delay
      await Future.delayed(
        Duration(milliseconds: 2000 + Random().nextInt(1000)),
      );

      // Simulate payment gateway response with higher success rate
      final random = Random();
      final success = random.nextDouble() > 0.05; // 95% success rate

      if (success) {
        _isPaymentVerified = true;
        debugPrint('✓ Payment verified successfully');
        debugPrint('  Amount: ₹${totalCost.toStringAsFixed(2)}');
        debugPrint('  Pages: $_totalPages');
        debugPrint('  Copies: $_numberOfCopies');
        debugPrint('  Mode: ${_isMonochromatic ? "B&W" : "Color"}');
      } else {
        debugPrint('✗ Payment verification failed');
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

  // Enhanced print method with better validation
  Future<void> printDocument(File documentFile) async {
    if (!canPrint) {
      throw Exception('Cannot print: ${_getCannotPrintReason()}');
    }

    try {
      debugPrint('=== ENHANCED PRINT JOB ===');
      debugPrint('Document: ${documentFile.path.split('/').last}');
      debugPrint('Type: $_documentType');
      debugPrint('File size: ${await documentFile.length()} bytes');
      debugPrint('Configuration:');
      debugPrint('  - Total pages: $_totalPages');
      debugPrint(
        '  - Selected pages: ${selectedPagesCount > 0 ? selectedPagesCount : _totalPages}',
      );
      debugPrint('  - Copies per page: $_numberOfCopies');
      debugPrint(
        '  - Color mode: ${_isMonochromatic ? "Monochrome" : "Full Color"}',
      );
      debugPrint('  - Orientation: $_pageOrientation');
      debugPrint('  - Auto-fit: $_autoFit');
      debugPrint('  - Brightness: ${(_brightness * 100).round()}%');
      debugPrint('  - Contrast: ${(_contrast * 100).round()}%');

      final breakdown = enhancedCostBreakdown;
      debugPrint('Cost Analysis:');
      breakdown.forEach((key, value) {
        debugPrint('  - $key: ₹${value.toStringAsFixed(2)}');
      });

      debugPrint('Total Cost: ₹${totalCost.toStringAsFixed(2)}');
      debugPrint('========================');

      // Simulate print processing with progress
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint('Processing... ${((i + 1) / 3 * 100).round()}%');
      }
    } catch (e) {
      debugPrint('Print error: $e');
      rethrow;
    }
  }

  // Reset all settings
  void resetSettings() {
    _batchUpdate(() {
      _numberOfCopies = 1;
      _isMonochromatic = false;
      _pageOrientation = 'portrait';
      _autoFit = true;
      _brightness = 0.0;
      _contrast = 0.0;
      _isPaymentVerified = false;
      _isVerifyingPayment = false;
      _pageSelections = List.filled(_totalPages, false);
    });
  }

  // Enhanced validation methods
  bool get canPrint {
    return _isPaymentVerified &&
        _numberOfCopies > 0 &&
        !_isVerifyingPayment &&
        _totalPages > 0;
  }

  String _getCannotPrintReason() {
    if (!_isPaymentVerified) return 'Payment not verified';
    if (_isVerifyingPayment) return 'Payment verification in progress';
    if (_numberOfCopies <= 0) return 'Invalid number of copies';
    if (_totalPages <= 0) return 'No pages to print';
    return 'Unknown reason';
  }

  bool get hasUnsavedChanges {
    return _numberOfCopies != 1 ||
        _isMonochromatic != false ||
        _brightness != 0.0 ||
        _contrast != 0.0 ||
        _pageSelections.any((selected) => selected);
  }

  String get paymentStatusMessage {
    if (_isVerifyingPayment) {
      return 'Verifying payment...';
    } else if (_isPaymentVerified) {
      return 'Payment verified successfully';
    } else {
      return 'Payment verification required';
    }
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

  // Export comprehensive settings
  Map<String, dynamic> get enhancedSettingsSnapshot {
    return {
      'numberOfCopies': _numberOfCopies,
      'isMonochromatic': _isMonochromatic,
      'pageOrientation': _pageOrientation,
      'autoFit': _autoFit,
      'brightness': _brightness,
      'contrast': _contrast,
      'totalPages': _totalPages,
      'selectedPages': _pageSelections,
      'documentType': _documentType,
      'totalCost': totalCost,
      'costBreakdown': enhancedCostBreakdown,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '2.0',
    };
  }

  // Import settings with validation
  void applyEnhancedSettings(Map<String, dynamic> settings) {
    try {
      _batchUpdate(() {
        _numberOfCopies = (settings['numberOfCopies'] as num?)?.toInt() ?? 1;
        _isMonochromatic = settings['isMonochromatic'] as bool? ?? false;
        _pageOrientation = settings['pageOrientation'] as String? ?? 'portrait';
        _autoFit = settings['autoFit'] as bool? ?? true;
        _brightness = (settings['brightness'] as num?)?.toDouble() ?? 0.0;
        _contrast = (settings['contrast'] as num?)?.toDouble() ?? 0.0;

        if (settings.containsKey('totalPages')) {
          _totalPages = (settings['totalPages'] as num?)?.toInt() ?? 1;
        }

        if (settings.containsKey('selectedPages')) {
          final selections = settings['selectedPages'] as List?;
          if (selections != null) {
            _pageSelections = selections.cast<bool>();
          }
        }

        if (settings.containsKey('documentType')) {
          _documentType = settings['documentType'] as String? ?? 'photo';
        }
      });
    } catch (e) {
      debugPrint('Error applying settings: $e');
    }
  }

  // Quality preset shortcuts
  void setDraftQuality() => applyPreset('draft');
  void setNormalQuality() => applyPreset('normal');
  void setHighQuality() => applyPreset('high_quality');
  void setEconomicalMode() => applyPreset('economical');

  // Bulk operations
  void bulkSetCopies(List<int> pageIndices, int copies) {
    // This would be implemented in the UI layer
    // as it affects individual page settings
    notifyListeners();
  }

  void bulkToggleColor(List<int> pageIndices) {
    // This would be implemented in the UI layer
    notifyListeners();
  }

  // Statistics and analytics
  Map<String, dynamic> get printingStatistics {
    return {
      'totalSheets': _totalPages * _numberOfCopies,
      'estimatedPrintTime':
          '${(_totalPages * _numberOfCopies * 0.5).ceil()} seconds',
      'paperUsage': '${_totalPages * _numberOfCopies} sheets',
      'inkUsage': _isMonochromatic ? 'Low (B&W)' : 'Medium (Color)',
      'costPerPage':
          '₹${(totalCost / (_totalPages * _numberOfCopies)).toStringAsFixed(2)}',
    };
  }

  @override
  void dispose() {
    debugPrint('Enhanced PreviewViewModel disposed');
    super.dispose();
  }
}
