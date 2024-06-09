import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'profile.dart';
import 'NotificationsPage.dart';
import 'leaveApply.dart';
import 'login.dart';

class UserDashboard extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<Map<String, String?>> _getUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return {
        'firstName': doc.data()?['firstName'] ?? '',
        'lastName': doc.data()?['lastName'] ?? '',
        'email': doc.data()?['email'] ?? '',
        'profileImage': doc.data()?['profileImage'] ?? '',
      };
    }
    return {
      'firstName': 'Guest',
      'lastName': '',
      'email': '',
      'profileImage': null,
    };
  }

  Future<Map<String, int>> _fetchLeaveTypes() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('leave_types').get();
      Map<String, int> leaveTypes = {};
      snapshot.docs.forEach((doc) {
        leaveTypes[_capitalize(doc['name'].trim())] = int.parse(doc['allowedLeaves']);
      });
      return leaveTypes;
    } catch (e) {
      print('Error fetching leave types: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getLeaveApplications() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('leave_applications').where('userId', isEqualTo: user.uid).get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }
    return [];
  }

  Future<void> _updateUserLeaveBalance(String userId, Map<String, int> leaveBalances) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'leaveBalances': leaveBalances,
      });
    } catch (e) {
      print('Error updating leave balances: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateLeaveBalance() async {
    var leaveTypes = await _fetchLeaveTypes();
    var leaveApplications = await _getLeaveApplications();

    // Initialize used leave days map
    Map<String, int> usedLeaveDays = {};
    leaveTypes.forEach((key, value) {
      usedLeaveDays[key] = 0;
    });

    // Calculate used leave days for approved leaves
    for (var leave in leaveApplications) {
      if (leave['status'] == 'Approved') {
        String leaveTypeKey = _capitalize(leave['leaveType'].trim());
        int leaveDays = _calculateLeaveDays(leave['startDate'], leave['endDate']);
        if (usedLeaveDays.containsKey(leaveTypeKey)) {
          usedLeaveDays[leaveTypeKey] = (usedLeaveDays[leaveTypeKey] ?? 0) + leaveDays;
        }
      }
    }

    // Calculate remaining leaves
    Map<String, int> leaveBalances = {};
    leaveTypes.forEach((key, value) {
      leaveBalances[key] = value - (usedLeaveDays[key] ?? 0);
    });

    // Update user leave balance in Firestore
    User? user = _auth.currentUser;
    if (user != null) {
      await _updateUserLeaveBalance(user.uid, leaveBalances);
    }

    return {
      'leaveBalances': leaveBalances,
      'leaveApplications': leaveApplications,
      'leaveTypes': leaveTypes,
      'usedLeaveDays': usedLeaveDays,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchCurrentMonthHolidays() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('holidays').get();
      DateTime now = DateTime.now();
      int currentMonth = now.month;
      int currentYear = now.year;

      List<Map<String, dynamic>> holidays = snapshot.docs.map((doc) {
        return {
          'name': doc['name'],
          'startDate': (doc['startDate'] as Timestamp).toDate(),
          'endDate': (doc['endDate'] as Timestamp).toDate(),
        };
      }).toList();

      holidays = holidays.where((holiday) {
        DateTime startDate = holiday['startDate'];
        return startDate.month == currentMonth && startDate.year == currentYear;
      }).toList();

      return holidays;
    } catch (e) {
      print('Error fetching holidays: $e');
      return [];
    }
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsPage()),
              );
            },
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCurrentMonthHolidays(),
        builder: (context, holidaySnapshot) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _calculateLeaveBalance(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                var leaveBalances = snapshot.data!['leaveBalances'] as Map<String, int>;
                var leaveApplications = snapshot.data!['leaveApplications'] as List<Map<String, dynamic>>;
                var leaveTypes = snapshot.data!['leaveTypes'] as Map<String, int>;
                var usedLeaveDays = snapshot.data!['usedLeaveDays'] as Map<String, int>;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (holidaySnapshot.connectionState == ConnectionState.waiting) ...[
                          const Center(child: CircularProgressIndicator()),
                        ] else if (holidaySnapshot.hasError) ...[
                          Center(child: Text('Error: ${holidaySnapshot.error}')),
                        ] else if (holidaySnapshot.hasData && holidaySnapshot.data!.isNotEmpty) ...[
                          const Text('Holidays This Month:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ...holidaySnapshot.data!.map((holiday) {
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              elevation: 6,
                              shadowColor: Colors.grey.withOpacity(0.5),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                  leading: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.blue.withOpacity(0.2),
                                    child: Icon(Icons.event, color: Colors.blue.shade700, size: 30),
                                  ),
                                  title: Text(
                                    holiday['name'],
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${DateFormat.yMMMd().format(holiday['startDate'])} - ${DateFormat.yMMMd().format(holiday['endDate'])}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            );

                          }).toList(),
                          const SizedBox(height: 20),
                        ],
                        const Text('Leave Balance:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ...leaveTypes.entries.map((entry) {
                          String leaveTypeKey = entry.key;
                          int usedLeaves = usedLeaveDays[leaveTypeKey] ?? 0;
                          int remainingLeaves = entry.value - usedLeaves;
                          double progress = usedLeaves / entry.value;
                          return _buildLeaveBalance(leaveTypeKey, remainingLeaves, entry.value, progress);
                        }).toList(),
                        const SizedBox(height: 20),
                        const Text('Applied Leaves (Pending):', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildAppliedLeaves(leaveApplications.where((leave) => leave['status'] == 'Pending').toList()),
                        const SizedBox(height: 20),
                        const Text('Leave History:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildLeaveHistory(leaveApplications.where((leave) => leave['status'] == 'Approved').toList()),
                      ],
                    ),
                  ),
                );
              } else {
                return const Center(child: Text('No leave data found'));
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LeaveApplicationForm()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  int _calculateLeaveDays(String startDate, String endDate) {
    try {
      DateTime start = DateFormat('d-M-yyyy').parse(startDate);
      DateTime end = DateFormat('d-M-yyyy').parse(endDate);
      return end.difference(start).inDays + 1; // +1 to include both start and end date
    } catch (e) {
      print('Error parsing dates: $e');
      return 0;
    }
  }

  ListTile _buildDrawerItems(BuildContext context, String title, IconData icon, Widget? page, [Function? onTap]) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) {
          onTap(context);
        } else if (page != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
        }
      },
    );
  }

  Widget _buildLoadingDrawer(BuildContext context) {
    return ListView(
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('Loading...'),
          accountEmail: Text('Loading...'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text('U'),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, null),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, _logout),
      ],
    );
  }

  Widget _buildErrorDrawer(BuildContext context) {
    return ListView(
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('Error'),
          accountEmail: Text('Error loading user data'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text('U'),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, null),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, _logout),
      ],
    );
  }

  Widget _buildNoUserDataDrawer(BuildContext context) {
    return ListView(
      children: [
        const UserAccountsDrawerHeader(
          accountName: Text('No User Data'),
          accountEmail: Text('No email available'),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text('U'),
          ),
        ),
        _buildDrawerItems(context, 'Home', Icons.home, null),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, _logout),
      ],
    );
  }

  Widget _buildUserDrawer(Map<String, String?> userDetails, BuildContext context) {
    String initials = 'U';
    if (userDetails['firstName'] != null && userDetails['firstName']!.isNotEmpty) {
      initials = userDetails['firstName']!.substring(0, 1).toUpperCase();
    }
    if (userDetails['lastName'] != null && userDetails['lastName']!.isNotEmpty) {
      initials += userDetails['lastName']!.substring(0, 1).toUpperCase();
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
        _buildDrawerItems(context, 'Home', Icons.home, null),
        _buildDrawerItems(context, 'Profile', Icons.person, ProfileScreen()),
        _buildDrawerItems(context, 'Logout', Icons.logout, null, _logout),
      ],
    );
  }

  Widget _buildLeaveBalance(String type, int remaining, int total, double progress) {
    bool exceeded = remaining < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$type: ${exceeded ? 'Exceeded by ${remaining.abs()}' : '$remaining'} / $total days',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: exceeded ? Colors.red : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: progress > 1 ? 1 : progress,
          backgroundColor: Colors.grey[300],
          color: exceeded ? Colors.red : Colors.blue,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildAppliedLeaves(List<dynamic> appliedLeaves) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: appliedLeaves.map((leave) {
        int leaveDays = _calculateLeaveDays(leave['startDate'], leave['endDate']);
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            title: Text('${leave['leaveType']} - ${leave['startDate']} to ${leave['endDate']}'),
            subtitle: Text('Total days: $leaveDays'),
            trailing: LeaveStatusWidget(status: leave['status']),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveHistory(List<dynamic> leaveHistory) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leaveHistory.length,
      itemBuilder: (context, index) {
        var leave = leaveHistory[index];
        int leaveDays = _calculateLeaveDays(leave['startDate'], leave['endDate']);
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            title: Text('${_capitalize(leave['leaveType'].trim())} - ${leave['startDate']} to ${leave['endDate']}'),
            subtitle: Text('Total days: $leaveDays'),
            trailing: LeaveStatusWidget(status: leave['status']),
          ),
        );
      },
    );
  }

  void _openFile(String url) {
    // Implement your logic to open the file
  }
}

class LeaveStatusWidget extends StatelessWidget {
  final String status;

  LeaveStatusWidget({required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'Pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending';
        break;
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, color: statusColor),
        const SizedBox(width: 5),
        Text(
          statusText,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
