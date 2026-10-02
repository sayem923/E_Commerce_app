import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'main_wrapper.dart';

/// এই widget-টি app চালু হওয়ার সময় এবং লগইন/লগআউট হওয়ার সময়
/// Supabase auth state শুনে (listen করে) স্বয়ংক্রিয়ভাবে সঠিক পেজে পাঠায়।
///
/// - session না থাকলে -> LoginPage
/// - session থাকলে -> MainWrapper (যেটা role অনুযায়ী vendor/user হোমপেজ ঠিক করে)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // প্রথমবার session আছে কিনা সেটা initialData হিসেবে দিয়ে দিচ্ছি,
      // যাতে স্ট্রিমের প্রথম ইভেন্টের জন্য অপেক্ষা করতে গিয়ে flicker না হয়।
      initialData: AuthState(
        Supabase.instance.client.auth.currentSession != null
            ? AuthChangeEvent.initialSession
            : AuthChangeEvent.signedOut,
        Supabase.instance.client.auth.currentSession,
      ),
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // স্ট্রিম কানেক্ট হওয়ার আগ পর্যন্ত ছোট্ট লোডিং দেখাবে
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }

        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return const MainWrapper();
        }
        return const LoginPage();
      },
    );
  }
}
