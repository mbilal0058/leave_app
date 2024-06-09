import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:badges/badges.dart' as badges_pkg;
import 'UserListScreen.dart';
import 'manager_notification.dart';
import 'profile.dart';
import 'login.dart';

class ManagerDashboard extends StatefulWidget {
  @override
  _ManagerDashboardState createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? currentUser;
  bool isManager = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  int pendingLeaveCount = 0;
  int totalLeaveCount = 0;
  int approvedLeaveCount = 0;
  int rejectedLeaveCount = 0;
  int selectedStatusIndex = 0; // 0: All, 1: Pending, 2: Approved, 3: Rejected
  DateTimeRange? selectedDateRange;
  List<Map<String, dynamic>> leaveApplications = [];
  List<Map<String, dynamic>> filteredLeaveApplications = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    await _fetchUserRole();
    await _fetchPendingLeaveCount();
    await _fetchLeaveApplications();
    await _fetchLeaveSummary();
    _filterApplications();
  }

  Future<void> _fetchUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          currentUser = user;
          isManager = userDoc['role'] == 'Manager';
        });
      } else {
        _showError("User document does not exist or has no data");
      }
    } else {
      _showError("No user is currently signed in");
    }
  }

  Future<void> _fetchPendingLeaveCount() async {
    if (currentUser == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('leave_applications')
        .where('managerId', isEqualTo: currentUser!.uid)
        .where('status', isEqualTo: 'Pending')
        .get();

    setState(() {
      pendingLeaveCount = snapshot.docs.length;
    });
  }

  Future<void> _fetchLeaveApplications() async {
    if (currentUser == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('leave_applications')
        .where('managerId', isEqualTo: currentUser!.uid)
        .get();

    var applications = snapshot.docs.map((doc) => {'docId': doc.id, ...doc.data() as Map<String, dynamic>}).toList();

    for (var leave in applications) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(leave['userId']).get();
      leave['userDetails'] = userDoc.data();
    }

    setState(() {
      leaveApplications = applications;
    });

    _filterApplications();
  }

  Future<void> _fetchLeaveSummary() async {
    if (currentUser == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('leave_applications')
        .where('managerId', isEqualTo: currentUser!.uid)
        .get();

    int total = snapshot.docs.length;
    int approved = snapshot.docs.where((doc) => doc['status'] == 'Approved').length;
    int rejected = snapshot.docs.where((doc) => doc['status'] == 'Rejected').length;

    setState(() {
      totalLeaveCount = total;
      approvedLeaveCount = approved;
      rejectedLeaveCount = rejected;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  Future<Map<String, String?>> _getUserDetails() async {
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      return {
        'firstName': userDoc['firstName'],
        'lastName': userDoc['lastName'],
        'email': userDoc['email'],
        'profileImage': userDoc['profileImage'],
      };
    }
    return {
      'firstName': 'Guest',
      'lastName': '',
      'email': '',
      'profileImage': null,
    };
  }

  Future<void> _updateLeaveStatus(String docId, String status, String comment) async {
    try {
      await FirebaseFirestore.instance.collection('leave_applications').doc(docId).update({
        'status': status,
        'comment': comment,
        'managerCommentedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        pendingLeaveCount--;
        leaveApplications.removeWhere((application) => application['docId'] == docId);
        if (status == 'Approved') {
          approvedLeaveCount++;
        } else if (status == 'Rejected') {
          rejectedLeaveCount++;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leave application $status successfully')));
    } catch (e) {
      _showError('Error updating leave status: $e');
    }

    _filterApplications();
  }

  DateTime? _parseDate(String date) {
    try {
      return DateFormat('d-M-yyyy').parse(date);
    } catch (e) {
      _showError('Invalid date format: $date');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
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

  Future<List<Map<String, dynamic>>> _getUserLeaveApplications(String userId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('leave_applications').where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> _calculateLeaveBalance(String userId) async {
    var leaveTypes = await _fetchLeaveTypes();
    var leaveApplications = await _getUserLeaveApplications(userId);

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

    return {
      'leaveBalances': leaveBalances,
      'leaveApplications': leaveApplications,
      'leaveTypes': leaveTypes,
      'usedLeaveDays': usedLeaveDays,
    };
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _filterApplications() {
    String searchText = _searchController.text.toLowerCase();
    String selectedStatus = ['All', 'Pending', 'Approved', 'Rejected'][selectedStatusIndex];

    List<Map<String, dynamic>> filtered = leaveApplications.where((application) {
      bool matchesStatus = selectedStatus == 'All' || application['status'] == selectedStatus;
      bool matchesSearch = application['userDetails']['firstName'].toLowerCase().contains(searchText) ||
          application['userDetails']['lastName'].toLowerCase().contains(searchText) ||
          application['leaveType'].toLowerCase().contains(searchText) ||
          application['status'].toLowerCase().contains(searchText);
      bool matchesDateRange = selectedDateRange == null ||
          (selectedDateRange!.start.isBefore(_parseDate(application['endDate'])!) &&
              selectedDateRange!.end.isAfter(_parseDate(application['startDate'])!));

      return matchesStatus && matchesSearch && matchesDateRange;
    }).toList();

    setState(() {
      filteredLeaveApplications = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSummaryGrid(),
            _buildUserListTile(), // Add the list tile here

            _buildSearchBar(),
            _buildDateRangePicker(),
            _buildStatusToggleButton(),
            _buildAllLeaveApplicationsView(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Manager Dashboard'),
      actions: [
        badges_pkg.Badge(
          position: badges_pkg.BadgePosition.topEnd(top: 0, end: 3),
          badgeContent: Text(
            pendingLeaveCount.toString(),
            style: TextStyle(color: Colors.white),
          ),
          child: IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ManagerNotification(notifications: leaveApplications),
              ));
            },
          ),
        ),
      ],
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: FutureBuilder<Map<String, String?>>(
        future: _getUserDetails(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var userDetails = snapshot.data!;
          return ListView(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text('${userDetails['firstName']} ${userDetails['lastName']}'),
                accountEmail: Text(userDetails['email'] ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: userDetails['profileImage'] != null
                      ? FileImage(File(userDetails['profileImage']!))
                      : null,
                  child: userDetails['profileImage'] == null ? Icon(Icons.person, size: 50) : null,
                ),
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
                onTap: () {
                  _logout(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        children: [
          _buildSummaryCard('Total Leave Applications', totalLeaveCount, Colors.blue),
          _buildSummaryCard('Pending Leave Applications', pendingLeaveCount, Colors.orange),
          _buildSummaryCard('Approved Leave Applications', approvedLeaveCount, Colors.green),
          _buildSummaryCard('Rejected Leave Applications', rejectedLeaveCount, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.0),
            Text(
              count.toString(),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggleButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ToggleButtons(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("All"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Pending"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Approved"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Rejected"),
          ),
        ],
        isSelected: [
          selectedStatusIndex == 0,
          selectedStatusIndex == 1,
          selectedStatusIndex == 2,
          selectedStatusIndex == 3,
        ],
        onPressed: (int index) {
          setState(() {
            selectedStatusIndex = index;
          });
          _filterApplications();
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Search',
        ),
        onChanged: (value) {
          _filterApplications();
        },
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null && picked != selectedDateRange) {
                  setState(() {
                    selectedDateRange = picked;
                  });
                  _filterApplications();
                }
              },
              child: Text(
                selectedDateRange == null
                    ? 'Select Date Range'
                    : '${_formatDate(selectedDateRange!.start)} - ${_formatDate(selectedDateRange!.end)}',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.clear, color: Colors.red),
            onPressed: () {
              setState(() {
                selectedDateRange = null;
              });
              _filterApplications();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserListTile() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(Icons.group, color: Colors.blueAccent, size: 30),
        title: Text(
          'View Users',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserListScreen(managerId: currentUser!.uid),
            ),
          );
        },
      ),
    );

  }

  Widget _buildAllLeaveApplicationsView() {
    return filteredLeaveApplications.isNotEmpty
        ? ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filteredLeaveApplications.length,
      itemBuilder: (context, index) {
        var leaveApplication = filteredLeaveApplications[index];
        return _buildLeaveApplicationItem(leaveApplication);
      },
    )
        : Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          'No record found in the selected date range',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLeaveApplicationItem(Map<String, dynamic> leaveApplication) {
    var userDetails = leaveApplication['userDetails'] ?? {};
    var profileImage = userDetails['profileImage'];
    return Card(
      margin: EdgeInsets.all(8.0),
      child: ListTile(
        leading: profileImage != null && profileImage.isNotEmpty
            ? CircleAvatar(backgroundImage: FileImage(File(profileImage))) // Use FileImage
            : CircleAvatar(child: Icon(Icons.person)),
        title: Text('${userDetails['firstName']} ${userDetails['lastName']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave type: ${leaveApplication['leaveType']}'),
            Text('Status: ${leaveApplication['status']}'),
          ],
        ),
        trailing: _buildStatusIndicator(leaveApplication['status']),
        onTap: () => _showLeaveDetailsBottomSheet(context, leaveApplication),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'Pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Icon(statusIcon, color: statusColor);
  }

  void _showLeaveDetailsBottomSheet(BuildContext context, Map<String, dynamic> leave) {
    var userDetails = leave['userDetails'] ?? {};
    var profileImage = userDetails['profileImage'];
    var userId = leave['userId'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _calculateLeaveBalance(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var leaveBalance = snapshot.data!;
                var leaveBalances = leaveBalance['leaveBalances'] as Map<String, int>;
                var leaveHistory = leaveBalance['leaveApplications'] as List<Map<String, dynamic>>;
                return Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            profileImage != null && profileImage.isNotEmpty
                                ? CircleAvatar(backgroundImage: FileImage(File(profileImage)), radius: 30) // Use FileImage
                                : CircleAvatar(child: Icon(Icons.person), radius: 30),
                            SizedBox(width: 16.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${userDetails['firstName']} ${userDetails['lastName']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text(userDetails['email']),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => launch('tel:${userDetails['contactNumber']}'),
                              child: Text('Call', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Text('Leave Balances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ...leaveBalances.entries.map((entry) {
                          int remaining = entry.value;
                          bool exceeded = remaining < 0;
                          int totalLeaves = leaveBalance['leaveTypes'][entry.key];
                          int usedLeaves = totalLeaves - remaining;
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
                                  value: exceeded ? 1.0 : usedLeaves / totalLeaves,
                                  backgroundColor: Colors.grey[300],
                                  color: exceeded ? Colors.red : Colors.green,
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  exceeded
                                      ? '${remaining.abs()} days overused'
                                      : '$usedLeaves out of $totalLeaves days used',
                                  style: TextStyle(color: exceeded ? Colors.red : Colors.black),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        SizedBox(height: 16.0),
                        Text('Leave Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Leave Type: ${leave['leaveType']}'),
                        Text('From: ${leave['startDate']}'),
                        Text('To: ${leave['endDate']}'),
                        Text('Reason: ${leave['reason']}'),
                        Text('Status: ${leave['status']}'),
                        if (leave['status'] == 'Rejected') Text('Comment: ${leave['comment']}'),
                        if (leave['status'] == 'Rejected') Text('Rejected At: ${_formatDate(leave['managerCommentedAt'].toDate())}'),
                        SizedBox(height: 16.0),
                        if (leave['status'] == 'Pending')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _commentController,
                                decoration: InputDecoration(labelText: 'Add a comment (optional)'),
                              ),
                              SizedBox(height: 16.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _updateLeaveStatus(leave['docId'], 'Approved', _commentController.text);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Accept', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          _updateLeaveStatus(leave['docId'], 'Rejected', _commentController.text);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Reject', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        SizedBox(height: 16.0),
                        Text('Leave History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: leaveHistory.length,
                          itemBuilder: (context, index) {
                            var leave = leaveHistory[index];
                            return ListTile(
                              title: Text('${leave['leaveType']} (${leave['status']})'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From: ${leave['startDate']} To: ${leave['endDate']}'),
                                  if (leave['status'] == 'Rejected') Text('Comment: ${leave['comment']}'),
                                  if (leave['status'] == 'Rejected') Text('Rejected At: ${_formatDate(leave['managerCommentedAt'].toDate())}'),
                                ],
                              ),
                              trailing: _buildStatusIndicator(leave['status']),
                            );
                          },
                        ),
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

  int _calculateLeaveDays(String startDate, String endDate) {
    DateTime? start = _parseDate(startDate);
    DateTime? end = _parseDate(endDate);
    if (start == null || end == null) return 0;
    return end.difference(start).inDays + 1;
  }
}
