import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManagerNotification extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;

  ManagerNotification({required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          var notification = notifications[index];
          var userDetails = notification['userDetails'];
          var leaveType = notification['leaveType'];
          var status = notification['status'];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 4.0,
            child: ListTile(
              leading: _buildProfileAvatar(userDetails),
              title: Text(
                'Leave Type: $leaveType',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Status: $status'),
              trailing: _buildStatusIcon(status),
              onTap: () {
                _showUserDetailsBottomSheet(context, notification);
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileAvatar(Map<String, dynamic>? userDetails) {
    return CircleAvatar(
      backgroundImage: userDetails != null && userDetails['profileImage'] != null
          ? NetworkImage(userDetails['profileImage'])
          : null,
      backgroundColor: userDetails == null || userDetails['profileImage'] == null ? Colors.grey : null,
      child: userDetails == null || userDetails['profileImage'] == null
          ? Icon(Icons.person, color: Colors.white)
          : null,
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData iconData;
    Color color;

    switch (status) {
      case 'Pending':
        iconData = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case 'Approved':
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        iconData = Icons.cancel;
        color = Colors.red;
    }

    return Icon(iconData, color: color);
  }

  void _showUserDetailsBottomSheet(BuildContext context, Map<String, dynamic> leave) {
    var userDetails = leave['userDetails'];
    final TextEditingController _commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(userDetails),
                  Divider(),
                  _buildSectionTitle('User Details'),
                  _buildUserInfoRow('Email', userDetails['email']),
                  _buildUserInfoRow('Contact Number', userDetails['contactNumber']),
                  _buildUserInfoRow('Current Address', userDetails['currentAddress']),
                  _buildUserInfoRow('Emergency Contact', userDetails['emergencyContactNumber']),
                  _buildImageSection('CNIC Front Image', userDetails['cnicFrontImage']),
                  _buildImageSection('CNIC Back Image', userDetails['cnicBackImage']),
                  Divider(),
                  _buildSectionTitle('Leave Details'),
                  _buildUserInfoRow('Leave Type', leave['leaveType']),
                  _buildUserInfoRow('From', _formatDate(leave['startDate'])),
                  _buildUserInfoRow('To', _formatDate(leave['endDate'])),
                  _buildUserInfoRow('Reason', leave['reason']),
                  SizedBox(height: 16.0),
                  if (leave['status'] == 'Pending') _buildCommentSection(_commentController, leave, context),
                  if (leave['status'] == 'Approved' || leave['status'] == 'Rejected') _buildCommentDisplay(leave),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic>? userDetails) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _buildProfileAvatar(userDetails),
      title: Text(
        '${userDetails?['firstName']} ${userDetails?['lastName']}',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
      ),
      subtitle: Text(userDetails?['jobTitle'] ?? 'No Job Title'),
    );
  }

  Widget _buildCommentSection(TextEditingController controller, Map<String, dynamic> leave, BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Enter your comment here',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        SizedBox(height: 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('Approve', Colors.green, () {
              _updateLeaveStatus(context, leave['docId'], 'Approved', controller.text);
            }),
            _buildActionButton('Reject', Colors.red, () {
              _updateLeaveStatus(context, leave['docId'], 'Rejected', controller.text);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          child: Text(label, style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCommentDisplay(Map<String, dynamic> leave) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Comment'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text('${leave['comment']}'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text('Date: ${_formatDateTime(leave['managerCommentedAt'])}'),
        ),
      ],
    );
  }

  Widget _buildUserInfoRow(String label, String? value) {
    return value != null
        ? Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    )
        : Container();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildImageSection(String label, String? imageUrl) {
    return imageUrl != null
        ? Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onTap: () => _openFile(imageUrl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Image.network(
                imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    )
        : Container();
  }

  void _openFile(String url) {
    launch(url);
  }

  void _updateLeaveStatus(BuildContext context, String docId, String status, String comment) {
    FirebaseFirestore.instance.collection('leave_applications').doc(docId).update({
      'status': status,
      'comment': comment,
      'managerCommentedAt': FieldValue.serverTimestamp(),
    }).then((value) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leave application $status successfully')));
    }).catchError((error) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating leave status: $error')));
    });
  }

  String _formatDate(String dateStr) {
    DateTime date = DateFormat('d-M-yyyy').parse(dateStr);
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatDateTime(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
}
