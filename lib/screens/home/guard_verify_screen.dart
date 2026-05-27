import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/session_manager.dart';

class GuardVerifyScreen extends StatefulWidget {
  final String orderId;
  const GuardVerifyScreen({super.key, required this.orderId});

  @override
  State<GuardVerifyScreen> createState() => _GuardVerifyScreenState();
}

class _GuardVerifyScreenState extends State<GuardVerifyScreen> {
  // 🚀 FETCH GLOBAL NAME FOR DATABASE
  final String guardName = FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.phoneNumber ??
      "Unknown Guard";
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool isProcessing = false;
  bool _auditVerified = false; // 🚀 NAYA: AI Spot Audit Lock

  final Map<String, int> _rejectReasons = {
    "Select Reason...": 0,
    "Not Match (Bina scan kiya item)": 15,
    "Mistake (jo item galti se miss hogaya)": 25,
    "Wrong item scanned (Galat barcode)": 10,
    "Customer refused checking": 20,
    "Other": 10
  };

  // 🧠 TRUST SCORE LOGIC
  Future<void> _updateTrustScore(String userId, double delta,
      {required bool isReward}) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        double currentScore = 80.0;
        if (snapshot.exists && snapshot.data()?['trustScore'] != null) {
          currentScore = (snapshot.data()?['trustScore'] as num).toDouble();
        }

        double newScore = currentScore;
        if (isReward) {
          double appliedReward = delta;
          if (currentScore < 40) {
            appliedReward = 0.25;
          } else if (currentScore < 60) {
            appliedReward = 0.5;
          } else if (currentScore < 80) appliedReward = 1.0;

          newScore = currentScore + appliedReward;
          if (newScore > 100) newScore = 100.0;
        } else {
          newScore = currentScore - delta;
          if (newScore < 0) newScore = 0.0;
        }

        transaction.set(
            userRef,
            {
              'trustScore': double.parse(newScore.toStringAsFixed(2)),
              'lastActivityAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Guard App - Trust Score Engine Error: $e");
    }
  }

  // 🟢 APPROVE ACTION (ATOMIC LOCK APPLIED)
  Future<void> _approveExit() async {
    setState(() => isProcessing = true);
    try {
      String userId = "";

      await _db.runTransaction((transaction) async {
        DocumentReference orderRef =
            _db.collection('orders').doc(widget.orderId);
        DocumentSnapshot doc = await transaction.get(orderRef);

        if (!doc.exists) throw "Order not found!";

        var data = doc.data() as Map<String, dynamic>;
        userId = data['userId'] ?? '';

        bool isValidStore = (data['branchCode'] == SessionManager.branchCode) &&
            (data['tenantId'] == SessionManager.tenantId);
        if (!isValidStore) {
          throw "SECURITY ALERT: This bill belongs to a different store!";
        }

        // 🚨 RACE CONDITION BLOCKER
        if (data['qrConsumed'] == true) {
          throw "ALREADY SCANNED! Stop the customer immediately!";
        }
        if (data['paymentStatus'] != 'PAID' && data['status'] != 'completed') {
          throw "Payment is Pending!";
        }
        // Replay protection inside transaction
        if (data['qrExpiresAt'] != null) {
          DateTime exp = (data['qrExpiresAt'] as Timestamp).toDate();
          if (DateTime.now().isAfter(exp)) {
            throw "QR EXPIRED! Cannot approve expired gate pass.";
          }
        }

        transaction.update(orderRef, {
          'exitStatus': 'APPROVED',
          'qrConsumed': true,
          'verifiedByGuardId': guardName, // 🚀 Name save hoga ab se!
          'verifiedAt': FieldValue.serverTimestamp(),
          'spotAuditDone':
              _auditVerified, // 🚀 Log that audit was forced & done
        });
      });

      if (userId.isNotEmpty) {
        await _updateTrustScore(userId, 2.0, isReward: true);
      }
      _showSuccessAndPop();
    } catch (e) {
      _showError(e.toString());
      setState(() => isProcessing = false);
    }
  }

  // 🔴 REJECT ACTION (ATOMIC LOCK APPLIED)
  Future<void> _rejectExit(String reason, String? extraNote) async {
    setState(() => isProcessing = true);
    try {
      String finalReason = reason == "Other" ? (extraNote ?? "Other") : reason;
      int penaltyDelta = _rejectReasons[reason] ?? 10;
      String userId = "";

      await _db.runTransaction((transaction) async {
        DocumentReference orderRef =
            _db.collection('orders').doc(widget.orderId);
        DocumentSnapshot doc = await transaction.get(orderRef);

        if (!doc.exists) throw "Order missing";

        var data = doc.data() as Map<String, dynamic>;
        userId = data['userId'] ?? '';

        bool isValidStore = (data['branchCode'] == SessionManager.branchCode) &&
            (data['tenantId'] == SessionManager.tenantId);
        if (!isValidStore) {
          throw "SECURITY ALERT: This bill belongs to a different store!";
        }

        if (data['qrConsumed'] == true) {
          throw "ALREADY SCANNED! Cannot reject a consumed gate pass.";
        }
        if (data['exitStatus'] == 'REJECTED') {
          throw "Already Rejected! Wait for sync.";
        }

        transaction.update(orderRef, {
          'exitStatus': 'REJECTED',
          'rejectReason': finalReason,
          'rejectedByGuardId': guardName, // 🚀 Name save hoga ab se!
          'rejectedAt': FieldValue.serverTimestamp(),
          'wasEverRejected': true,
        });
      });

      if (userId.isNotEmpty) {
        await _updateTrustScore(userId, penaltyDelta.toDouble(),
            isReward: false);
      }

      if (mounted) Navigator.pop(context);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
      setState(() => isProcessing = false);
    }
  }

