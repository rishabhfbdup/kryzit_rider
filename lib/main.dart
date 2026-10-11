import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'features/delivery/presentation/rider_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KryzitRiderApp());
}

class KryzitRiderApp extends StatelessWidget {
  const KryzitRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kryzit Delivery Rider Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const RiderAuthGatewayScreen(),
    );
  }
}

// -------------------------------------------------------------
// 1. RIDER AUTH GATEWAY (Password Login vs Self-Onboarding)
// -------------------------------------------------------------
class RiderAuthGatewayScreen extends StatefulWidget {
  const RiderAuthGatewayScreen({super.key});

  @override
  State<RiderAuthGatewayScreen> createState() => _RiderAuthGatewayScreenState();
}

class _RiderAuthGatewayScreenState extends State<RiderAuthGatewayScreen> {
  bool _isRegisterMode = false;

  // Single Password Controller for Direct Login
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  // New Rider Registration Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _isSubmitting = false;

  // Password-only Login Check
  Future<void> _handlePasswordLogin() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Kripya apna Rider Password enter karein!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check in Firestore riders collection
      final query = await FirebaseFirestore.instance
          .collection('riders')
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final bool isApproved = data['isApproved'] ?? false;
        final bool isSuspended = data['isSuspended'] ?? false;

        if (!isApproved) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Aapka account abhi Admin se Pending Approval hai. Approval milne ke baad login karein.';
          });
          return;
        }

        if (isSuspended) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Aapka Rider account Admin dwara Suspend kar diya gaya hai.';
          });
          return;
        }

        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => RiderDashboardScreen(
              riderId: data['riderId'] ?? query.docs.first.id,
              riderName: data['name'] ?? 'Delivery Partner',
              riderPhone: data['phone'] ?? '',
            ),
          ),
        );
      } else {
        // Fallback default password for quick testing
        if (password == '1234' || password == 'rider123') {
          setState(() => _isLoading = false);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (c) => const RiderDashboardScreen(
                riderId: 'RD-KZ-101',
                riderName: 'Kamalganj Express Rider',
                riderPhone: '9876543210',
              ),
            ),
          );
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = 'Galat Password! Kripya Admin dwara diya gaya password daalein ya register karein.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login Error: $e';
      });
    }
  }

  // Submit Rider Self-Registration
  Future<void> _handleRegisterRider() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final vehicle = _vehicleCtrl.text.trim();
    final dl = _dlCtrl.text.trim();
    final upi = _upiCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || vehicle.isEmpty || dl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya Name, Mobile, Vehicle No. aur DL Number bharein!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String tempDocId = 'rider_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('riders').doc(tempDocId).set({
        'riderId': 'PENDING',
        'name': name,
        'phone': phone,
        'vehicleNumber': vehicle,
        'dlNumber': dl,
        'upiId': upi.isEmpty ? 'N/A' : upi,
        'isApproved': false, // Admin portal pe approval aayega
        'isSuspended': false,
        'totalDeliveries': 0,
        'payoutEarned': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isSubmitting = false;
        _isRegisterMode = false;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Registration Submitted!'),
            ],
          ),
          content: Text(
            'Aapki application Admin Portal par bhej di gayi hai.\n\nAdmin aapke documents verify karke aapko Rider Password issue karenge. Us password ko daal kar aap turant Dashboard khole sakenge.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting request: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9EE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.two_wheeler_rounded, size: 28, color: Colors.black87),
                      SizedBox(width: 8),
                      Text(
                        'kryzit rider',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isRegisterMode ? 'New Rider On-boarding' : 'Delivery Partner Login',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode
                      ? 'Submit details for Admin approval & password'
                      : 'Enter your Rider Password to start receiving orders',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Toggle Bar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isRegisterMode = false;
                            _errorMessage = '';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isRegisterMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_isRegisterMode ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : [],
                            ),
                            child: Center(
                              child: Text(
                                'Password Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: !_isRegisterMode ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isRegisterMode = true;
                            _errorMessage = '';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isRegisterMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isRegisterMode ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : [],
                            ),
                            child: Center(
                              child: Text(
                                'New Rider Register',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _isRegisterMode ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // VIEW 1: SINGLE PASSWORD LOGIN
                if (!_isRegisterMode) ...[
                  if (_errorMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_rounded, color: Colors.black87),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: 'Enter Rider Password',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handlePasswordLogin,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Open Delivery Dashboard ›',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ]

                // VIEW 2: NEW RIDER ON-BOARDING FORM
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Rider Full Name*', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: const InputDecoration(labelText: 'Mobile Number*', counterText: '', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _vehicleCtrl,
                          decoration: const InputDecoration(labelText: 'Vehicle Number (e.g. UP 76 AB 1234)*', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _dlCtrl,
                          decoration: const InputDecoration(labelText: 'Driving Licence (DL) Number*', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _upiCtrl,
                          decoration: const InputDecoration(labelText: 'Payout UPI ID (PhonePe/GPay)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSubmitting ? null : _handleRegisterRider,
                            child: _isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Submit Application to Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}