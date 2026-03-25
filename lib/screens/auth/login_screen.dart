import 'package:clickout_guard/screens/home/guard_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/auth/unified_auth_service.dart';
import '../../utils/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  // 1. 🧠 UNIFIED ENGINE: Send OTP
  Future<void> _sendOtp() async {
    String phone = "+91${_phoneController.text.trim()}";

    if (phone.length < 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid 10 digit number")),
      );
      return;
    }

    setState(() => _isLoading = true);

    await UnifiedAuthService.sendPhoneOtp(
      phone: phone,
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

  // 2. 🧠 UNIFIED ENGINE: Verify OTP
  Future<void> _verifyOtp() async {
    String otp = _otpController.text.trim();
    if (otp.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final userCred = await UnifiedAuthService.verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: otp,
        roleCollection: 'staff',
        initialData: {'role': 'GUARD'}, // Default data if auto-created
      );

      if (userCred != null && userCred.user != null) {
        await _checkIfGuard(userCred.user!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  // 3. Final Guard Check (Reverted back to check 'guards' collection)
  Future<void> _checkIfGuard(User user) async {
    String phoneWithCode = user.phoneNumber!;
    String phoneWithoutCode = user.phoneNumber!.replaceAll('+91', '');
    String enteredStore = _storeController.text.trim().toUpperCase();

    var querySnapshot = await FirebaseFirestore.instance
        .collection('staff')
        .where('isActive', isEqualTo: true)
        .where('role',
            isEqualTo: 'GUARD') // 👈 ENTERPRISE SECURITY: Sirf guard hi aayega!
        .where('phone', whereIn: [phoneWithCode, phoneWithoutCode]).get();

    if (!mounted) return;

    if (querySnapshot.docs.isNotEmpty) {
      var guardDoc = querySnapshot.docs.first;
      // 🗑️ FIX 1: 'guardData' variable hata diya kyunki uska use nahi tha

      // ⏳ Yahan ek naya await chal raha hai
      await FirebaseFirestore.instance
          .collection('staff')
          .doc(guardDoc.id)
          .set({
        'storeId': enteredStore,
        'tenantId': 'tnt_clickout',
      }, SetOptions(merge: true));

      SessionManager.setGuardContext(
        tId: 'tnt_clickout',
        sId: enteredStore,
        bCode: enteredStore,
      );

      // 🛡️ FIX 2: Naye await ke baad fir se 'mounted' check karna padta hai
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Welcome Guard! Login Successful.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green));
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const GuardDashboard()));
    } else {
      // ⏳ Yahan bhi ek await chal raha hai
      await FirebaseAuth.instance.signOut();

      // 🛡️ FIX 2: Is await ke baad bhi check lagana padega
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isOtpSent = false;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Access Denied! Active Guard registration not found."),
          backgroundColor: Colors.red));
    }
  }

  // UI REMAINS EXACTLY THE SAME (Untouched)
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
              // 🏪 1. Naya Store ID / Branch Code Field
              TextField(
                controller: _storeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Store ID / Branch Code",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.store, color: Color(0xFFF7B731)),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[800]!)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFF7B731))),
                ),
              ),
              const SizedBox(height: 20),

              // 📱 2. Purana Phone Number Field (Jo gayab ho gaya tha)
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

              // 🚀 3. GET OTP Button
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
