// lib/screens/preview_screen/preview_view_model.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class PreviewViewModel extends ChangeNotifier {
  // Print settings
  int _numberOfCopies = 1;
  bool _isMonochromatic = false;
  int _pagesPerSheet = 1;

  // Page edit settings
  double _zoomLevel = 1.0;
  double _rotationAngle = 0.0;

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
  static const double _baseCostPerCopy = 1.0;
  static const double _colorSurcharge = 0.5;
  static const double _minZoom = 0.1;
  static const double _maxZoom = 3.0;

  // Getters
  int get numberOfCopies => _numberOfCopies;
  bool get isMonochromatic => _isMonochromatic;
  int get pagesPerSheet => _pagesPerSheet;
  double get zoomLevel => _zoomLevel;
  double get rotationAngle => _rotationAngle;
  String get pageOrientation => _pageOrientation;
  bool get autoFit => _autoFit;
  double get brightness => _brightness;
  double get contrast => _contrast;
  bool get isPaymentVerified => _isPaymentVerified;
  bool get isVerifyingPayment => _isVerifyingPayment;
  bool get isUpdating => _isUpdating;

  double get totalCost {
    double baseCost = _numberOfCopies * _baseCostPerCopy;
    double colorCost = _isMonochromatic
        ? 0.0
        : _numberOfCopies * _colorSurcharge;

    // Add multi-page discount
    double multiPageDiscount = 0.0;
    if (_pagesPerSheet > 1) {
      multiPageDiscount = baseCost * 0.1; // 10% discount for multi-page sheets
    }

    return (baseCost + colorCost - multiPageDiscount).clamp(
      0.0,
      double.infinity,
    );
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

  // Print option setters
  void setNumberOfCopies(int value) {
    if (value > 0 && value <= 50 && value != _numberOfCopies) {
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

  void setPagesPerSheet(int value) {
    if (value != _pagesPerSheet && [1, 2, 4, 6, 9].contains(value)) {
      _pagesPerSheet = value;

      // Auto-adjust zoom for better fit
      if (_autoFit) {
        switch (value) {
          case 1:
            _zoomLevel = 1.0;
            break;
          case 2:
            _zoomLevel = 0.7;
            break;
          case 4:
            _zoomLevel = 0.5;
            break;
          case 6:
          case 9:
            _zoomLevel = 0.4;
            break;
        }
      }

      _notifyListeners();
    }
  }

  // Page edit setters with validation
  void setZoomLevel(double value) {
    final clampedValue = value.clamp(_minZoom, _maxZoom);
    if (clampedValue != _zoomLevel) {
      _zoomLevel = clampedValue;
      _notifyListeners();
    }
  }

  void setRotationAngle(double angle) {
    final normalizedAngle = angle % 360;
    if (normalizedAngle != _rotationAngle) {
      _rotationAngle = normalizedAngle;
      _notifyListeners();
    }
  }

  // Advanced setters
  void setPageOrientation(String orientation) {
    if (orientation != _pageOrientation &&
        ['portrait', 'landscape'].contains(orientation)) {
      _pageOrientation = orientation;
      // Auto-rotate based on orientation
      if (orientation == 'landscape' && _rotationAngle == 0) {
        _rotationAngle = 90;
      } else if (orientation == 'portrait' && _rotationAngle == 90) {
        _rotationAngle = 0;
      }
      _notifyListeners();
    }
  }

  void setAutoFit(bool value) {
    if (value != _autoFit) {
      _autoFit = value;
      if (value) {
        _optimizeZoomForPagesPerSheet();
      }
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

  // Helper methods
  void _optimizeZoomForPagesPerSheet() {
    switch (_pagesPerSheet) {
      case 1:
        _zoomLevel = 1.0;
        break;
      case 2:
        _zoomLevel = 0.7;
        break;
      case 4:
        _zoomLevel = 0.5;
        break;
      case 6:
      case 9:
        _zoomLevel = 0.4;
        break;
    }
  }

  // Rotation methods
  void rotateLeft() {
    _rotationAngle = (_rotationAngle - 90) % 360;
    if (_rotationAngle < 0) _rotationAngle += 360;
    _updateOrientationFromRotation();
    _notifyListeners();
  }

  void rotateRight() {
    _rotationAngle = (_rotationAngle + 90) % 360;
    _updateOrientationFromRotation();
    _notifyListeners();
  }

  void resetRotation() {
    if (_rotationAngle != 0.0) {
      _rotationAngle = 0.0;
      _pageOrientation = 'portrait';
      _notifyListeners();
    }
  }

  void _updateOrientationFromRotation() {
    if (_rotationAngle == 0 || _rotationAngle == 180) {
      _pageOrientation = 'portrait';
    } else {
      _pageOrientation = 'landscape';
    }
  }

  // Zoom methods
  void zoomIn() {
    setZoomLevel(_zoomLevel * 1.2);
  }

  void zoomOut() {
    setZoomLevel(_zoomLevel / 1.2);
  }

  void resetZoom() {
    setZoomLevel(1.0);
  }

  void fitToWidth() {
    setZoomLevel(1.2);
  }

  void fitToPage() {
    setZoomLevel(1.0);
  }

  // Quick presets
  void applyPreset(String preset) {
    _batchUpdate(() {
      switch (preset) {
        case 'draft':
          _isMonochromatic = true;
          _pagesPerSheet = 2;
          _zoomLevel = 0.7;
          break;
        case 'normal':
          _isMonochromatic = false;
          _pagesPerSheet = 1;
          _zoomLevel = 1.0;
          break;
        case 'high_quality':
          _isMonochromatic = false;
          _pagesPerSheet = 1;
          _zoomLevel = 1.2;
          break;
        case 'economical':
          _isMonochromatic = true;
          _pagesPerSheet = 4;
          _zoomLevel = 0.5;
          break;
      }
    });
  }

  // Payment methods
  Future<void> verifyPayment() async {
    if (_isVerifyingPayment) return;

    _isVerifyingPayment = true;
    notifyListeners();

    try {
      // Simulate API call with realistic delay
      await Future.delayed(
        Duration(milliseconds: 1500 + Random().nextInt(1000)),
      );

      // Simulate payment gateway response
      // In a real app, this would call actual payment verification API
      final random = Random();
      final success = random.nextDouble() > 0.1; // 90% success rate for demo

      if (success) {
        _isPaymentVerified = true;
        // Log successful payment
        debugPrint(
          'Payment verified successfully for amount: ₹${totalCost.toStringAsFixed(2)}',
        );
      } else {
        // Handle payment failure
        debugPrint('Payment verification failed');
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

  // Print method with enhanced logging
  Future<void> printDocument(File documentFile) async {
    if (!canPrint) {
      throw Exception('Cannot print: Payment not verified or invalid settings');
    }

    try {
      debugPrint('=== PRINT JOB DETAILS ===');
      debugPrint('Document: ${documentFile.path}');
      debugPrint('File size: ${await documentFile.length()} bytes');
      debugPrint('Settings:');
      debugPrint('  - Copies: $_numberOfCopies');
      debugPrint(
        '  - Color mode: ${_isMonochromatic ? "Monochrome" : "Color"}',
      );
      debugPrint('  - Pages per sheet: $_pagesPerSheet');
      debugPrint('  - Zoom level: ${(_zoomLevel * 100).round()}%');
      debugPrint('  - Rotation: $_rotationAngle°');
      debugPrint('  - Orientation: $_pageOrientation');
      debugPrint('  - Auto-fit: $_autoFit');
      debugPrint('Cost breakdown:');
      final breakdown = costBreakdown;
      breakdown.forEach((key, value) {
        debugPrint('  - $key: ₹${value.toStringAsFixed(2)}');
      });
      debugPrint('=== END PRINT JOB ===');

      // TODO: Implement actual printing logic here
      // This would include:
      // 1. Convert document with applied transformations
      // 2. Apply color/brightness/contrast adjustments
      // 3. Layout pages according to pagesPerSheet setting
      // 4. Send to printer queue

      // Simulate print processing
      await Future.delayed(const Duration(milliseconds: 500));
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
      _pagesPerSheet = 1;
      _zoomLevel = 1.0;
      _rotationAngle = 0.0;
      _pageOrientation = 'portrait';
      _autoFit = true;
      _brightness = 0.0;
      _contrast = 0.0;
      _isPaymentVerified = false;
      _isVerifyingPayment = false;
    });
  }

  // Validation methods
  bool get canPrint =>
      _isPaymentVerified && _numberOfCopies > 0 && !_isVerifyingPayment;

  bool get hasUnsavedChanges =>
      _numberOfCopies != 1 ||
      _isMonochromatic != false ||
      _pagesPerSheet != 1 ||
      _zoomLevel != 1.0 ||
      _rotationAngle != 0.0 ||
      _brightness != 0.0 ||
      _contrast != 0.0;

  String get paymentStatusMessage {
    if (_isVerifyingPayment) {
      return 'Verifying payment...';
    } else if (_isPaymentVerified) {
      return 'Payment verified successfully';
    } else {
      return 'Payment verification required';
    }
  }

  // Cost breakdown with detailed information
  Map<String, double> get costBreakdown {
    final baseCost = _numberOfCopies * _baseCostPerCopy;
    final colorSurcharge = _isMonochromatic
        ? 0.0
        : _numberOfCopies * _colorSurcharge;
    final multiPageDiscount = _pagesPerSheet > 1 ? baseCost * 0.1 : 0.0;

    return {
      'baseCost': baseCost,
      'colorSurcharge': colorSurcharge,
      'multiPageDiscount': multiPageDiscount,
      'total': totalCost,
    };
  }

  // Export settings for sharing or saving
  Map<String, dynamic> get settingsSnapshot {
    return {
      'numberOfCopies': _numberOfCopies,
      'isMonochromatic': _isMonochromatic,
      'pagesPerSheet': _pagesPerSheet,
      'zoomLevel': _zoomLevel,
      'rotationAngle': _rotationAngle,
      'pageOrientation': _pageOrientation,
      'autoFit': _autoFit,
      'brightness': _brightness,
      'contrast': _contrast,
      'totalCost': totalCost,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Import settings
  void applySettings(Map<String, dynamic> settings) {
    _batchUpdate(() {
      _numberOfCopies = settings['numberOfCopies'] ?? 1;
      _isMonochromatic = settings['isMonochromatic'] ?? false;
      _pagesPerSheet = settings['pagesPerSheet'] ?? 1;
      _zoomLevel = settings['zoomLevel'] ?? 1.0;
      _rotationAngle = settings['rotationAngle'] ?? 0.0;
      _pageOrientation = settings['pageOrientation'] ?? 'portrait';
      _autoFit = settings['autoFit'] ?? true;
      _brightness = settings['brightness'] ?? 0.0;
      _contrast = settings['contrast'] ?? 0.0;
    });
  }

  @override
  void dispose() {
    debugPrint('PreviewViewModel disposed');
    super.dispose();
  }
}
