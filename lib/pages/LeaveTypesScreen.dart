import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaveTypesScreen extends StatefulWidget {
  @override
  _LeaveTypesScreenState createState() => _LeaveTypesScreenState();
}

class _LeaveTypesScreenState extends State<LeaveTypesScreen> {
  final TextEditingController _leaveTypeController = TextEditingController();
  final TextEditingController _leaveNumberController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _leaveTypesCollection = FirebaseFirestore.instance.collection('leave_types');

  void _addOrEditLeaveType([DocumentSnapshot? document]) {
    if (document != null) {
      _leaveTypeController.text = document['name'] ?? '';
      _leaveNumberController.text = document['allowedLeaves'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document == null ? 'Add Leave Type' : 'Edit Leave Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _leaveTypeController,
              decoration: const InputDecoration(
                hintText: 'Enter leave type',
                labelText: 'Leave Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _leaveNumberController,
              decoration: const InputDecoration(
                hintText: 'Enter number of leaves allowed',
                labelText: 'Allowed Leaves',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _leaveTypeController.clear();
              _leaveNumberController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final String leaveType = _leaveTypeController.text;
              final String numberOfLeaves = _leaveNumberController.text;

              if (document == null) {
                _leaveTypesCollection.add({
                  'name': leaveType,
                  'allowedLeaves': numberOfLeaves,
                });
              } else {
                document.reference.update({
                  'name': leaveType,
                  'allowedLeaves': numberOfLeaves,
                });
              }
              _leaveTypeController.clear();
              _leaveNumberController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  void _deleteLeaveType(DocumentSnapshot document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Leave Type'),
        content: const Text('Are you sure you want to delete this leave type?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              document.reference.delete();
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Types', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder(
        stream: _leaveTypesCollection.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var document = snapshot.data!.docs[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  title: Text(document['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text('Allowed Leaves: ${document['allowedLeaves'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _addOrEditLeaveType(document),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteLeaveType(document),
                      ),
                    ],
                  ),
                  tileColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 10),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditLeaveType(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
