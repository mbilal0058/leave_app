import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emergencyContactNumberController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedRole = 'User';
  bool _obscurePassword = true;
  List<DocumentSnapshot> _managers = [];
  String? _selectedManager;
  File? _cnicFrontImage;
  File? _cnicBackImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchManagers();
  }

  Future<void> _fetchManagers() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Manager').get();
    setState(() {
      _managers = querySnapshot.docs;
    });
  }

  Future<void> _pickImage(ImageSource source, bool isFront) async {
    final pickedFile = await _picker.pickImage(source: source);

    setState(() {
      if (pickedFile != null) {
        if (isFront) {
          _cnicFrontImage = File(pickedFile.path);
        } else {
          _cnicBackImage = File(pickedFile.path);
        }
      }
    });
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'contactNumber': _contactNumberController.text,
          'emergencyContactNumber': _emergencyContactNumberController.text,
          'currentAddress': _currentAddressController.text,
          'email': _emailController.text,
          'role': _selectedRole,
          'jobTitle': _jobTitleController.text,
          'managerId': _selectedRole == 'User' ? _selectedManager : null,
          'cnicFrontImage': _cnicFrontImage?.path,
          'cnicBackImage': _cnicBackImage?.path,
        });
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextFormField(
                    controller: _firstNameController,
                    label: 'First Name',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    icon: Icons.phone,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _emergencyContactNumberController,
                    label: 'Emergency Contact Number',
                    icon: Icons.phone,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _currentAddressController,
                    label: 'Current Address',
                    icon: Icons.home,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                  ),
                  SizedBox(height: 10),
                  _buildTextFormField(
                    controller: _jobTitleController,
                    label: 'Job Title',
                    icon: Icons.work,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Select Role',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: <String>['User', 'Manager', 'Toadmin'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedRole = newValue!;
                        _selectedManager = null;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  if (_selectedRole == 'User')
                    DropdownButtonFormField<String>(
                      value: _selectedManager,
                      decoration: InputDecoration(
                        labelText: 'Select Manager',
                        prefixIcon: Icon(Icons.supervisor_account),
                      ),
                      items: _managers.map((manager) {
                        return DropdownMenuItem<String>(
                          value: manager.id,
                          child: Text('${manager['firstName']} ${manager['lastName']}'),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedManager = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a manager';
                        }
                        return null;
                      },
                    ),
                  SizedBox(height: 20),
                  _buildImagePickerButton('Select CNIC Front Image', true),
                  SizedBox(height: 10),
                  _cnicFrontImage != null
                      ? Image.file(_cnicFrontImage!, height: 100)
                      : Container(),
                  SizedBox(height: 10),
                  _buildImagePickerButton('Select CNIC Back Image', false),
                  SizedBox(height: 10),
                  _cnicBackImage != null
                      ? Image.file(_cnicBackImage!, height: 100)
                      : Container(),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _register,
                    child: Text('Register', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }

  Widget _buildImagePickerButton(String label, bool isFront) {
    return ElevatedButton.icon(
      icon: Icon(Icons.image, color: Colors.white),
      label: Text(label, style: TextStyle(color: Colors.white)),
      onPressed: () => _showImagePickerOptions(isFront),
    );
  }

  void _showImagePickerOptions(bool isFront) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Take a picture'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, isFront);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Select from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, isFront);
            },
          ),
        ],
      ),
    );
  }
}
