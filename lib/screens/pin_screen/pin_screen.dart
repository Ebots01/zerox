// lib/screens/pin_screen/pin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import '../preview_screen/preview_screen.dart';
import 'pin_view_model.dart';
import '../../services/download_service.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeAnimController;
  late final AnimationController _pulseAnimController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;
  bool _isServiceStarted = false;
  String _currentPin = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fadeAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimController, curve: Curves.easeInOut),
    );

    _pulseAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseAnimController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionAndStartService();
      _fadeAnimController.forward();
    });
  }

  Future<void> _requestPermissionAndStartService() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (status.isGranted) {
      if (!_isServiceStarted && mounted) {
        context.read<DownloadService>().startDownloading();
        setState(() => _isServiceStarted = true);
      }
    }
  }

  void _onNumberTap(String number) {
    if (_currentPin.length < 4) {
      setState(() {
        _currentPin += number;
      });
      context.read<PinViewModel>().setPin(_currentPin);

      // Add haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _onBackspace() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
      context.read<PinViewModel>().setPin(_currentPin);
      HapticFeedback.lightImpact();
    }
  }

  void _onClear() {
    setState(() {
      _currentPin = '';
    });
    context.read<PinViewModel>().setPin('');
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _fadeAnimController.dispose();
    _pulseAnimController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.indigo.shade900,
              Colors.purple.shade800,
              Colors.deepPurple.shade900,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: OrientationBuilder(
            builder: (context, orientation) {
              return orientation == Orientation.landscape
                  ? _buildLandscapeLayout()
                  : _buildPortraitLayout();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHeader(),
                    _buildPinDisplay(),
                    _buildErrorMessage(),
                    _buildNumpad(),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildBrandingWidget()),
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.98),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.08,
                          vertical: constraints.maxHeight * 0.05,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildHeader(isDark: false),
                            _buildPinDisplay(isDark: false, isLandscape: true),
                            _buildErrorMessage(),
                            _buildNumpad(isLandscape: true),
                            _buildSubmitButton(isLandscape: true),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade800,
            Colors.purple.shade700,
            Colors.deepPurple.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.print_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ZEROXA',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Print Kiosk',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Secure Document Access',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool isDark = true}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.cyanAccent : Colors.indigo;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.indigo.withOpacity(0.1)),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.security, size: 50, color: iconColor),
        ),
        const SizedBox(height: 20),
        Text(
          'Enter PIN Code',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please enter your 4-digit document PIN',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildPinDisplay({bool isDark = true, bool isLandscape = false}) {
    final errorMessage = context.watch<PinViewModel>().errorMessage;
    final hasError = errorMessage.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: isLandscape ? 8 : 20,
        horizontal: isLandscape ? 20 : 0,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 32 : 40,
        vertical: isLandscape ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasError
              ? Colors.red.shade400
              : (isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade300),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'PIN CODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (isDark ? Colors.white : Colors.grey.shade600).withOpacity(
                0.8,
              ),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              final bool isFilled = index < _currentPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isFilled ? 20 : 16,
                height: isFilled ? 20 : 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? (isDark ? Colors.cyanAccent : Colors.indigo.shade600)
                      : (isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.grey.shade400),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color:
                                (isDark
                                        ? Colors.cyanAccent
                                        : Colors.indigo.shade600)
                                    .withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentPin.length}/4',
            style: TextStyle(
              fontSize: 11,
              color: (isDark ? Colors.white : Colors.grey.shade600).withOpacity(
                0.6,
              ),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    final errorMessage = context.watch<PinViewModel>().errorMessage;
    if (errorMessage.isEmpty) {
      return const SizedBox(height: 10);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad({bool isLandscape = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate button size based on available space and orientation
        double buttonSize;
        if (isLandscape) {
          // In landscape, use smaller buttons to fit all keys
          buttonSize = constraints.maxWidth * 0.15; // 15% of available width
          buttonSize = buttonSize.clamp(45.0, 65.0); // Min 45px, Max 65px
        } else {
          // In portrait, use larger buttons
          buttonSize = (constraints.maxWidth / 4.2);
          buttonSize = buttonSize.clamp(60.0, 90.0); // Min 60px, Max 90px
        }

        return Container(
          constraints: BoxConstraints(
            maxWidth: isLandscape
                ? constraints.maxWidth * 0.8
                : double.infinity,
          ),
          child: Column(
            children: [
              _buildNumpadRow(['1', '2', '3'], buttonSize, isLandscape),
              _buildNumpadRow(['4', '5', '6'], buttonSize, isLandscape),
              _buildNumpadRow(['7', '8', '9'], buttonSize, isLandscape),
              _buildActionRow(buttonSize, isLandscape),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNumpadRow(
    List<String> numbers,
    double buttonSize,
    bool isLandscape,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLandscape ? 3 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: numbers
            .map(
              (number) => _buildNumberButton(number, buttonSize, isLandscape),
            )
            .toList(),
      ),
    );
  }

  Widget _buildActionRow(double buttonSize, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLandscape ? 3 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            Icons.clear,
            'Clear',
            buttonSize,
            _onClear,
            isLandscape,
          ),
          _buildNumberButton('0', buttonSize, isLandscape),
          _buildActionButton(
            Icons.backspace_outlined,
            'Delete',
            buttonSize,
            _onBackspace,
            isLandscape,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number, double size, bool isLandscape) {
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.all(isLandscape ? 2 : 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size / 2),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: () => _onNumberTap(number),
          splashColor: Colors.indigo.shade100,
          highlightColor: Colors.indigo.shade50,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(color: Colors.indigo.shade100, width: 1),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.shade100.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: size * 0.35,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String tooltip,
    double size,
    VoidCallback onTap,
    bool isLandscape,
  ) {
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.all(isLandscape ? 2 : 4),
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(size / 2),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          splashColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(color: Colors.grey.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: size * 0.3, color: Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({bool isLandscape = false}) {
    final viewModel = context.read<PinViewModel>();
    final isLoading = context.watch<PinViewModel>().isLoading;
    final canSubmit = _currentPin.length == 4 && !isLoading;

    return ScaleTransition(
      scale: canSubmit ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: double.infinity,
        height: isLandscape ? 48 : 56,
        margin: EdgeInsets.symmetric(horizontal: isLandscape ? 40 : 20),
        child: ElevatedButton(
          onPressed: canSubmit
              ? () async {
                  HapticFeedback.mediumImpact();
                  final file = await viewModel.validatePin();
                  if (file != null && mounted) {
                    setState(() => _currentPin = '');
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            PreviewScreen(documentFile: file),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: animation.drive(
                                  Tween(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).chain(
                                    CurveTween(curve: Curves.easeOutCubic),
                                  ),
                                ),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit
                ? Colors.indigo.shade600
                : Colors.grey.shade300,
            foregroundColor: canSubmit ? Colors.white : Colors.grey.shade500,
            elevation: canSubmit ? 6 : 1,
            shadowColor: canSubmit
                ? Colors.indigo.shade300.withOpacity(0.5)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isLandscape ? 24 : 28),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: isLandscape ? 20 : 24,
                  height: isLandscape ? 20 : 24,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_open, size: isLandscape ? 18 : 20),
                    const SizedBox(width: 8),
                    Text(
                      'ACCESS DOCUMENT',
                      style: TextStyle(
                        fontSize: isLandscape ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
