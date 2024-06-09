import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class UserDetailScreen extends StatelessWidget {
  final String userId;

  UserDetailScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User not found'));
          }

          var userDocument = snapshot.data!;
          var data = userDocument.data() as Map<String, dynamic>;
          String? profileImage = data['profileImage'];
          String firstName = data['firstName'] ?? '';
          String lastName = data['lastName'] ?? '';
          String email = data['email'] ?? 'Not provided';
          String contactNumber = data['contactNumber'] ?? 'Not provided';
          String emergencyContact = data['emergencyContactNumber'] ?? 'Not provided';
          String currentAddress = data['currentAddress'] ?? 'Not provided';
          String role = data['role'] ?? 'Not provided';
          String jobTitle = data['jobTitle'] ?? 'Not provided';
          String cnicFrontImage = data['cnicFrontImage'] ?? '';
          String cnicBackImage = data['cnicBackImage'] ?? '';
          Map<String, dynamic> leaveBalances = data['leaveBalances'] != null ? Map<String, dynamic>.from(data['leaveBalances']) : {};

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profileImage != null && profileImage.isNotEmpty
                          ? FileImage(File(profileImage))
                          : null,
                      child: profileImage == null || profileImage.isEmpty
                          ? Text('${firstName[0]}${lastName[0]}', style: TextStyle(fontSize: 24))
                          : null,
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      '$firstName $lastName',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 8),
                  Divider(thickness: 1),
                  _buildDetailRow('Email', email, icon: Icons.email, onTap: () => _emailUser(email)),
                  _buildDetailRow('Contact Number', contactNumber, icon: Icons.phone, onTap: () => _contactUser(contactNumber)),
                  _buildDetailRow('Emergency Contact', emergencyContact),
                  _buildDetailRow('Current Address', currentAddress),
                  _buildDetailRow('Role', role),
                  _buildDetailRow('Job Title', jobTitle),
                  _buildImageRow('CNIC Front Image', cnicFrontImage),
                  _buildImageRow('CNIC Back Image', cnicBackImage),
                  SizedBox(height: 20),
                  FutureBuilder<Map<String, int>>(
                    future: _fetchLeaveTypes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error fetching leave types: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('No leave types found'));
                      }

                      var leaveTypes = snapshot.data!;
                      return _buildLeaveBalances(leaveBalances, leaveTypes);
                    },
                  ),
                  SizedBox(height: 20),
                  _buildActionButton('Call', Icons.call, contactNumber != 'Not provided' ? () => _contactUser(contactNumber) : null),
                  SizedBox(height: 10),
                  _buildActionButton('Email', Icons.email, email != 'Not provided' ? () => _emailUser(email) : null),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1).toLowerCase();

  Widget _buildDetailRow(String title, String value, {IconData? icon, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, color: Colors.blue),
          if (icon != null) SizedBox(width: 8),
          Text(
            '$title: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: TextStyle(fontSize: 16, color: onTap != null ? Colors.blue : Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageRow(String title, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          if (imageUrl.isNotEmpty)
            Container(
              height: 200,
              child: imageUrl.startsWith('http')
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Image.file(File(imageUrl), fit: BoxFit.cover),
            )
          else
            Text('No image available', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLeaveBalances(Map<String, dynamic> leaveBalances, Map<String, int> leaveTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave Balances:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
        ),
        SizedBox(height: 12),
        ...leaveTypes.entries.map((entry) {
          String leaveType = entry.key;
          int allowedLeaves = entry.value;
          int usedLeaves = leaveBalances[leaveType]?.toInt() ?? 0;
          int remainingLeaves = allowedLeaves - usedLeaves;
          double progress = usedLeaves / allowedLeaves;
          bool exceeded = remainingLeaves < 0;
          Color progressColor = exceeded ? Colors.red : Colors.blue;

          return Tooltip(
            message: 'Allowed: $allowedLeaves\nUsed: $usedLeaves\nRemaining: $remainingLeaves',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$leaveType: ${exceeded ? 'Exceeded by ${remainingLeaves.abs()}' : '$remainingLeaves'} / $allowedLeaves days',
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
                  color: progressColor,
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.blue,
          padding: EdgeInsets.symmetric(vertical: 16.0),
          textStyle: TextStyle(fontSize: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _contactUser(String contactNumber) async {
    if (contactNumber == 'Not provided') return;
    final Uri uri = Uri(
      scheme: 'tel',
      path: contactNumber,
    );
    if (await canLaunch(uri.toString())) {
      await launch(uri.toString());
    } else {
      print('Could not launch $contactNumber');
    }
  }

  void _emailUser(String email) async {
    if (email == 'Not provided') return;
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunch(uri.toString())) {
      await launch(uri.toString());
    } else {
      print('Could not launch $email');
    }
  }
}
