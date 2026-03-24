import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class MLKitFaceService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
    ),
  );

  Future<List<Face>> detect(InputImage image) async {
    return await _detector.processImage(image);
  }

  void dispose() => _detector.close();
}