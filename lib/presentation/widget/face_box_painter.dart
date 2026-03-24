import 'package:face_detection/domain/model/face_result.dart';
import 'package:flutter/material.dart';

class FaceBoxPainter extends CustomPainter {

  final List<FaceResult> faces;

  FaceBoxPainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final face in faces) {

      final rect = Rect.fromLTRB(
        face.left,
        face.top,
        face.right,
        face.bottom,
      );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}