  void _showRejectSheet() {
    String selectedReason = "Select Reason...";
    TextEditingController otherController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isButtonActive = selectedReason != "Select Reason...";

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Reject Reason 🚨",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30, width: 2)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.grey[900],
                        isExpanded: true,
                        value: selectedReason,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.white, size: 30),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        items: _rejectReasons.keys.map((String reason) {
                          return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason,
                                  style: TextStyle(
                                      color: reason == "Select Reason..."
                                          ? Colors.grey
                                          : Colors.white)));
                        }).toList(),
                        onChanged: (String? newValue) {
                          setModalState(() {
                            selectedReason = newValue!;
                          });
                        },
                      ),
                    ),
                  ),
                  if (selectedReason == "Other") ...[
                    const SizedBox(height: 15),
                    TextField(
                        controller: otherController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                            hintText: "Type exact reason...",
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.black,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)))),
                  ],
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: isButtonActive
                              ? Colors.redAccent
                              : Colors.grey[800],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: isButtonActive
                          ? () =>
                              _rejectExit(selectedReason, otherController.text)
                          : null,
                      child: Text("CONFIRM REJECT",
                          style: TextStyle(
                              fontSize: 18,
                              color: isButtonActive
                                  ? Colors.white
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessAndPop() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Exit Approved Successfully!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2)));
    Navigator.pop(context);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Verify Bag Contents",
              style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context))),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text("Connection Error",
                    style: TextStyle(color: Colors.red, fontSize: 20)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text("❌ INVALID QR! Order not found.",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;

          // 🛡️ THE SAAS ISOLATION UI BLOCKER (ULTIMATE FAILSAFE)
          String oBranch = (data['branchCode'] ?? '').toString().trim();
          String oStore = (data['storeId'] ?? '').toString().trim();
          String gBranch = SessionManager.branchCode.trim();
          String gStore = SessionManager.storeId.trim();

          String oTenant = (data['tenantId'] ?? '').toString().trim();
          String gTenant = SessionManager.tenantId.trim();

          bool isMatch = (oBranch.isNotEmpty && oBranch == gBranch) &&
              (oTenant.isNotEmpty && oTenant == gTenant);

          if (!isMatch) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "❌ CROSS-STORE ALERT!\n\nOrder Store: [$oStore]\nOrder Branch: [$oBranch]\n\nGuard Store: [$gStore]\nGuard Branch: [$gBranch]\n\nExact values aapke samne hain. Agar alag hain toh Guard app ko logout karke login karo.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900),
                ),
              ),
            );
          }

          bool isConsumed = data['qrConsumed'] ?? false;
          String exitStatus = data['exitStatus'] ?? 'PENDING';
          bool isPaid =
              data['paymentStatus'] == 'PAID' || data['status'] == 'completed';

          bool isExpired = false;
          if (data['qrExpiresAt'] != null) {
            DateTime expiresAt = (data['qrExpiresAt'] as Timestamp).toDate();
            if (DateTime.now().isAfter(expiresAt)) isExpired = true;
          }

          List<dynamic> items = data['items'] ?? [];
          double totalAmount =
              double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
          double totalWeight =
              double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;

          String weightDisplay = totalWeight >= 1000
              ? "${(totalWeight / 1000).toStringAsFixed(2)} KG"
              : "${totalWeight.toStringAsFixed(0)} g";

          String dateStr = "Unknown Date";
          if (data['timestamp'] != null) {
            DateTime dt = (data['timestamp'] as Timestamp).toDate();
            dateStr = DateFormat('dd MMM, hh:mm a').format(dt);
          }

          // 🚀 THE AI SPOT AUDIT LOGIC
          bool requiresAudit = totalAmount >= 1000 || items.length >= 5;
          List<dynamic> auditItems = [];
          if (requiresAudit && items.isNotEmpty) {
            // Sort items by price to ask guard to check the most expensive items
            var sortedItems = List.from(items);
            sortedItems.sort((a, b) {
              double pA = double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
              double pB = double.tryParse(b['price']?.toString() ?? '0') ?? 0.0;
              return pB.compareTo(pA);
            });
            auditItems = sortedItems.take(2).toList();
          }

          // Approve Lock Logic
          bool canApprove = !requiresAudit || _auditVerified;

          return Column(
            children: [
              if (isConsumed)
                _buildAlertBanner("🚨 ALREADY USED",
                    "This Gate Pass has already been exited.", Colors.red),
              if (isExpired && !isConsumed)
                _buildAlertBanner("⏰ EXPIRED",
                    "This Gate Pass time limit exceeded.", Colors.red),
              if (!isPaid)
                _buildAlertBanner("⚠️ UNPAID",
                    "Customer has not completed payment yet.", Colors.orange),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24)),
                        child: Column(
                          children: [
                            _buildRow("Order ID",
                                "#${widget.orderId.substring(0, 8).toUpperCase()}"),
                            const Divider(color: Colors.white24, height: 25),
                            _buildRow("Date & Time", dateStr),
                            const Divider(color: Colors.white24, height: 25),
                            _buildRow("Status", isPaid ? "PAID" : "PENDING",
                                valueColor: isPaid
                                    ? Colors.greenAccent
                                    : Colors.orange),
                            const Divider(color: Colors.white24, height: 25),
                            _buildRow("Total Weight", weightDisplay,
                                valueColor: Colors.cyanAccent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🚀 THE SPOT AUDIT UI CARD
                      if (requiresAudit &&
                          !_auditVerified &&
                          !isConsumed &&
                          isPaid &&
                          exitStatus != 'REJECTED')
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade900.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.amber.withOpacity(0.1),
                                  blurRadius: 15)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.security_update_warning,
                                      color: Colors.amber, size: 30),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "RANDOM SPOT AUDIT",
                                      style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "High-value cart detected. Please physically verify the following expensive items in the bag:",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 15),
                              ...auditItems.map((item) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.check_box_outline_blank,
                                            color: Colors.amberAccent,
                                            size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "${item['qty'] ?? item['quantity'] ?? 1}x  ${item['name']}",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.verified, size: 24),
                                  label: const Text(
                                      "I HAVE VERIFIED THESE ITEMS",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900)),
                                  onPressed: () {
                                    setState(() {
                                      _auditVerified = true;
                                    });
                                  },
                                ),
                              )
                            ],
                          ),
                        ),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.5),
                                width: 2)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("BAG CONTENTS",
                                    style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 1.5)),
                                Text("${items.length} Items",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(
                                color: Colors.white24,
                                height: 25,
                                thickness: 2),
                            ...items.map((item) {
                              int qty = int.tryParse(
                                      item['qty']?.toString() ?? '') ??
                                  int.tryParse(
                                      item['quantity']?.toString() ?? '1') ??
                                  1;
                              double price = double.tryParse(
                                      item['price']?.toString() ?? '') ??
                                  double.tryParse(
                                      item['discountedPrice']?.toString() ??
                                          '') ??
                                  double.tryParse(
                                      item['originalPrice']?.toString() ??
                                          '0') ??
                                  0.0;
                              double itemTotal = qty * price;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                        width: 45,
                                        height: 45,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade900,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text("${qty}x",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900))),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item['name'] ?? "Unknown Item",
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text(
                                              "₹${price.toStringAsFixed(0)} /item",
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    Text("₹${itemTotal.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(
                                color: Colors.white24,
                                height: 30,
                                thickness: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("GRAND TOTAL",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900)),
                                Text("₹${totalAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900)),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              if (!isConsumed &&
                  isPaid &&
                  !isExpired &&
                  exitStatus != 'REJECTED')
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black,
                  child: isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : Row(
                          children: [
                            Expanded(
                                flex: 1,
                                child: SizedBox(
                                    height: 70,
                                    child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12))),
                                        onPressed: _showRejectSheet,
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 40)))),
                            const SizedBox(width: 15),
                            Expanded(
                                flex: 2,
                                child: SizedBox(
                                    height: 70,
                                    child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: canApprove
                                                ? Colors.green
                                                : Colors.grey
                                                    .shade800, // 🚀 DYNAMIC COLOR
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12))),
                                        onPressed: canApprove
                                            ? _approveExit
                                            : () {
                                                _showError(
                                                    "⚠️ Please complete the Spot Audit above first!");
                                              }, // 🚀 DYNAMIC LOCK
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (!canApprove)
                                              const Icon(Icons.lock,
                                                  color: Colors.white54,
                                                  size: 24),
                                            if (!canApprove)
                                              const SizedBox(width: 8),
                                            Text(
                                                canApprove
                                                    ? "APPROVE EXIT"
                                                    : "LOCKED",
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    color: canApprove
                                                        ? Colors.white
                                                        : Colors.white54,
                                                    letterSpacing: 1.0)),
                                          ],
                                        )))),
                          ],
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {Color valueColor = Colors.white}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: const TextStyle(
              color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
      Text(value,
          style: TextStyle(
              color: valueColor, fontWeight: FontWeight.w900, fontSize: 18))
    ]);
  }

  Widget _buildAlertBanner(String title, String subtitle, Color color) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: color,
        child: Column(children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold))
        ]));
  }
}
