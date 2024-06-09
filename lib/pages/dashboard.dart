import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:leave_app/pages/profile.dart';
import 'ManagerDashboard.dart';
import 'ToAdminDashboard.dart';
import 'UserDashboard.dart';
import 'leaveApply.dart';
import 'login.dart';

class DashboardScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.data()?['role'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (snapshot.hasData) {
          String? role = snapshot.data as String?;
          if (role == 'User') {
            return UserDashboard();
          } else if (role == 'Manager') {
            return ManagerDashboard();
          } else if (role == 'Toadmin') {
            return ToAdminDashboard();
          } else {
            return Scaffold(body: Center(child: Text('Unknown role')));
          }
        }
        return Scaffold(body: Center(child: Text('No role found')));
      },
    );
  }
}
