import 'package:e_commerce_app/login_page.dart';
import 'package:e_commerce_app/user_home_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://oervuqjvjpnnvaqgikgr.supabase.co',
    anonKey: 'sb_publishable_SX5rujGdK9lPWAi-NoZWsw_Kjw-yBkO',
  );
  runApp(const MegaMart());
}

class MegaMart extends StatelessWidget {
  const MegaMart({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}