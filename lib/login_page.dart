import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // সুপাবেস ইম্পোর্ট
import 'signup_page.dart';
import 'main_wrapper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // কন্ট্রোলারগুলো ক্লাসের ভেতরে নিয়ে আসা ভালো
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false; // লোডিং স্টেট

  // লগইন ফাংশন
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // সুপাবেস দিয়ে লগইন
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      if (response.user != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainWrapper()),
          );
        }
      }
    } on AuthException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_basket_rounded, size: 100, color: Colors.orange),
              const SizedBox(height: 20),
              const Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text("Login to continue shopping", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _emailController, 
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email", 
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                )
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController, 
                obscureText: true, 
                decoration: InputDecoration(
                  labelText: "Password", 
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                )
              ),
              const SizedBox(height: 30),
              
              // লোডিং হলে ইন্ডিকেটর দেখাবে, নাহলে বাটন
              _isLoading 
                ? const CircularProgressIndicator(color: Colors.orange)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800], 
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: _handleLogin, // লগইন ফাংশন কল
                    child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())), 
                child: const Text("New here? Create an Account", style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }
}