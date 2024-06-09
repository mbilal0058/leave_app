import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserListScreen extends StatelessWidget {
  final String managerId;

  UserListScreen({required this.managerId});

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('managerId', isEqualTo: managerId)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<Map<String, int>> _calculateLeaveBalance(String userId) async {
    try {
      QuerySnapshot leaveTypesSnapshot = await FirebaseFirestore.instance.collection('leave_types').get();
      QuerySnapshot leaveApplicationsSnapshot = await FirebaseFirestore.instance
          .collection('leave_applications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'Approved')
          .get();

      Map<String, int> leaveTypes = {};
      leaveTypesSnapshot.docs.forEach((doc) {
        leaveTypes[doc['name']] = int.parse(doc['allowedLeaves']);
      });

      Map<String, int> usedLeaveDays = {};
      leaveApplicationsSnapshot.docs.forEach((doc) {
        String leaveType = doc['leaveType'];
        int leaveDays = _calculateLeaveDays(doc['startDate'], doc['endDate']);
        usedLeaveDays[leaveType] = (usedLeaveDays[leaveType] ?? 0) + leaveDays;
      });

      Map<String, int> leaveBalances = {};
      leaveTypes.forEach((key, value) {
        leaveBalances[key] = value - (usedLeaveDays[key] ?? 0);
      });

      return leaveBalances;
    } catch (e) {
      print('Error calculating leave balance: $e');
      return {};
    }
  }

  int _calculateLeaveDays(String startDate, String endDate) {
    DateTime start = DateTime.parse(startDate);
    DateTime end = DateTime.parse(endDate);
    return end.difference(start).inDays + 1;
  }

  void _showProfileBottomSheet(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var profileImage = user['cnicFrontImage'] as String?;
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, int>>(
              future: _calculateLeaveBalance(user['id']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var leaveBalances = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildProfileImage(profileImage),
                            SizedBox(width: 16.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    user['email'] ?? '',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.0),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.phone),
                          title: Text('Contact Number'),
                          subtitle: Text(user['contactNumber'] ?? ''),
                        ),
                        ListTile(
                          leading: Icon(Icons.phone_in_talk),
                          title: Text('Emergency Contact Number'),
                          subtitle: Text(user['emergencyContactNumber'] ?? ''),
                        ),
                        ListTile(
                          leading: Icon(Icons.home),
                          title: Text('Current Address'),
                          subtitle: Text(user['currentAddress'] ?? ''),
                        ),
                        ListTile(
                          leading: Icon(Icons.work),
                          title: Text('Job Title'),
                          subtitle: Text(user['jobTitle'] ?? ''),
                        ),
                        ListTile(
                          leading: Icon(Icons.person),
                          title: Text('Role'),
                          subtitle: Text(user['role'] ?? ''),
                        ),
                        SizedBox(height: 16.0),
                        Text('Leave Balances:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8.0),
                        ...leaveBalances.entries.map((entry) {
                          int remaining = entry.value;
                          bool exceeded = remaining < 0;
                          int totalLeaves = leaveBalances[entry.key] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key}:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4.0),
                                LinearProgressIndicator(
                                  value: exceeded ? 1.0 : remaining / totalLeaves,
                                  backgroundColor: Colors.grey[300],
                                  color: exceeded ? Colors.red : Colors.green,
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  exceeded
                                      ? '${remaining.abs()} days overused'
                                      : '$remaining out of $totalLeaves days remaining',
                                  style: TextStyle(color: exceeded ? Colors.red : Colors.black),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileImage(String? profileImage) {
    if (profileImage != null && profileImage.isNotEmpty) {
      File imageFile = File(profileImage);
      bool exists = imageFile.existsSync();
      print('Profile image path: $profileImage');
      print('File exists: $exists');
      if (exists) {
        return CircleAvatar(backgroundImage: FileImage(imageFile), radius: 40);
      } else {
        return CircleAvatar(child: Icon(Icons.person, size: 40), radius: 40);
      }
    } else {
      return CircleAvatar(child: Icon(Icons.person, size: 40), radius: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              var profileImage = user['cnicFrontImage'] as String?;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  leading: _buildProfileImage(profileImage),
                  title: Text(
                    '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(user['jobTitle'] ?? ''),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showProfileBottomSheet(context, user);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
