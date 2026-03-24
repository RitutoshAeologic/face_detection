import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:face_detection/domain/repositories/face_detection_repository.dart';

class DetectFacesUseCase {
  final FaceDetectionRepository repository;
  DetectFacesUseCase(this.repository);

  Future<List<Face>> call(InputImage image) => repository.detectFaces(image);
}