import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_wrapper.dart'; // আপনার মেইন অ্যাপ র‍্যাপার যেখানে হোম পেজে যায়

// --- ১. সাইনআপ পেজ (যেখানে ইউজার তথ্য দিবে) ---
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  String _role = 'user';
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    if (_name.text.isEmpty || _email.text.isEmpty || _pass.text.isEmpty) {
      _showSnackBar("All fields are required!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Supabase-এ সাইনআপ রিকোয়েস্ট (এটি ইমেইলে ৮ ডিজিটের OTP পাঠাবে)
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        data: {
          'full_name': _name.text.trim(),
          'role': _role,
        },
      );

      if (mounted) {
        // ওটিপি ভেরিফিকেশন পেজে নিয়ে যাওয়া হচ্ছে
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerifyPage(email: _email.text.trim()),
          ),
        );
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.teal),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Text("Create Account", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 40),
            
            _buildTextField(_name, "Full Name", Icons.person_outline),
            const SizedBox(height: 15),
            _buildTextField(_email, "Email", Icons.email_outlined),
            const SizedBox(height: 15),
            _buildTextField(_pass, "Password", Icons.lock_outline, obscure: true),
            
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(value: 'user', groupValue: _role, onChanged: (v) => setState(() => _role = v!)), 
                const Text("User"),
                const SizedBox(width: 20),
                Radio<String>(value: 'vendor', groupValue: _role, onChanged: (v) => setState(() => _role = v!)), 
                const Text("Vendor"),
              ],
            ),
            
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator(color: Colors.teal)
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, 
                    minimumSize: const Size(double.infinity, 55), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _handleSignup,
                  child: const Text("Send 8-Digit OTP", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
      ),
    );
  }
}

// --- ২. ওটিপি ভেরিফিকেশন পেজ (৮ ডিজিটের জন্য আপডেট করা) ---
class OTPVerifyPage extends StatefulWidget {
  final String email;
  const OTPVerifyPage({super.key, required this.email});

  @override
  State<OTPVerifyPage> createState() => _OTPVerifyPageState();
}

class _OTPVerifyPageState extends State<OTPVerifyPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOTP() async {
    // এখানে ৮ ডিজিট চেক করা হচ্ছে
    if (_otpController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter the 8-digit OTP code")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Supabase-এর verifyOTP মেথড
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.signup,
      );

      if (response.user != null && mounted) {
        // ভেরিফিকেশন সফল হলে মেইন অ্যাপে পাঠিয়ে দিবে
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid OTP: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Email Verification"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            Text(
              "Check your email! We've sent an 8-digit OTP to\n${widget.email}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            // ৮ ডিজিট ইনপুট ফিল্ড ডিজাইন
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
              maxLength: 8, // ৮ ডিজিট লিমিট
              decoration: InputDecoration(
                hintText: "00000000",
                counterText: "",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.teal)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _verifyOTP,
                    child: const Text("Verify & Continue", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Wrong email? Go back", style: TextStyle(color: Colors.teal)),
            )
          ],
        ),
      ),
    );
  }
}