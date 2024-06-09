import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class LeaveApplicationForm extends StatefulWidget {
  @override
  _LeaveApplicationFormState createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedLeaveType;
  String? _defaultManagerId;
  File? _selectedFile;
  List<String> _leaveTypes = [];
  bool _isLoading = false;
  int _totalLeaveDays = 0;

  @override
  void initState() {
    super.initState();
    _fetchLeaveTypes();
    _loadUserProfile();
  }

  Future<void> _fetchLeaveTypes() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('leave_types').get();
      List<String> leaveTypes = snapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _leaveTypes = leaveTypes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching leave types: $e'),
      ));
    }
  }

  Future<void> _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _defaultManagerId = doc.data()?['managerId'];
      });
    }
  }

  Future<void> _submitApplication() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        User? user = _auth.currentUser;

        String? fileUrl;
        if (_selectedFile != null) {
          String fileName = _selectedFile!.path.split('/').last;
          Reference storageRef = FirebaseStorage.instance.ref().child('leave_attachments/$fileName');
          UploadTask uploadTask = storageRef.putFile(_selectedFile!);
          TaskSnapshot taskSnapshot = await uploadTask;
          fileUrl = await taskSnapshot.ref.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('leave_applications').add({
          'userId': user?.uid,
          'leaveType': _selectedLeaveType,
          'reason': _reasonController.text,
          'startDate': _startDateController.text,
          'endDate': _endDateController.text,
          'status': 'Pending',
          'fileUrl': fileUrl,
          'managerId': _defaultManagerId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Leave application submitted.'),
        ));
        _formKey.currentState?.reset();
        setState(() {
          _selectedLeaveType = null;
          _selectedFile = null;
          _totalLeaveDays = 0;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error submitting application: $e'),
        ));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('dd-MM-yyyy').format(pickedDate);
        _calculateTotalLeaveDays();
      });
    }
  }

  void _calculateTotalLeaveDays() {
    if (_startDateController.text.isNotEmpty && _endDateController.text.isNotEmpty) {
      DateTime startDate = DateFormat('dd-MM-yyyy').parse(_startDateController.text);
      DateTime endDate = DateFormat('dd-MM-yyyy').parse(_endDateController.text);
      setState(() {
        _totalLeaveDays = endDate.difference(startDate).inDays + 1;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_file),
                title: Text('File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leave Application'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedLeaveType,
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _leaveTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedLeaveType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a leave type';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the reason';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _startDateController,
                decoration: InputDecoration(
                  labelText: 'Start Date',
                  prefixIcon: Icon(Icons.date_range),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(_startDateController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the start date';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _endDateController,
                decoration: InputDecoration(
                  labelText: 'End Date',
                  prefixIcon: Icon(Icons.date_range),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(_endDateController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the end date';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Text(
                'Total Leave Days: $_totalLeaveDays',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              _selectedFile != null
                  ? Column(
                children: [
                  Text('Selected File: ${_selectedFile!.path.split('/').last}'),
                  SizedBox(height: 10),
                ],
              )
                  : Container(),
              ElevatedButton.icon(
                onPressed: _showAttachmentOptions,
                icon: Icon(Icons.attach_file, color: Colors.white),
                label: Text('Attach File', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submitApplication,
                child: Text(
                  'Submit Application',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(height: 20),
              if (_selectedLeaveType != null &&
                  _reasonController.text.isNotEmpty &&
                  _startDateController.text.isNotEmpty &&
                  _endDateController.text.isNotEmpty)
                Text(
                  'Summary:\n\n'
                      'Leave Type: $_selectedLeaveType\n'
                      'Reason: ${_reasonController.text}\n'
                      'Start Date: ${_startDateController.text}\n'
                      'End Date: ${_endDateController.text}\n'
                      'Total Leave Days: $_totalLeaveDays',
                  style: TextStyle(fontSize: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
