import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  //final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? _roomId;
  bool _isRemoteVideoAvailable = false; // Add a flag

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
    _webrtcService.peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        _webrtcService.remoteRenderer.srcObject = event.streams[0];
        setState(() {
          // This is the key: Update the UI when the remote stream is available
          _isRemoteVideoAvailable = true;
        });
      }
    };
  }

  Future<void> _initializeRenderer() async {
    await _localRenderer.initialize();
    await _webrtcService.remoteRenderer.initialize(); // تهيئة الـ RTCVideoRenderer البعيد
    await _webrtcService.initializeWebRTC();
    setState(() {
      _localRenderer.srcObject = _webrtcService.localStream;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _webrtcService.remoteRenderer.dispose(); // تخلص من RTCVideoRenderer البعيد
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("WebRTC P2P Call")),
        body: Center(
          child: Column(
            children: [
              Expanded(
                child: _localRenderer.srcObject != null
                    ? RTCVideoView(_localRenderer, mirror: true)
                    : CircularProgressIndicator(),
              ),
              Expanded(
                child: _webrtcService.remoteRenderer.srcObject != null
                    ? RTCVideoView(_webrtcService.remoteRenderer)
                    : CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}