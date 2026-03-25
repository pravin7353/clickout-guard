import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 Bouncer ko bulaya
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/guard_dashboard.dart'; // 👈 Dashboard import kiya
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 DB se data uthana hai
import '../utils/session_manager.dart'; // 👈 Session Manager

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Firebase Connect

  runApp(const GuardApp());
}

class GuardApp extends StatelessWidget {
  const GuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClickOut Guard',
      debugShowCheckedModeBanner: false,

      // 🎨 THEME CONFIGURATION
      themeMode: ThemeMode.dark, // Hamesha Dark Rahega
      theme: AppTheme.darkTheme, // Fallback
      darkTheme: AppTheme.darkTheme, // Main Theme

      // 🚀 SMART ROUTING ENGINE (The Fix)
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFF7B731))),
            );
          }

          // 🧠 SMART BOOT: Agar User logged in hai, toh uska Store Data DB se uthao
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('staff')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (ctx, guardSnap) {
                if (guardSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFF7B731))));
                }

                if (guardSnap.hasData && guardSnap.data!.exists) {
                  var data = guardSnap.data!.data() as Map<String, dynamic>;
                  // 🔒 Memory me Store lock kar diya
                  SessionManager.setGuardContext(
                    tId: data['tenantId'] ?? 'tnt_clickout',
                    sId: data['storeId'] ?? 'str_mumbai_01',
                    bCode: data['branchCode'] ?? 'MART01',
                  );
                  return const GuardDashboard();
                }

                return const LoginScreen(); // Agar DB me guard nahi mila
              },
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
