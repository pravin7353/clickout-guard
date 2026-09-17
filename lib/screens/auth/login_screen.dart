import 'package:clickout_guard/screens/home/guard_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/auth/unified_auth_service.dart';
import '../../utils/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  // 1. Send OTP (phone-only, no branch code required)
  Future<void> _sendOtp() async {
    String rawNumber = _phoneController.text.trim();
    String finalPhone = "+91$rawNumber";

    if (rawNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid 10 digit number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 🚀 Staff validation is now handled server-side in sendMsg91Otp
    // (admin SDK bypasses Firestore rules — fixes permission-denied)

    await UnifiedAuthService.sendPhoneOtp(
      phone: finalPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("OTP Sent! Check SMS."),
              backgroundColor: Colors.green),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      },
    );
  }

  // 2. Verify OTP and resolve session via Cloud Function
  Future<void> _verifyOtp() async {
    String otp = _otpController.text.trim();
    if (otp.length != 6) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Firebase Phone Auth
      final userCred = await UnifiedAuthService.verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: otp,
        roleCollection: 'staff',
        initialData: {'role': 'GUARD'},
      );

      if (userCred == null || userCred.user == null) {
        throw "Authentication failed. Please try again.";
      }

      // Step 2: Force-refresh token so Cloud Function sees verified phone claim
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      // Step 3: Resolve tenantId/storeId/branchCode via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable(
        'resolveStaffSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call({'role': 'guard'});
      final sessionData = Map<String, dynamic>.from(result.data as Map);

      if (!mounted) return;

      final tenantId = (sessionData['tenantId'] ?? '').toString();
      final storeId = (sessionData['storeId'] ?? '').toString();
      final branchCode = (sessionData['branchCode'] ?? '').toString();
      final name = (sessionData['name'] ?? 'Guard').toString();
      final docId = (sessionData['docId'] ?? '').toString();

      if (tenantId.isEmpty || storeId.isEmpty) {
        await FirebaseAuth.instance.signOut();
        throw "⚠️ Staff profile incomplete (missing tenantId/storeId). Contact your admin.";
      }

      // Step 4: Update display name and persist session
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      await SessionManager.setGuardContext(
        tId: tenantId,
        sId: storeId,
        bCode: branchCode,
        docId: docId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Welcome Guard! Login Successful.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green));
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const GuardDashboard()));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      final errStr = e.toString().toLowerCase();
      final isNotFound = (e is FirebaseFunctionsException && e.code == 'not-found') ||
          errStr.contains('not-found') ||
          errStr.contains('no active staff record');

      if (isNotFound) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Access Denied"),
            content: const Text(
              "This number is not registered as a guard. Contact your admin.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isOtpSent = false;
                    _otpController.clear();
                  });
                },
                child: const Text("Re-enter Number"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guard Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Color(0xFFF7B731)),
            const SizedBox(height: 20),
            const Text(
              "CLICKOUT GUARD",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            if (!_isOtpSent) ...[
              // 📱 Phone Number Field (branch code removed — auto-resolved)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Mobile Number",
                  prefixText: "+91 ",
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 20),

              // 🚀 GET OTP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("GET OTP"),
                ),
              ),
            ] else ...[
              const Text("Enter OTP sent to your phone"),
              const SizedBox(height: 20),
              Pinput(
                length: 6,
                controller: _otpController,
                defaultPinTheme: PinTheme(
                  width: 50,
                  height: 50,
                  textStyle: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF7B731)),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("VERIFY & LOGIN"),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isOtpSent = false),
                child: const Text("Change Number",
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
