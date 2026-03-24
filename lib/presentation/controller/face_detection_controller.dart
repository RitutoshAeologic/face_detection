import 'dart:io';
import 'package:face_detection/domain/usecase/detect_faces_usecase.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionController extends GetxController {
  // FIX #4: use DetectFacesUseCase instead of direct repository
  final DetectFacesUseCase detectFacesUseCase;
  FaceDetectionController(this.detectFacesUseCase);

  CameraController? cameraController;
  List<CameraDescription> cameras = [];
  int currentCameraIndex = 0;

  final faces = <Face>[].obs;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _initializing = false;

  // Expose camera image size for coordinate scaling in painter
  Size? imageSize;

  Future<void> initializeCamera() async {
    if (_isCameraInitialized || _initializing) return;
    _initializing = true;

    // FIX #6: request camera permission before accessing hardware
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      debugPrint("Camera permission denied");
      _initializing = false;
      return;
    }

    cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint("No cameras found");
      _initializing = false;
      return;
    }

    await _startCamera(cameras[currentCameraIndex]);
    _isCameraInitialized = true;
    _initializing = false;
  }

  Future<void> _startCamera(CameraDescription camera) async {
    cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21   // NV21 required on Android for ML Kit
          : ImageFormatGroup.bgra8888,
    );

    await cameraController!.initialize();

    if (!cameraController!.value.isInitialized) {
      throw Exception("Camera failed to initialize");
    }

    await Future.delayed(const Duration(milliseconds: 200));
    await cameraController!.startImageStream(_processFrame);
    update();
  }

  Future<void> switchCamera() async {
    if (cameras.length < 2) return;
    _isProcessing = false;

    // FIX #9: await the stream stop to avoid race condition
    try {
      await cameraController?.stopImageStream();
    } catch (_) {}
    await cameraController?.dispose();
    cameraController = null;

    currentCameraIndex = (currentCameraIndex + 1) % cameras.length;
    await _startCamera(cameras[currentCameraIndex]);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Store image size for coordinate transform in painter
      imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final inputImage = _convertCameraImage(image);

      final result = await detectFacesUseCase(inputImage);
      faces.assignAll(result);
    } catch (e) {
      debugPrint("Face detection error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // FIX #1 & #2: correct InputImage conversion
  // - Use InputImageMetadata without deprecated planeData
  // - On Android pass only the first plane bytes (Y plane for NV21)
  // - On iOS use bgra8888 and pass all bytes directly
  InputImage _convertCameraImage(CameraImage image) {

    final WriteBuffer allBytes = WriteBuffer();

    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final camera = cameras[currentCameraIndex];

    final rotation =
        InputImageRotationValue.fromRawValue(
            camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format =
        InputImageFormatValue.fromRawValue(
            image.format.raw) ??
            InputImageFormat.nv21;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }
  bool get isFrontCamera =>
      cameras.isNotEmpty &&
          cameras[currentCameraIndex].lensDirection ==
              CameraLensDirection.front;

  @override
  void onClose() async {
    // FIX #9: proper async cleanup
    try {
      await cameraController?.stopImageStream();
    } catch (_) {}
    await cameraController?.dispose();
    super.onClose();
  }
}