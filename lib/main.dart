import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 Bouncer ko bulaya
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/guard_dashboard.dart'; // 👈 Dashboard import kiya
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 DB se data uthana hai
import 'utils/session_manager.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  if (kReleaseMode) {
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // 🛡️ App Check (Play Integrity on release, debug provider on debug)
  bool isEmulator = false;
  assert(() {
    isEmulator = true;
    return true;
  }());

  if (isEmulator) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
  } // Firebase Connect
// Crashlytics: catch all Flutter + async errors in release
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await SessionManager.init();

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

          // 🧠 SMART BOOT: Agar User logged in hai
          if (snapshot.hasData && snapshot.data != null) {
            // 🚀 FIX: ZERO LOADING TIME! Agar memory card me Store ID hai, seedha andar jao!
            if (SessionManager.storeId.isNotEmpty) {
              return const GuardDashboard();
            }

            // Fallback: Agar memory khali hai (jaise pehli baar), toh DB se uthao
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

                  bool validGuard = data['role'] == 'GUARD' &&
                      data['isActive'] == true &&
                      data['isDeleted'] != true &&
                      (data['tenantId'] ?? '').isNotEmpty &&
                      (data['branchCode'] ?? '').isNotEmpty;

                  if (!validGuard) {
                    // Kick out invalid guard post-build
                    Future.microtask(() async {
                      await FirebaseAuth.instance.signOut();
                      await SessionManager.clear();
                    });
                    return const LoginScreen();
                  }

                  SessionManager.setGuardContext(
                    tId: data['tenantId'] ?? '',
                    sId: data['storeId'] ?? '',
                    bCode: data['branchCode'] ?? '',
                    docId: guardSnap.data!.id,
                  );
                  return const GuardDashboard();
                }

                return const LoginScreen();
              },
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
