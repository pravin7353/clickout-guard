import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import '../../core/theme/app_theme.dart';
import 'guard_verify_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // 🛑 BRAKE 1: Scanner Controller me Timeout lagaya (1.5 seconds)
  final MobileScannerController cameraController = MobileScannerController(
    detectionTimeoutMs: 1500,
  );

  bool isScanning = true;
  DateTime? _lastScanTime; // 🛑 BRAKE 2: Smart Debounce Timer

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!isScanning) return;

    // 🛑 BRAKE 2 (LOGIC): Agar pichle scan ko 2 second nahi hue, toh naya scan ignore karo!
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }
    _lastScanTime = now; // Naya time set karo

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => isScanning = false); // Pause scanner

        // 📳 Haptic Feedback on scan (Vibration)
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 100);
        }

        if (!mounted) return;

        // 🚀 Navigate to Real-time Verify Screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuardVerifyScreen(orderId: barcode.rawValue!),
          ),
        );

        // 🛑 BRAKE 3: Wapas aane ke baad turant scan mat karo, thoda ruko (Like Paytm)
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                isScanning = true;
                _lastScanTime = null; // Reset the timer
              });
            }
          });
        }
        break; // Process only first barcode detected
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Gate Pass",
            style: TextStyle(color: AppTheme.primaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on, color: AppTheme.primaryColor),
            onPressed: () {
              try {
                cameraController.toggleTorch();
              } catch (e) {
                debugPrint("Torch Error: $e");
              }
            },
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.cameraswitch),
            onPressed: () {
              try {
                cameraController.switchCamera();
              } catch (e) {
                debugPrint("Camera Switch Error: $e");
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Scanner Camera
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // 2. Custom Dark Overlay with Cutout
          CustomPaint(
            painter: GuardScannerOverlayPainter(),
            child: Container(),
          ),

          // 3. Instructions
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Icon(Icons.security, color: AppTheme.primaryColor, size: 40),
                SizedBox(height: 10),
                Text(
                  "Align Customer Gate Pass\nwithin the yellow frame",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🎯 PREMIUM CUTOUT OVERLAY (UI)
class GuardScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7) // ✅ Warning fixed
      ..style = PaintingStyle.fill;

    final double scanAreaSize = size.width * 0.75;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(20)));
    final Path finalPath =
        Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    canvas.drawPath(finalPath, paint);

    // 🟡 Guard Yellow Borders
    final borderPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 40.0;

    // Draw 4 corners
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.left, scanRect.top + cornerLength)
          ..lineTo(scanRect.left, scanRect.top)
          ..lineTo(scanRect.left + cornerLength, scanRect.top),
        borderPaint);
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.right - cornerLength, scanRect.top)
          ..lineTo(scanRect.right, scanRect.top)
          ..lineTo(scanRect.right, scanRect.top + cornerLength),
        borderPaint);
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.left, scanRect.bottom - cornerLength)
          ..lineTo(scanRect.left, scanRect.bottom)
          ..lineTo(scanRect.left + cornerLength, scanRect.bottom),
        borderPaint);
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
          ..lineTo(scanRect.right, scanRect.bottom)
          ..lineTo(scanRect.right, scanRect.bottom - cornerLength),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
