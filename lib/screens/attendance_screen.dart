import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui; // ✅ untuk ImageFilter

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';

import '../models/attendance_record.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';

enum AttendanceMode { checkIn, checkOut }

class AttendanceScreen extends StatefulWidget {
  final AttendanceMode mode;
  const AttendanceScreen({Key? key, required this.mode}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  List<Face> _detectedFaces = [];

  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _requestCameraPermission();
      await _faceDetectionService.initialize();
      await _initializeCamera();
    } catch (e) {
      _showErrorDialog('Initialization Error', e.toString());
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        throw Exception('Camera permission denied');
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = await _cameraService.initializeCamera();
      await _cameraController!.initialize();
      await _cameraController!.lockCaptureOrientation();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showErrorDialog('Camera Error', 'Failed to initialize camera: $e');
    }
  }

  Future<void> _captureAndProcessImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final imagePath = await CameraService.captureImage(_cameraController!);
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) throw Exception('Image file not found');

      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetectionService.detectFaces(inputImage);
      setState(() => _detectedFaces = faces);

      if (faces.isNotEmpty) {
        await _processAttendance(imagePath, faces.first);
      } else {
        _showMessage('No face detected',
            'Please ensure your face is clearly visible.');
      }
    } catch (e) {
      _showErrorDialog('Processing Error', e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processAttendance(String imagePath, Face face) async {
    try {
      String recordId = '${DateTime.now().millisecondsSinceEpoch}';
      String userId = 'user_${Random().nextInt(1000)}';
      String userName = 'Employee ${Random().nextInt(100)}';

      double confidence = face.headEulerAngleY != null
          ? (1.0 - (face.headEulerAngleY!.abs() / 90.0))
          : 0.8;

      Map<String, dynamic> faceData = _faceDetectionService.getFaceInfo(face);

      AttendanceRecord record = AttendanceRecord(
        id: recordId,
        userId: userId,
        userName: userName,
        type: widget.mode == AttendanceMode.checkIn
            ? AttendanceType.checkIn
            : AttendanceType.checkOut,
        timestamp: DateTime.now(),
        photoPath: imagePath,
        faceData: faceData,
        confidence: confidence,
      );

      bool success = await FirebaseService.saveAttendanceRecord(record);
      if (success) {
        _showSuccessDialog(record);
      } else {
        _showMessage('Save Failed', 'Failed to save record. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Attendance Error', e.toString());
    }
  }

  void _showSuccessDialog(AttendanceRecord record) {
    String typeText =
        record.type == AttendanceType.checkIn ? 'Check In' : 'Check Out';
    String timeText = DateFormat('HH:mm:ss').format(record.timestamp);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              record.type == AttendanceType.checkIn
                  ? Icons.login
                  : Icons.logout,
              color: record.type == AttendanceType.checkIn
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            Text('$typeText Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${record.userName}'),
            Text('Time: $timeText'),
            Text(
                'Confidence: ${(record.confidence! * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            if (record.photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(record.photoPath!), height: 100),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor =
        widget.mode == AttendanceMode.checkIn ? Colors.green : Colors.red;
    final titleText =
        widget.mode == AttendanceMode.checkIn ? 'Check In' : 'Check Out';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(titleText),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: _isCameraInitialized
          ? _buildCameraView(themeColor)
          : _buildLoadingView(), // ✅ sudah ada
    );
  }

  /// ✅ Loading view agar tidak error
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(Color themeColor) {
    final size = MediaQuery.of(context).size;
    final preview = _cameraController!.value;
    final previewSize = preview.previewSize;
    if (previewSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final scale = max(
      size.width / previewSize.height,
      size.height / previewSize.width,
    );

    return Stack(
      children: [
        Center(
          child: Transform.scale(
            scale: scale,
            child: CameraPreview(_cameraController!),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),
        ..._detectedFaces
            .map((f) => _buildFaceOverlay(f, scale, themeColor))
            .toList(),
        Positioned(
          bottom: 140,
          left: 20,
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), // ✅
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.face_retouching_natural,
                        size: 40, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'Arahkan wajah Anda ke kamera\nlalu tekan tombol di bawah',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isProcessing ? null : _captureAndProcessImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt,
                    size: 36, color: Colors.white),
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Memproses...',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFaceOverlay(Face face, double scale, Color color) {
    final rect = face.boundingBox;
    return Positioned(
      left: rect.left * scale,
      top: rect.top * scale,
      width: rect.width * scale,
      height: rect.height * scale,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
