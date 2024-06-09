import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emergencyContactNumberController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  File? _profileImage;
  File? _cnicFrontImage;
  File? _cnicBackImage;
  final ImagePicker _picker = ImagePicker();
  bool _isEditing = false;
  List<DocumentSnapshot> _managers = [];
  String? _selectedManager;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchManagers();
  }

  Future<void> _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _firstNameController.text = doc.data()?['firstName'] ?? '';
        _lastNameController.text = doc.data()?['lastName'] ?? '';
        _contactNumberController.text = doc.data()?['contactNumber'] ?? '';
        _emergencyContactNumberController.text = doc.data()?['emergencyContactNumber'] ?? '';
        _currentAddressController.text = doc.data()?['currentAddress'] ?? '';
        _emailController.text = doc.data()?['email'] ?? '';
        _selectedManager = doc.data()?['managerId'];
        String profileImagePath = doc.data()?['profileImage'] ?? '';
        String cnicFrontImagePath = doc.data()?['cnicFrontImage'] ?? '';
        String cnicBackImagePath = doc.data()?['cnicBackImage'] ?? '';
        if (profileImagePath.isNotEmpty) {
          _profileImage = File(profileImagePath);
        }
        if (cnicFrontImagePath.isNotEmpty) {
          _cnicFrontImage = File(cnicFrontImagePath);
        }
        if (cnicBackImagePath.isNotEmpty) {
          _cnicBackImage = File(cnicBackImagePath);
        }
      });
    }
  }

  Future<void> _fetchManagers() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Manager')
        .get();
    setState(() {
      _managers = querySnapshot.docs;
    });
  }

  Future<void> _updateUserProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        User? user = _auth.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'contactNumber': _contactNumberController.text,
            'emergencyContactNumber': _emergencyContactNumberController.text,
            'currentAddress': _currentAddressController.text,
            'email': _emailController.text,
            'managerId': _selectedManager,
            'profileImage': _profileImage?.path,
            'cnicFrontImage': _cnicFrontImage?.path,
            'cnicBackImage': _cnicBackImage?.path,
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Profile updated successfully'),
          ));
          setState(() {
            _isEditing = false;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profile update failed: ${e.toString()}'),
        ));
      }
    }
  }

  Future<void> _pickImage(bool isProfileImage, bool isFrontImage) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    setState(() {
      if (pickedFile != null) {
        if (isProfileImage) {
          _profileImage = File(pickedFile.path);
        } else if (isFrontImage) {
          _cnicFrontImage = File(pickedFile.path);
        } else {
          _cnicBackImage = File(pickedFile.path);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateUserProfile();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 100,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                        child: _profileImage == null ? Icon(Icons.person, size: 70) : null,
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _pickImage(true, false),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Icon(Icons.camera_alt, size: 30, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person,
                    readOnly: !_isEditing,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person,
                    readOnly: !_isEditing,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    icon: Icons.phone,
                    readOnly: !_isEditing,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _emergencyContactNumberController,
                    label: 'Emergency Contact Number',
                    icon: Icons.phone,
                    readOnly: !_isEditing,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _currentAddressController,
                    label: 'Current Address',
                    icon: Icons.home,
                    readOnly: !_isEditing,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    readOnly: !_isEditing,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: TextEditingController(text: 'Manager: ${_getManagerName(_selectedManager)}'),
                    label: 'Manager',
                    icon: Icons.supervisor_account,
                    readOnly: true,
                  ),
                  SizedBox(height: 20),
                  _buildImagePicker(
                    label: 'CNIC Front Image',
                    imageFile: _cnicFrontImage,
                    isProfileImage: false,
                    isFrontImage: true,
                  ),
                  SizedBox(height: 20),
                  _buildImagePicker(
                    label: 'CNIC Back Image',
                    imageFile: _cnicBackImage,
                    isProfileImage: false,
                    isFrontImage: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required File? imageFile,
    required bool isProfileImage,
    bool isFrontImage = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _isEditing ? () => _pickImage(isProfileImage, isFrontImage) : null,
          child: Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey, width: 1),
              image: imageFile != null
                  ? DecorationImage(image: FileImage(imageFile), fit: BoxFit.cover)
                  : null,
              color: Colors.grey[200],
            ),
            child: imageFile == null
                ? Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey[700]))
                : null,
          ),
        ),
      ],
    );
  }

  String _getManagerName(String? managerId) {
    if (managerId == null) return 'None';
    for (var manager in _managers) {
      if (manager.id == managerId) {
        return '${manager['firstName']} ${manager['lastName']}';
      }
    }
    return 'None';
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool readOnly,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        isDense: true,
      ),
      readOnly: readOnly,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }
}
