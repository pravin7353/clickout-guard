import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // 👈 Aapke cashier app ka login screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final Color darkBaseColor = const Color(0xFF101010);
  final Color deepGreen = const Color(0xFF052E16);
  final Color brandGreen = const Color(0xFF16A34A);

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _scannerController;
  late Animation<double> _scannerPosition;

  late AnimationController _verifiedController;
  late Animation<double> _verifiedScale;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scannerPosition = Tween<double>(begin: -50, end: 150).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );

    _verifiedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _verifiedScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _verifiedController, curve: Curves.elasticOut),
    );

    _runAnimationSequence();
  }

  void _runAnimationSequence() async {
    await _logoController.forward();
    await _scannerController.forward();
    await _verifiedController.forward();
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _scannerController.dispose();
    _verifiedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBaseColor,
      body: Stack(
        children: [
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: deepGreen.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Click",
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Text(
                                    "Out",
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: brandGreen,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: _scannerController,
                        builder: (context, child) {
                          if (!_scannerController.isAnimating &&
                              _scannerController.isDismissed) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            top: _scannerPosition.value,
                            child: Opacity(
                              opacity:
                                  _scannerController.value > 0.9 ? 0.0 : 1.0,
                              child: Container(
                                width: 200,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: brandGreen,
                                  boxShadow: [
                                    BoxShadow(
                                      color: brandGreen.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _verifiedController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _verifiedScale.value,
                      child: Opacity(
                        opacity: _verifiedScale.value.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: brandGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: brandGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: brandGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.black, size: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "SYSTEM SECURE",
                                style: TextStyle(
                                  color: brandGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
