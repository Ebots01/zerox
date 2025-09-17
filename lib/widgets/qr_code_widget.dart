// lib/widgets/qr_code_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeWidget extends StatefulWidget {
  final String data;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showCopyButton;
  final bool showPaymentInfo;
  final String? paymentAmount;
  final String? merchantName;
  final VoidCallback? onPaymentInitiated;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 150.0,
    this.backgroundColor,
    this.foregroundColor,
    this.showCopyButton = true,
    this.showPaymentInfo = true,
    this.paymentAmount,
    this.merchantName,
    this.onPaymentInitiated,
  });

  @override
  State<QrCodeWidget> createState() => _QrCodeWidgetState();
}

class _QrCodeWidgetState extends State<QrCodeWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  bool _isScanning = false;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });

    _scanController.repeat();
    widget.onPaymentInitiated?.call();

    // Simulate scan detection
    _scanTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _scanController.stop();
        _showScanSuccessDialog();
      }
    });
  }

  void _showScanSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'QR Code Detected!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Payment app should open automatically',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.data));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Payment link copied to clipboard'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Map<String, String> _parseUPIData() {
    final uri = Uri.tryParse(widget.data);
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
        color: widget.backgroundColor ?? Colors.white,
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
          // QR Code with animations
          _buildAnimatedQRCode(),

          const SizedBox(height: 16),

          // Payment information
          if (widget.showPaymentInfo) _buildPaymentInfo(),

          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(),

          const SizedBox(height: 12),

          // Instructions
          _buildInstructions(),
        ],
      ),
    );
  }

  Widget _buildAnimatedQRCode() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse animation background
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: widget.size + 20,
                height: widget.size + 20,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
        ),

        // QR Code
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: QrImageView(
            data: widget.data,
            version: QrVersions.auto,
            size: widget.size,
            backgroundColor: widget.backgroundColor ?? Colors.white,
            foregroundColor: widget.foregroundColor ?? Colors.black,
            errorStateBuilder: (context, error) => _buildErrorState(),
          ),
        ),

        // Scanning overlay
        if (_isScanning) _buildScanningOverlay(),
      ],
    );
  }

  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withAlpha(128), width: 2),
          ),
          child: Stack(
            children: [
              // Scanning line
              Positioned(
                left: 0,
                right: 0,
                top: _scanAnimation.value * (widget.size + 16 - 4),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withAlpha(128),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: widget.size,
      height: widget.size,
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
            size: widget.size * 0.2,
          ),
          SizedBox(height: widget.size * 0.05),
          Text(
            'QR Code Error',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: widget.size * 0.08,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    if (!widget.data.startsWith('upi://')) {
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

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scan button
        if (!_isScanning) ...[
          ElevatedButton.icon(
            onPressed: _startScanning,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text(
              'Scan with Camera',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            label: const Text(
              'Scanning...',
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],

        // Copy button
        if (widget.showCopyButton) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _copyToClipboard,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade600,
              side: BorderSide(color: Colors.blue.shade600),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'How to Pay',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Open any UPI app (GPay, PhonePe, Paytm, etc.) and scan this QR code to make payment instantly',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Enhanced QR code widget specifically for print shop payments
class PrintShopQrWidget extends StatelessWidget {
  final double amount;
  final int pages;
  final int copies;
  final bool isColor;
  final String? orderId;
  final VoidCallback? onPaymentComplete;

  const PrintShopQrWidget({
    super.key,
    required this.amount,
    required this.pages,
    required this.copies,
    required this.isColor,
    this.orderId,
    this.onPaymentComplete,
  });

  String get upiLink {
    final orderRef = orderId ?? 'DOC${DateTime.now().millisecondsSinceEpoch}';
    final description =
        'Print: ${pages}pg×${copies}cp ${isColor ? 'Color' : 'BW'}';

    return 'upi://pay?pa=printshop@upi&pn=Digital Print Shop&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$description&tr=$orderRef';
  }

  @override
  Widget build(BuildContext context) {
    return QrCodeWidget(
      data: upiLink,
      size: 180,
      showPaymentInfo: true,
      paymentAmount: amount.toStringAsFixed(2),
      merchantName: 'Digital Print Shop',
      onPaymentInitiated: onPaymentComplete,
    );
  }
}
