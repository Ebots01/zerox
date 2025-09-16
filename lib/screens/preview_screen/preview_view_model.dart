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

  // Payment settings
  bool _isPaymentVerified = false;
  bool _isVerifyingPayment = false;

  // Constants
  static const double _baseCostPerCopy = 1.0;
  static const double _colorSurcharge = 0.5;

  // Getters
  int get numberOfCopies => _numberOfCopies;
  bool get isMonochromatic => _isMonochromatic;
  int get pagesPerSheet => _pagesPerSheet;
  double get zoomLevel => _zoomLevel;
  double get rotationAngle => _rotationAngle;
  bool get isPaymentVerified => _isPaymentVerified;
  bool get isVerifyingPayment => _isVerifyingPayment;

  double get totalCost {
    double baseCost = _numberOfCopies * _baseCostPerCopy;
    double colorCost = _isMonochromatic
        ? 0.0
        : _numberOfCopies * _colorSurcharge;
    return baseCost + colorCost;
  }

  // Print option setters
  void setNumberOfCopies(int value) {
    if (value > 0 && value <= 50) {
      _numberOfCopies = value;
      notifyListeners();
    }
  }

  void setIsMonochromatic(bool value) {
    _isMonochromatic = value;
    notifyListeners();
  }

  void setPagesPerSheet(int value) {
    _pagesPerSheet = value;
    notifyListeners();
  }

  // Page edit setters
  void setZoomLevel(double value) {
    _zoomLevel = value.clamp(0.5, 2.0);
    notifyListeners();
  }

  void setRotationAngle(double angle) {
    _rotationAngle = angle % 360;
    notifyListeners();
  }

  void rotateLeft() {
    _rotationAngle = (_rotationAngle - 90) % 360;
    notifyListeners();
  }

  void rotateRight() {
    _rotationAngle = (_rotationAngle + 90) % 360;
    notifyListeners();
  }

  void resetRotation() {
    _rotationAngle = 0.0;
    notifyListeners();
  }

  // Payment methods
  Future<void> verifyPayment() async {
    _isVerifyingPayment = true;
    notifyListeners();

    // Simulate payment verification delay
    await Future.delayed(const Duration(seconds: 2));

    // Dummy verification - in real app, this would call payment gateway API
    // For demo purposes, we'll randomly succeed or fail
    final random = Random();
    _isPaymentVerified = random.nextBool() || true; // Force success for demo

    _isVerifyingPayment = false;
    notifyListeners();
  }

  // Print method
  void printDocument(File documentFile) {
    // TODO: Implement actual printing logic
    // This would include:
    // 1. Apply zoom level and rotation to document
    // 2. Apply color/monochrome settings
    // 3. Apply pages per sheet layout
    // 4. Send to printer with specified number of copies

    print('Printing document: ${documentFile.path}');
    print('Copies: $_numberOfCopies');
    print('Monochromatic: $_isMonochromatic');
    print('Pages per sheet: $_pagesPerSheet');
    print('Zoom level: $_zoomLevel');
    print('Rotation: $_rotationAngle degrees');
    print('Total cost: ₹${totalCost.toStringAsFixed(2)}');
  }

  // Reset all settings
  void resetSettings() {
    _numberOfCopies = 1;
    _isMonochromatic = false;
    _pagesPerSheet = 1;
    _zoomLevel = 1.0;
    _rotationAngle = 0.0;
    _isPaymentVerified = false;
    _isVerifyingPayment = false;
    notifyListeners();
  }

  // Validation methods
  bool get canPrint => _isPaymentVerified && _numberOfCopies > 0;

  String get paymentStatusMessage {
    if (_isVerifyingPayment) {
      return 'Verifying payment...';
    } else if (_isPaymentVerified) {
      return 'Payment verified successfully';
    } else {
      return 'Payment verification required';
    }
  }

  // Cost breakdown
  Map<String, double> get costBreakdown {
    return {
      'baseCost': _numberOfCopies * _baseCostPerCopy,
      'colorSurcharge': _isMonochromatic
          ? 0.0
          : _numberOfCopies * _colorSurcharge,
      'total': totalCost,
    };
  }
}
