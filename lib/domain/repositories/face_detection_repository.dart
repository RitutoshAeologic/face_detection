
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

abstract class FaceDetectionRepository {
  Future<List<Face>> detectFaces(InputImage image);
}