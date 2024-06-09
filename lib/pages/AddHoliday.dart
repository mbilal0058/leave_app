import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddHolidays extends StatefulWidget {
  @override
  _AddHolidaysState createState() => _AddHolidaysState();
}

class _AddHolidaysState extends State<AddHolidays> {
  final TextEditingController _holidayNameController = TextEditingController();
  DateTimeRange? _dateRange;
  final CollectionReference _holidaysCollection = FirebaseFirestore.instance.collection('holidays');

  void _addOrEditHoliday([DocumentSnapshot? document]) {
    if (document != null) {
      _holidayNameController.text = document['name'] ?? '';
      _dateRange = DateTimeRange(
        start: (document['startDate'] as Timestamp).toDate(),
        end: (document['endDate'] as Timestamp).toDate(),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document == null ? 'Add Holiday' : 'Edit Holiday'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _holidayNameController,
              decoration: const InputDecoration(
                hintText: 'Enter holiday name',
                labelText: 'Holiday Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _selectDateRange,
              child: Text(
                _dateRange == null
                    ? 'Select Date Range'
                    : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _holidayNameController.clear();
              _dateRange = null;
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final String holidayName = _holidayNameController.text;
              final DateTimeRange? dateRange = _dateRange;

              if (holidayName.isEmpty || dateRange == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Please enter all details'),
                ));
                return;
              }

              if (document == null) {
                _holidaysCollection.add({
                  'name': holidayName,
                  'startDate': dateRange.start,
                  'endDate': dateRange.end,
                });
              } else {
                document.reference.update({
                  'name': holidayName,
                  'startDate': dateRange.start,
                  'endDate': dateRange.end,
                });
              }

              _holidayNameController.clear();
              _dateRange = null;
              Navigator.of(context).pop();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteHoliday(DocumentSnapshot document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: const Text('Are you sure you want to delete this holiday?'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Holidays', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder(
        stream: _holidaysCollection.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var document = snapshot.data!.docs[index];
              DateTime startDate = (document['startDate'] as Timestamp).toDate();
              DateTime endDate = (document['endDate'] as Timestamp).toDate();
              int totalDays = endDate.difference(startDate).inDays + 1; // Calculate total days

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  title: Text(document['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Date Range: ${DateFormat('yyyy-MM-dd').format(startDate)} - ${DateFormat('yyyy-MM-dd').format(endDate)}\nTotal Days: $totalDays',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _addOrEditHoliday(document),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteHoliday(document),
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
        onPressed: () => _addOrEditHoliday(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
