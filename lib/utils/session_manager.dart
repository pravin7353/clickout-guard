import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static String tenantId = '';
  static String storeId = '';
  static String branchCode = '';
  static String guardDocId = '';

  // 🚀 FIX 1: App khulte hi ye RAM me data bharega
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    tenantId = prefs.getString('guard_tenantId') ?? '';
    storeId = prefs.getString('guard_storeId') ?? '';
    branchCode = prefs.getString('guard_branchCode') ?? '';
    guardDocId = prefs.getString('guard_docId') ?? '';
  }

  // 🚀 FIX 2: Data ko hamesha ke liye Memory Card me lock karo
  static Future<void> setGuardContext({
    required String tId,
    required String sId,
    required String bCode,
    required String docId,
  }) async {
    tenantId = tId;
    storeId = sId;
    branchCode = bCode;
    guardDocId = docId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guard_tenantId', tId);
    await prefs.setString('guard_storeId', sId);
    await prefs.setString('guard_branchCode', bCode);
    await prefs.setString('guard_docId', docId);
  }

  // 🧹 FIX 3: Logout hone par memory saaf!
  static Future<void> clear() async {
    tenantId = '';
    storeId = '';
    branchCode = '';
    guardDocId = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guard_tenantId');
    await prefs.remove('guard_storeId');
    await prefs.remove('guard_branchCode');
    await prefs.remove('guard_docId');
  }
}
