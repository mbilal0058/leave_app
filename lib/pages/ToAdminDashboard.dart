import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile.dart';
import 'AddHoliday.dart';
import 'AnnouncementScreen.dart';
import 'LeaveTypesScreen.dart';
import 'UsersListScreen.dart';
import 'leaveApply.dart';
import 'login.dart';

class ToAdminDashboard extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()), // Ensure you have a named route for login
    );
  }

  Future<Map<String, String?>> _getUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return {
        'firstName': doc.data()?['firstName'],
        'lastName': doc.data()?['lastName'],
        'email': doc.data()?['email'],
        'profileImage': doc.data()?['profileImage'],
      };
    }
    return {
      'firstName': 'Guest',
      'lastName': '',
      'email': '',
      'profileImage': null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<Map<String, String?>>(
          future: _getUserDetails(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingDrawer(context);
            } else if (snapshot.hasError) {
              return _buildErrorDrawer(context);
            } else if (snapshot.hasData) {
              var userDetails = snapshot.data!;
              return _buildUserDrawer(userDetails, context);
            } else {
              return _buildNoUserDataDrawer(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildGradientListTile(
              context,
              'Announcement',
              Icons.announcement,
              [Colors.blue, Colors.lightBlueAccent],
              AnnouncementScreen(),
            ),
            _buildGradientListTile(
              context,
              'Leave Types',
              Icons.list,
              [Colors.green, Colors.lightGreenAccent],
              LeaveTypesScreen(),
            ),
            _buildGradientListTile(
              context,
              'Leave Balance',
              Icons.balance,
              [Colors.orange, Colors.yellow],
              LeaveBalanceScreen(),
            ),
            _buildGradientListTile(
              context,
              'Users List',
              Icons.people,
              [Colors.purple, Colors.pinkAccent],
              UsersListScreen(),
            ),
            _buildGradientListTile(
              context,
              'Add Holiday',
              Icons.supervisor_account,
              [Colors.red, Colors.deepOrangeAccent],
              AddHolidays(),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _buildDrawerItems(BuildContext context, String title, IconData icon, Widget? page, [Function? onTap]) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) {
          onTap();
        } else if (page != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        }
      },
    );
  }

  ListView _buildLoadingDrawer(BuildContext context) {
    return ListView(
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('Loading...'),
          accountEmail: Text('Loading...'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text('A'),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, ToAdminDashboard()),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, () => _logout(context)),
      ],
    );
  }

  ListView _buildErrorDrawer(BuildContext context) {
    return ListView(
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('Error'),
          accountEmail: Text('Error'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text('A'),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, ToAdminDashboard()),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, () => _logout(context)),
      ],
    );
  }

  ListView _buildNoUserDataDrawer(BuildContext context) {
    return ListView(
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('No User Data'),
          accountEmail: Text('No User Data'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text('A'),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, ToAdminDashboard()),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, () => _logout(context)),
      ],
    );
  }

  ListView _buildUserDrawer(Map<String, String?> userDetails, BuildContext context) {
    String initials = '';
    if (userDetails['firstName'] != null && userDetails['lastName'] != null) {
      initials = '${userDetails['firstName']![0]}${userDetails['lastName']![0]}';
    }
    return ListView(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text('${userDetails['firstName']} ${userDetails['lastName']}'),
          accountEmail: Text(userDetails['email'] ?? 'No Email'),
          currentAccountPicture: userDetails['profileImage'] != null && userDetails['profileImage']!.isNotEmpty
              ? CircleAvatar(
            backgroundImage: FileImage(File(userDetails['profileImage']!)),
          )
              : CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(initials),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, ToAdminDashboard()),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, () => _logout(context)),
      ],
    );
  }

  Widget _buildGradientListTile(
      BuildContext context,
      String title,
      IconData icon,
      List<Color> colors,
      Widget page,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }
}

class LeaveBalanceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Balance'),
      ),
      body: const Center(
        child: Text('Leave Balance Page'),
      ),
    );
  }
}
