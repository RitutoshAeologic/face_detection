import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'core/service/mlkit_face_service.dart';
import 'data/repositories/face_detection_repository_impl.dart';
import 'domain/repositories/face_detection_repository.dart';
import 'domain/usecase/detect_faces_usecase.dart';
import 'presentation/controller/face_detection_controller.dart';
import 'presentation/screens/face_detection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initDependencies();
  runApp(const MyApp());
}

void _initDependencies() {
  final service = MLKitFaceService();
  Get.put(service);

  final repository = FaceDetectionRepositoryImpl(service);
  // FIX #5: register repository in GetX
  Get.put<FaceDetectionRepository>(repository);

  // FIX #4: wire use case and inject into controller
  final useCase = DetectFacesUseCase(repository);
  Get.put(useCase);

  Get.put(FaceDetectionController(useCase));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
        ),
      ),
      home: const FaceDetectionScreen(),
    );
  }
}