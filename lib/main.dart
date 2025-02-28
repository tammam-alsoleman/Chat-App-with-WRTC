import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  Future<void> _initializeRenderer() async {
    await _localRenderer.initialize();
    await _webrtcService.initializeWebRTC();
    setState(() {
      _localRenderer.srcObject = _webrtcService.localStream;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("WebRTC P2P Call")),
        body: Center(
          child: _localRenderer.srcObject != null
              ? RTCVideoView(_localRenderer)
              : CircularProgressIndicator(),
        ),
      ),
    );
  }
}