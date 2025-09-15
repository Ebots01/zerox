// lib/screens/preview_screen/preview_view_model.dart
import 'package:flutter/foundation.dart';
import '../../utils/app_constants.dart';

class PreviewViewModel extends ChangeNotifier {
  int _numberOfCopies = 1;
  bool _isMonochromatic = false;

  int get numberOfCopies => _numberOfCopies;
  bool get isMonochromatic => _isMonochromatic;
  double get totalCost => _numberOfCopies * COST_PER_COPY;

  void setNumberOfCopies(int value) {
    _numberOfCopies = value;
    notifyListeners();
  }

  void setIsMonochromatic(bool value) {
    _isMonochromatic = value;
    notifyListeners();
  }
}
