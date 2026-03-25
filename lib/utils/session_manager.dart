class SessionManager {
  static String tenantId = '';
  static String storeId = '';
  static String branchCode = '';

  static void setGuardContext({
    required String tId,
    required String sId,
    required String bCode,
  }) {
    tenantId = tId;
    storeId = sId;
    branchCode = bCode;
  }

  static void clear() {
    tenantId = '';
    storeId = '';
    branchCode = '';
  }
}
