import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchLeaveApplications() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('leave_applications')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .get();

        return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      } catch (e) {
        print("Error fetching leave applications: $e");
        return [];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLeaveApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error fetching leave applications'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No leave applications found'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final leaveApplication = snapshot.data![index];
                return _buildLeaveApplicationItem(
                  leaveApplication['leaveType'],
                  leaveApplication['startDate'],
                  leaveApplication['endDate'],
                  leaveApplication['status'],
                  leaveApplication['reason'],
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildLeaveApplicationItem(String leaveType, String startDate, String endDate, String status, String reason) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text('$leaveType from $startDate to $endDate', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Status: $status\nReason: $reason'),
        trailing: Icon(
          Icons.notifications,
          color: status == 'Approved' ? Colors.green : status == 'Rejected' ? Colors.red : Colors.orange,
        ),
      ),
    );
  }
}
