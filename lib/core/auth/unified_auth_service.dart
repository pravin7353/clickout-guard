import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnifiedAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================================
  // 📱 1. PHONE OTP ENGINE (Customers, Guards, Cashiers)
  // ==========================================================

  static Future<void> sendPhoneOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      // 🛡️ SPARK PLAN SAVER: 60-Second Cooldown Check (Local)
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getInt('last_otp_$phone') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - lastSent < 60000) {
        throw "Please wait 60 seconds before requesting another OTP.";
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        // Web ReCAPTCHA handles this automatically if setup correctly
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (mostly Android)
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Verification failed.");
        },
        codeSent: (String verificationId, int? resendToken) async {
          // Save timestamp to prevent spam
          await prefs.setInt(
              'last_otp_$phone', DateTime.now().millisecondsSinceEpoch);
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  static Future<UserCredential?> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
    required String roleCollection, // 'users', 'guards', or 'cashiers'
    required Map<String, dynamic> initialData, // Data to save if new user
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCred = await _auth.signInWithCredential(credential);

      // 🧠 AUTO-CREATION & ROLE ASSIGNMENT
      if (userCred.user != null) {
        final docRef = _db.collection(roleCollection).doc(userCred.user!.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          // 🚨 SMART SECURITY: Customers automatically active honge, par Staff 'false' rahega jab tak Admin verify na kare!
          bool isAutoActive = (roleCollection == 'users');

          // Create new user in DB
          await docRef.set({
            ...initialData,
            'uid': userCred.user!.uid,
            'phone': userCred.user!.phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': isAutoActive, // Yahan masterstroke khela hai humne!
          });
        }

        // Update session ID for anti-hijack (from Module 2)
        await docRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'activeSessionId': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      }
      return userCred;

      // 🚀 THE FIX: Asli error ko chhupane ki jagah screen par dikhao!
    } on FirebaseAuthException catch (e) {
      throw "Firebase Blocked: ${e.code}";
    } catch (e) {
      throw "System Error: $e";
    }
  }

  // ==========================================================
  // 📧 2. ADMIN MAGIC LINK (Passwordless - Ultra Secure)
  // ==========================================================

  static Future<void> sendAdminMagicLink(String email, String bundleId) async {
    try {
      // Check if email actually belongs to an admin first
      final query = await _db
          .collection('admin_users')
          .where('email', isEqualTo: email)
          .get();
      if (query.docs.isEmpty) throw "Access Denied: Unregistered Admin Email.";

      var acs = ActionCodeSettings(
        url:
            'https://clickout-admin.web.app/finishSignUp?cartId=1234', // Replace with your hosting URL
        handleCodeInApp: true,
        iOSBundleId: bundleId,
        androidPackageName: bundleId,
        androidInstallApp: false,
        androidMinimumVersion: '12',
      );

      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'emailForSignIn', email); // Save locally to verify later
    } catch (e) {
      throw e.toString();
    }
  }

  static Future<void> verifyMagicLink(String emailLink) async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('emailForSignIn');

    if (email == null) throw "Session expired. Try logging in again.";

    if (_auth.isSignInWithEmailLink(emailLink)) {
      try {
        await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
        // Clear email from storage
        await prefs.remove('emailForSignIn');
      } catch (e) {
        throw "Error signing in with link: $e";
      }
    }
  }

  // ==========================================================
  // 🚪 3. GLOBAL LOGOUT
  // ==========================================================
  static Future<void> logout(String roleCollection) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Destroy Session ID
      await _db.collection(roleCollection).doc(user.uid).update({
        'activeSessionId': FieldValue.delete(),
      }).catchError((_) {}); // Ignore if document doesn't exist
    }
    await _auth.signOut();
  }
}
