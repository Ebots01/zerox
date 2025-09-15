// lib/widgets/qr_code_widget.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;

  const QrCodeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return QrImageView(data: data, version: QrVersions.auto, size: 150.0);
  }
}
