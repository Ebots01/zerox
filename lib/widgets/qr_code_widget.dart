// lib/widgets/qr_code_widget.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showPaymentInfo;
  final String? paymentAmount;
  final String? merchantName;

  const QrCodeWidget({
    Key? key,
    required this.data,
    this.size = 150.0,
    this.backgroundColor,
    this.foregroundColor,
    this.showPaymentInfo = true,
    this.paymentAmount,
    this.merchantName,
  }) : super(key: key);

  Map<String, String> _parseUPIData() {
    final uri = Uri.tryParse(data);
    if (uri == null) return {};
    final params = uri.queryParameters;
    return {
      'pa': params['pa'] ?? '',
      'pn': params['pn'] ?? '',
      'am': params['am'] ?? '',
      'cu': params['cu'] ?? 'INR',
      'tn': params['tn'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            backgroundColor: backgroundColor ?? Colors.white,
            foregroundColor: foregroundColor ?? Colors.black,
            errorStateBuilder: (context, error) => _buildErrorState(),
          ),
          const SizedBox(height: 16),
          if (showPaymentInfo) _buildPaymentInfo(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: size * 0.2,
          ),
          SizedBox(height: size * 0.05),
          Text(
            'QR Code Error',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: size * 0.08,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    if (!data.startsWith('upi://')) {
      return const SizedBox.shrink();
    }
    final upiData = _parseUPIData();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: Colors.green.shade600,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Details',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (upiData['pn']?.isNotEmpty == true) ...[
            _buildInfoRow('Merchant', upiData['pn']!),
            const SizedBox(height: 4),
          ],
          if (upiData['am']?.isNotEmpty == true) ...[
            _buildInfoRow('Amount', '₹${upiData['am']}'),
            const SizedBox(height: 4),
          ],
          if (upiData['tn']?.isNotEmpty == true)
            _buildInfoRow('Description', upiData['tn']!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
