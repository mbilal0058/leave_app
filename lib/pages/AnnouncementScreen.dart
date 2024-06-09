import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AnnouncementScreen extends StatefulWidget {
  @override
  _AnnouncementScreenState createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final TextEditingController _announcementController = TextEditingController();
  File? _imageFile;
  String? _voiceNotePath;
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
    _requestPermissions();
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile != null ? File(pickedFile.path) : null;
    });
  }

  Future<void> _recordVoiceNote() async {
    if (_isRecording) {
      await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } else {
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder!.startRecorder(toFile: tempPath);
      setState(() {
        _voiceNotePath = tempPath;
        _isRecording = true;
      });
    }
  }

  Future<void> _postAnnouncement() async {
    if (_announcementController.text.isEmpty && (_imageFile == null && _voiceNotePath == null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please add some content to post.'),
      ));
      return;
    }

    String? imageUrl;
    String? voiceNoteUrl;

    if (_imageFile != null) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('announcements/${_imageFile!.path.split('/').last}');
        final uploadTask = storageRef.putFile(_imageFile!);
        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error uploading image: $e'),
        ));
        return;
      }
    }

    if (_voiceNotePath != null) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('announcements/voice_notes/${_voiceNotePath!.split('/').last}');
        final uploadTask = storageRef.putFile(File(_voiceNotePath!));
        final snapshot = await uploadTask;
        voiceNoteUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error uploading voice note: $e'),
        ));
        return;
      }
    }

    await FirebaseFirestore.instance.collection('announcements').add({
      'text': _announcementController.text,
      'imageUrl': imageUrl,
      'voiceNoteUrl': voiceNoteUrl,
      'timestamp': Timestamp.now(),
      'userId': _auth.currentUser?.uid,
    });

    _announcementController.clear();
    setState(() {
      _imageFile = null;
      _voiceNotePath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Announcement posted successfully.'),
    ));
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _announcementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('announcements').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView(
                  reverse: true,
                  children: snapshot.data!.docs.map((document) {
                    return ChatBubble(
                      text: document['text'],
                      imageUrl: document['imageUrl'],
                      voiceNoteUrl: document['voiceNoteUrl'],
                      timestamp: (document['timestamp'] as Timestamp).toDate(),
                      isCurrentUser: document['userId'] == _auth.currentUser?.uid,
                      documentId: document.id,
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  onPressed: _recordVoiceNote,
                ),
                Expanded(
                  child: TextField(
                    controller: _announcementController,
                    decoration: InputDecoration(
                      hintText: 'Enter announcement',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _postAnnouncement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String? text;
  final String? imageUrl;
  final String? voiceNoteUrl;
  final DateTime timestamp;
  final bool isCurrentUser;
  final String documentId;

  const ChatBubble({
    Key? key,
    this.text,
    this.imageUrl,
    this.voiceNoteUrl,
    required this.timestamp,
    required this.isCurrentUser,
    required this.documentId,
  }) : super(key: key);

  Future<void> _deleteVoiceNote(BuildContext context) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Voice Note'),
        content: Text('Are you sure you want to delete this voice note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete) {
      try {
        // Delete voice note from Firebase Storage
        await FirebaseStorage.instance.refFromURL(voiceNoteUrl!).delete();

        // Remove voice note reference from Firestore document
        await FirebaseFirestore.instance.collection('announcements').doc(documentId).update({'voiceNoteUrl': FieldValue.delete()});

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Voice note deleted successfully.'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting voice note: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text != null) Text(text!, style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black)),
            if (imageUrl != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewer(imageUrl: imageUrl!),
                    ),
                  );
                },
                child: Image.network(imageUrl!, height: 100, fit: BoxFit.cover),
              ),
            if (voiceNoteUrl != null)
              GestureDetector(
                onLongPress: () => _deleteVoiceNote(context),
                child: VoiceNotePlayer(
                  voiceNoteUrl: voiceNoteUrl!,
                ),
              ),
            SizedBox(height: 5.0),
            Text(
              DateFormat('yyyy-MM-dd – kk:mm').format(timestamp),
              style: TextStyle(color: isCurrentUser ? Colors.white60 : Colors.black54, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceNotePlayer extends StatefulWidget {
  final String voiceNoteUrl;

  const VoiceNotePlayer({required this.voiceNoteUrl});

  @override
  _VoiceNotePlayerState createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setUrl(widget.voiceNoteUrl);
    _audioPlayer.durationStream.listen((d) => setState(() => _duration = d ?? Duration.zero));
    _audioPlayer.positionStream.listen((p) => setState(() => _position = p));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _playPause,
            ),
            Expanded(
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                },
              ),
            ),
            Text(_formatDuration(_position)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class ImageViewer extends StatelessWidget {
  final String imageUrl;

  const ImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Image.network(imageUrl),
      ),
    );
  }
}
