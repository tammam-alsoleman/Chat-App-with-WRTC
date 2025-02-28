import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math'; // Import for generating random room ID

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? _roomId; // Store the room ID
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();


  Future<void> initializeWebRTC() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      }
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null && _roomId != null) {
        addIceCandidateToRoom(candidate);
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    print("WebRTC Initialized Successfully");
  }

  RTCPeerConnection? get peerConnection => _peerConnection;

  // 1. إنشاء غرفة (Caller)
  Future<String?> createRoom() async {
    // Generate a random room ID for better security
    _roomId = generateRoomId();
    DatabaseReference roomRef = _dbRef.child('rooms').child(_roomId!);

    // Initialize room data
    await roomRef.set({
      'offer': null,
      'answer': null,
      'iceCandidates': {},
      'createdAt': ServerValue.timestamp, // Firebase server timestamp
    });

    print('Created room with ID: $_roomId');
    return _roomId;
  }

  // 2. الانضمام إلى غرفة (Callee)
  Future<bool> joinRoom(String roomId) async {
    DatabaseReference roomRef = _dbRef.child('rooms').child(roomId);

    // Check if the room exists
    DataSnapshot snapshot = await roomRef.get();
    if (!snapshot.exists) {
      print('Room with ID: $roomId does not exist.');
      return false; // Indicate that joining failed
    }

    _roomId = roomId;

    // Listen for remote offer
    roomRef.child('offer').onValue.listen((event) async {
      if (event.snapshot.value != null) {
        Map<String, dynamic> offerData = Map<String, dynamic>.from(event.snapshot.value as Map);
        RTCSessionDescription offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
        await setRemoteDescription(offer);
        createAnswer(); // Automatically create the answer
      }
    });
    // Listen for ICE candidates and add them
    roomRef.child('iceCandidates').onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        Map<String, dynamic> iceCandidate = Map<String, dynamic>.from(event.snapshot.value as Map);
        addRemoteIceCandidate(RTCIceCandidate(iceCandidate['candidate'], iceCandidate['sdpMid'], iceCandidate['sdpMLineIndex']));
      }
    });

    print('Joined room with ID: $_roomId');
    return true; // Indicate that joining was successful
  }

  // 3. إنشاء عرض (Offer) - Caller
  Future<void> createOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await setLocalDescription(offer);
    DatabaseReference roomRef = _dbRef.child('rooms').child(_roomId!);
    await roomRef.child('offer').set(offer.toMap());
  }

  Future<void> createAnswer() async {
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await setLocalDescription(answer);
    DatabaseReference roomRef = _dbRef.child('rooms').child(_roomId!);
    await roomRef.child('answer').set(answer.toMap());
  }

  // Add ICE candidate to Firebase
  Future<void> addIceCandidateToRoom(RTCIceCandidate candidate) async {
    if (_roomId != null) {
      DatabaseReference roomRef = _dbRef.child('rooms').child(_roomId!);
      await roomRef.child('iceCandidates').push().set(candidate.toMap());
    }
  }

  //Set local description
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    await _peerConnection!.setLocalDescription(description);
  }

  // Set remote description
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  // Add remote ICE candidate
  Future<void> addRemoteIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  // Helper function to generate a random room ID
  String generateRoomId({int length = 8}) {
    const String allowedChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => allowedChars.codeUnitAt(random.nextInt(allowedChars.length)),
      ),
    );
  }

  MediaStream? get localStream => _localStream;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
}