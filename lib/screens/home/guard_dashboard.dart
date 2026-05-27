import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';
import 'qr_scanner_screen.dart';
import '../../utils/session_manager.dart';

class GuardDashboard extends StatefulWidget {
  const GuardDashboard({super.key});

  @override
  State<GuardDashboard> createState() => _GuardDashboardState();
}

class _GuardDashboardState extends State<GuardDashboard> {
  @override
  void initState() {
    super.initState();
    _restoreSessionMemory();
  }

  Future<void> _restoreSessionMemory() async {
    if (SessionManager.branchCode.isEmpty) {
      await SessionManager.init();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🛡️ POPSCOPE: Prevents back button from closing the app silently
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Silently blocks the back button. Kuch nahi dikhayega.
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Guard Panel",
              style: TextStyle(color: Color(0xFFF7B731))),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await SessionManager.clear(); // 🧹 FIX: Memory Card Format!
                await FirebaseAuth.instance.signOut();
                // ✅ WARNING FIX: Check if widget is mounted after async
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WELCOME CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                  // ✅ WARNING FIX: .withValues instead of deprecated .withOpacity
                  border: Border.all(
                      color: const Color(0xFFF7B731).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFF7B731),
                      child: Icon(Icons.person, color: Colors.black),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Welcome on Duty,",
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        // 🚀 DISPLAY NAME (Fallback to number if issue occurs)
                        Text(user?.displayName ?? user?.phoneNumber ?? "Guard",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),

              const Spacer(),

              // SCAN BUTTON
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const QRScannerScreen()),
                    );
                  },
                  child: Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7B731),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          // ✅ WARNING FIX: .withValues(alpha: 0.4)
                          color: const Color(0xFFF7B731).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 60, color: Colors.black),
                        SizedBox(height: 10),
                        Text(
                          "SCAN BILL",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Center(
                child: Text(
                  "ClickOut Guard System v1.0",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
