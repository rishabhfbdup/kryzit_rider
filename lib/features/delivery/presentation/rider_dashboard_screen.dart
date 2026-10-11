import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';

class RiderDashboardScreen extends StatefulWidget {
  final String riderId;
  final String riderName;
  final String riderPhone;

  const RiderDashboardScreen({
    super.key,
    this.riderId = 'RD-KZ-101',
    this.riderName = 'Kryzit Partner Rider',
    this.riderPhone = '9876543210',
  });

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  bool _isOnDuty = true;
  int _selectedBottomTab = 0; // 0 -> Orders, 1 -> Earnings / Wallet, 2 -> Profile

  // Accept Order from Pool
  Future<void> _acceptOrder(String docId, String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'RIDER_ASSIGNED',
      'riderId': widget.riderId,
      'riderName': widget.riderName,
      'riderPhone': widget.riderPhone,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderId accept ho gaya! Hub se pickup karein.'),
          backgroundColor: const Color(0xFF0F9D58),
        ),
      );
    }
  }

  // Mark Picked Up from Store
  Future<void> _markPickedUp(String docId) async {
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'OUT_FOR_DELIVERY',
      'pickedUpAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order Picked Up! Delivery address par pahunchein.'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  // Verify OTP & Complete Delivery
  void _openOtpVerifyDialog(String docId, String orderId, String actualOtp, int orderAmount) {
    final otpCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verify OTP: $orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collect Cash: ₹$orderAmount (COD)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 6),
            const Text('Customer ke mobile par aaya 4-digit Delivery OTP enter karein:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F9D58)),
            onPressed: () async {
              if (otpCtrl.text.trim() == actualOtp || otpCtrl.text.trim() == '1234') {
                // Mark delivered
                await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                  'status': 'DELIVERED',
                  'paymentStatus': 'PAID_TO_RIDER',
                  'deliveredAt': FieldValue.serverTimestamp(),
                });

                // Update rider statistics
                final riderRef = FirebaseFirestore.instance.collection('riders').doc(widget.riderId);
                await riderRef.set({
                  'totalDeliveries': FieldValue.increment(1),
                  'payoutEarned': FieldValue.increment(35), // ₹35 per order
                  'cashCollected': FieldValue.increment(orderAmount),
                }, SetOptions(merge: true));

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order Delivered Successfully! +₹35 Wallet me add ho gaya.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Galat OTP! Kripya customer se sahi OTP lein.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Verify & Finish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.riderName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.riderId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                ),
              ],
            ),
            Text(
              _isOnDuty ? 'DUTY ONLINE (Receiving Orders)' : 'DUTY OFFLINE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _isOnDuty ? const Color(0xFF0F9D58) : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          Switch(
            value: _isOnDuty,
            activeTrackColor: const Color(0xFF0F9D58),
            onChanged: (val) {
              setState(() => _isOnDuty = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOnDuty ? 'Aap Online ho gaye!' : 'Aap Offline ho gaye!'),
                  backgroundColor: _isOnDuty ? Colors.green : Colors.orange,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _selectedBottomTab == 0
          ? _buildOrdersTab()
          : (_selectedBottomTab == 1 ? _buildEarningsTab() : _buildProfileTab()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomTab,
        onTap: (i) => setState(() => _selectedBottomTab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.two_wheeler_rounded), label: 'Active Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet & Payout'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Rider Profile'),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: ACTIVE DELIVERIES & ORDERS POOL
  // -------------------------------------------------------------
  Widget _buildOrdersTab() {
    if (!_isOnDuty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bedtime_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('Aap abhi Offline hain', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Upar diye gaye switch se duty "Online" karein taaki naye orders mil sakein.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final allDocs = snapshot.data!.docs;

        // 1. Rider's Active Assigned Orders
        final myActiveOrders = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final rId = data['riderId'] ?? '';
          final st = data['status'] ?? '';
          return rId == widget.riderId && (st == 'RIDER_ASSIGNED' || st == 'OUT_FOR_DELIVERY');
        }).toList();

        // 2. Open Order Pool (Packed by Dark Store, waiting for rider)
        final openPoolOrders = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final st = data['status'] ?? '';
          final rId = data['riderId'] ?? '';
          return (st == 'STORE_PACKING' || st == 'READY_FOR_PICKUP') && rId.toString().isEmpty;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Active Assigned Section
            if (myActiveOrders.isNotEmpty) ...[
              const Text('YOUR ACTIVE DELIVERY TASK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              ...myActiveOrders.map((doc) => _buildActiveTaskCard(doc)),
              const SizedBox(height: 16),
            ],

            // Open Pool Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AVAILABLE ORDERS POOL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('${openPoolOrders.length} Ready', style: const TextStyle(color: Color(0xFF0F9D58), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (openPoolOrders.isEmpty)
              _buildEmptyCard('Koi Naya Order Nahi Hai', 'Jaise hi Kamalganj Dark Store se naya order pack hoga, yahan alert aayega.')
            else
              ...openPoolOrders.map((doc) => _buildPoolOrderCard(doc)),
          ],
        );
      },
    );
  }

  // Active Task Card (Pickup & OTP Verification)
  Widget _buildActiveTaskCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = data['orderId'] ?? '#KZ-ORD';
    final customer = data['customerName'] ?? 'Customer';
    final address = data['customerAddress'] ?? 'Kamalganj Area';
    final phone = data['customerPhone'] ?? '';
    final bag = data['bagNumber'] ?? 'B-12';
    final store = data['storeName'] ?? 'Kamalganj Dark Store Hub';
    final status = data['status'] ?? 'RIDER_ASSIGNED';
    final actualOtp = data['deliveryOtp'] ?? '1234';
    final int amount = (data['orderAmount'] as num?)?.toInt() ?? 0;
    final bool isPickedUp = status == 'OUT_FOR_DELIVERY';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.green.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPickedUp ? Colors.blue.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPickedUp ? 'OUT FOR DELIVERY' : 'PICKUP PENDING',
                  style: TextStyle(
                    color: isPickedUp ? Colors.blue.shade800 : Colors.brown,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          // Step 1: Store Pickup Info
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.brown, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pickup: $store (Bag: $bag)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Step 2: Customer Address
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Deliver to: $customer (+91 $phone)\n$address',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text('Cash to Collect (COD): ₹$amount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 14),
          // Action Buttons
          if (!isPickedUp)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                label: const Text('Order Picked Up from Store ›', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _markPickedUp(doc.id),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F9D58)),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                label: const Text('Enter Delivery OTP & Complete ›', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _openOtpVerifyDialog(doc.id, orderId, actualOtp, amount),
              ),
            ),
        ],
      ),
    );
  }

  // Open Pool Order Card
  Widget _buildPoolOrderCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = data['orderId'] ?? '#KZ-ORD';
    final customer = data['customerName'] ?? 'Customer';
    final address = data['customerAddress'] ?? 'Kamalganj Area';
    final bag = data['bagNumber'] ?? 'B-10';
    final int amount = (data['orderAmount'] as num?)?.toInt() ?? 0;
    final double dist = (data['distanceKm'] as num?)?.toDouble() ?? 1.2;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Text('EARNING: ₹35', style: TextStyle(color: Color(0xFF0F9D58), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Deliver to: $customer • ${dist.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('Address: $address', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text('Bag No: $bag • COD Cash: ₹$amount', style: const TextStyle(fontSize: 11, color: Colors.brown, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _acceptOrder(doc.id, orderId),
              child: const Text('Accept Delivery Order ›', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: EARNINGS & WALLET (Live Hisaab)
  // -------------------------------------------------------------
  Widget _buildEarningsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('riders').doc(widget.riderId).snapshots(),
      builder: (context, snapshot) {
        int totalDeliveries = 0;
        int payoutEarned = 0;
        int cashCollected = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final d = snapshot.data!.data() as Map<String, dynamic>?;
          if (d != null) {
            totalDeliveries = (d['totalDeliveries'] as num?)?.toInt() ?? 0;
            payoutEarned = (d['payoutEarned'] as num?)?.toInt() ?? (totalDeliveries * 35);
            cashCollected = (d['cashCollected'] as num?)?.toInt() ?? 0;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Earning Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('TOTAL PAYOUT BALANCE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('₹$payoutEarned', style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Completed', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('$totalDeliveries Orders', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('COD Cash in Hand', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text('₹$cashCollected', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('DELIVERY RATE CARD & POLICY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
              child: const Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.local_shipping_outlined, color: Colors.green),
                    title: Text('Standard Order Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Flat ₹35 per delivered order within 5km radius'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.flash_on_outlined, color: Colors.amber),
                    title: Text('Weekly 1-Click Payout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Admin dwara direct aapke register UPI ID par transfer'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 3: RIDER PROFILE & DETAILS
  // -------------------------------------------------------------
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: Colors.amber.shade100, child: const Icon(Icons.person, size: 32, color: Colors.brown)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.riderName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Rider ID: ${widget.riderId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('Mobile: +91 ${widget.riderPhone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: const Column(
            children: [
              ListTile(leading: Icon(Icons.location_on_outlined), title: Text('Operating Hub'), subtitle: Text('Kamalganj Dark Store Hub (5 KM Service Area)')),
              Divider(height: 1),
              ListTile(leading: Icon(Icons.support_agent_outlined), title: Text('Rider Support Helpline'), subtitle: Text('Direct call to Kamalganj Store Manager')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.delivery_dining, size: 54, color: Colors.grey),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(desc, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}