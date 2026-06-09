import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';      // ভেন্ডর হোমপেজ
import 'user_home_page.dart'; // ইউজার হোমপেজ

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  String? role;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  // সুপাবেস মেটাডাটা থেকে ইউজারের রোল বের করা
  void _checkUserRole() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        // সাইনআপের সময় 'role' মেটাডাটা সেভ করা হয়েছিল
        role = user.userMetadata?['role'] ?? 'user';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // রোলের ওপর ভিত্তি করে পেজ রিটার্ন করা
    return role == 'vendor' ? const HomePage() : const UserHomePage();
  }
}