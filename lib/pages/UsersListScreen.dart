import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import 'UserDetailScreen.dart';

class UsersListScreen extends StatefulWidget {
  @override
  _UsersListScreenState createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  String _searchQuery = '';
  String _selectedRole = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users List'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedRole = value;
              });
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(value: 'All', child: Text('All')),
                PopupMenuItem(value: 'User', child: Text('User')),
                PopupMenuItem(value: 'Manager', child: Text('Manager')),
                PopupMenuItem(value: 'Toadmin', child: Text('Admin')),
              ];
            },
            icon: Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No users found'));
              }

              var users = snapshot.data!.docs;
              if (_searchQuery.isNotEmpty) {
                users = users.where((user) {
                  var name = '${user['firstName']} ${user['lastName']}'.toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();
              }
              if (_selectedRole != 'All') {
                users = users.where((user) => user['role'] == _selectedRole).toList();
              }

              return Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Total Employees: ${users.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          var document = users[index];
                          var data = document.data() as Map<String, dynamic>;
                          String? profileImage = data['profileImage'];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16.0),
                              leading: CircleAvatar(
                                radius: 30,
                                backgroundImage: profileImage != null && profileImage.isNotEmpty
                                    ? FileImage(File(profileImage))
                                    : null,
                                child: profileImage == null || profileImage.isEmpty
                                    ? Text(
                                  '${data['firstName'][0]}${data['lastName'][0]}',
                                  style: TextStyle(fontSize: 24),
                                )
                                    : null,
                              ),
                              title: Text(
                                '${data['firstName']} ${data['lastName']}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['email'] ?? '', style: TextStyle(fontSize: 16)),
                                  Text('Role: ${data['role']}', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserDetailScreen(userId: document.id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
