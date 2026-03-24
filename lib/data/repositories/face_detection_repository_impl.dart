import 'package:face_detection/core/service/mlkit_face_service.dart';
import 'package:face_detection/domain/repositories/face_detection_repository.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';


class FaceDetectionRepositoryImpl implements FaceDetectionRepository {
  final MLKitFaceService service;
  FaceDetectionRepositoryImpl(this.service);

  @override
  Future<List<Face>> detectFaces(InputImage image) => service.detect(image);
}
