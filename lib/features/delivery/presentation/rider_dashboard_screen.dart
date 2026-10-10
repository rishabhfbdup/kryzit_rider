import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  bool isOnDuty = true;
  int todayEarnings = 412;
  int completedDeliveries = 11;

  final String _riderName = 'Rider Partner';
  final String _riderPhone = '9876543210';
  final double _currentLat = 27.2731;
  final double _currentLng = 79.6642;

  Timer? _deliveryTimer;
  int _deliverySecondsLeft = 12 * 60;
  bool _deliveryTimerRunning = false;

  Timer? _acceptTimer;
  int _acceptSecondsLeft = 40;
  String? _currentPendingOrderId;

  @override
  void dispose() {
    _deliveryTimer?.cancel();
    _acceptTimer?.cancel();
    super.dispose();
  }

  void _startAcceptTimer(String docId, String orderId) {
    _acceptTimer?.cancel();
    _currentPendingOrderId = orderId;
    _acceptSecondsLeft = 40;

    _acceptTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_acceptSecondsLeft > 0) {
        if (mounted) {
          setState(() {
            _acceptSecondsLeft--;
          });
        }
      } else {
        timer.cancel();
        _rejectOrder(docId, reason: 'TIME_OUT');
      }
    });
  }

  Future<void> _rejectOrder(String docId, {required String reason}) async {
    _acceptTimer?.cancel();
    _currentPendingOrderId = null;

    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'REJECTED_BY_RIDER',
      'lastRejectedReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(
            reason == 'TIME_OUT'
                ? '⏳ 40s Time Up! Order transfer ho gaya.'
                : '❌ Order reject ho gaya.',
          ),
        ),
      );
    }
  }

  void _startDeliveryTimer() {
    setState(() {
      _deliveryTimerRunning = true;
    });
    _deliveryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_deliverySecondsLeft > 0) {
        if (mounted) {
          setState(() {
            _deliverySecondsLeft--;
          });
        }
      } else {
        _deliveryTimer?.cancel();
        if (mounted) {
          setState(() {
            _deliveryTimerRunning = false;
          });
        }
      }
    });
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, int> _getPayoutSlab(double distanceKm) {
    if (distanceKm <= 1.0) return {'fast': 12, 'late': 10};
    if (distanceKm <= 2.0) return {'fast': 22, 'late': 18};
    if (distanceKm <= 3.0) return {'fast': 30, 'late': 27};
    if (distanceKm <= 4.0) return {'fast': 38, 'late': 35};
    return {'fast': 48, 'late': 45};
  }

  Future<void> _openGoogleMaps(String address) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showOtpDialog(
    BuildContext context,
    String docId,
    String correctOtp,
    int earned,
  ) {
    final TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF0F9D58)),
            SizedBox(width: 8),
            Text('Customer Delivery OTP', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Customer se 4-digit verification OTP lekar enter karein:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(
                fontSize: 26,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F9D58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (otpController.text.trim() == correctOtp.trim()) {
                Navigator.pop(ctx);
                _deliveryTimer?.cancel();
                setState(() {
                  todayEarnings += earned;
                  completedDeliveries++;
                  _deliveryTimerRunning = false;
                  _deliverySecondsLeft = 12 * 60;
                });

                await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                  'status': 'DELIVERED',
                  'deliveredAt': FieldValue.serverTimestamp(),
                  'riderPayout': earned,
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF2E7D32),
                      content: Text('Delivery Successful! +₹$earned added.'),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Galat OTP! Customer se check karke daalein.'),
                  ),
                );
              }
            },
            child: const Text('Verify & Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.two_wheeler, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Kryzit Rider Partner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          Switch(
            value: isOnDuty,
            activeTrackColor: const Color(0xFF0F9D58),
            onChanged: (val) {
              setState(() {
                isOnDuty = val;
              });
            },
          ),
          const SizedBox(width: 12),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOnDuty ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isOnDuty ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 5,
                        backgroundColor: isOnDuty ? const Color(0xFF2E7D32) : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnDuty ? 'ON DUTY (Active)' : 'OFF DUTY (Paused)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isOnDuty ? const Color(0xFF2E7D32) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isOnDuty ? '⚡ Live Dispatch Listening' : '💤 Offline',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today Rider Earnings', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('₹$todayEarnings', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$completedDeliveries Completed Deliveries', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.electric_moped, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Active Task & Delivery Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (!isOnDuty)
              _buildEmptyCard('Rider is Offline', 'Naye orders receive karne ke liye On-Duty switch ON karein.')
            else
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('status', whereIn: [
                      'STORE_PACKING',
                      'RIDER_ASSIGNED',
                      'RIDER_ARRIVED',
                      'STORE_PACKED',
                      'PICKED_UP'
                    ])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    _acceptTimer?.cancel();
                    _currentPendingOrderId = null;
                    return _buildEmptyCard(
                      'No Active Deliveries',
                      'Customer aur Store Partner se naya order aate hi yahan live flash hoga.',
                    );
                  }

                  final orderDoc = snapshot.data!.docs.first;
                  final data = orderDoc.data() as Map<String, dynamic>;

                  final String docId = orderDoc.id;
                  final String orderId = data['orderId'] ?? '#KZ-ORDER';
                  final double distanceKm = ((data['distanceKm'] ?? 2.0) as num).toDouble();
                  final String status = data['status'] ?? 'STORE_PACKING';
                  final String storeName = data['storeName'] ?? 'Kamalganj Dark Store Hub';
                  final String bagNumber = data['bagNumber'] ?? 'B-01';
                  final String customerName = data['customerName'] ?? 'Customer';
                  final String customerAddress = data['customerAddress'] ?? 'Kamalganj';
                  final String correctOtp = (data['deliveryOtp'] ?? '1234').toString();

                  final slabs = _getPayoutSlab(distanceKm);
                  final int fastPay = slabs['fast']!;
                  final int latePay = slabs['late']!;

                  if (status == 'STORE_PACKING') {
                    if (_currentPendingOrderId != orderId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _startAcceptTimer(docId, orderId);
                      });
                    }
                  } else {
                    _acceptTimer?.cancel();
                  }

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (status == 'STORE_PACKING') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.timer, color: Colors.deepOrange),
                                      const SizedBox(width: 8),
                                      Text(
                                        'New Request: $_acceptSecondsLeft s left',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Text('Auto-pass if timeout', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Order $orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('Drop Distance: $distanceKm km', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹$fastPay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F9D58))),
                                  const Text('Payout Earn', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Target: 12 Mins delivery', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('• Ontime Payout: ₹$fastPay', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _deliveryTimerRunning
                                          ? _formatTime(_deliverySecondsLeft)
                                          : (status == 'PICKED_UP' ? 'Running' : '12:00'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _deliverySecondsLeft < 180 ? Colors.red : Colors.black87,
                                      ),
                                    ),
                                    Text('* Late: ₹$latePay', style: const TextStyle(fontSize: 10, color: Colors.deepOrange)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              const Icon(Icons.radio_button_checked, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Pickup: Dark Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('$storeName • Bag: $bagNumber', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Customer Drop Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('$customerName • $customerAddress', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.navigation, color: Colors.blueAccent),
                                tooltip: 'Open Google Maps',
                                onPressed: () => _openGoogleMaps(customerAddress),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (status == 'STORE_PACKING')
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _rejectOrder(docId, reason: 'RIDER_REJECTED'),
                                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F9D58),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () async {
                                      _acceptTimer?.cancel();
                                      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                                        'status': 'RIDER_ASSIGNED',
                                        'riderName': _riderName,
                                        'riderPhone': _riderPhone,
                                        'riderLat': _currentLat,
                                        'riderLng': _currentLng,
                                        'riderAssignedAt': FieldValue.serverTimestamp(),
                                      });
                                    },
                                    child: Text(
                                      'Accept Delivery (${_acceptSecondsLeft}s)',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (status == 'RIDER_ASSIGNED')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.store, color: Colors.white),
                                label: const Text('Reached Dark Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                                    'status': 'RIDER_ARRIVED',
                                    'riderArrivedAt': FieldValue.serverTimestamp(),
                                  });
                                },
                              ),
                            )
                          else if (status == 'RIDER_ARRIVED')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: const Center(
                                child: Text(
                                  '⏳ At Store: Waiting for Partner Handover...',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                ),
                              ),
                            )
                          else if (status == 'STORE_PACKED')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B7A38),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.moped, color: Colors.white),
                                label: const Text('Confirm Handover & Start Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  _startDeliveryTimer();
                                  await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                                    'status': 'PICKED_UP',
                                    'pickedUpAt': FieldValue.serverTimestamp(),
                                  });
                                },
                              ),
                            )
                          else if (status == 'PICKED_UP')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F9D58),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.verified_user, color: Colors.white),
                                label: Text(
                                  'Delivered (OTP Verify: ₹${_deliverySecondsLeft > 0 ? fastPay : latePay})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  int earned = _deliverySecondsLeft > 0 ? fastPay : latePay;
                                  _showOtpDialog(context, docId, correctOtp, earned);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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