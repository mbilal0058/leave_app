import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:leave_app/pages/splashPage.dart';
import 'package:leave_app/pages/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leave Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(),
    );
  }
}
