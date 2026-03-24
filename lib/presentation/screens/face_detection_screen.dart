import 'package:face_detection/presentation/controller/face_detection_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';


class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  final controller = Get.find<FaceDetectionController>();

  @override
  void initState() {
    super.initState();
    controller.initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GetBuilder<FaceDetectionController>(
        builder: (_) {
          if (controller.cameraController == null ||
              !controller.cameraController!.value.isInitialized) {
            return const _LoadingView();
          }
          return _CameraView(controller: controller);
        },
      ),
    );
  }
}

// ── Loading state ──────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Initializing Camera",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera + Overlay ──────────────────────────

class _CameraView extends StatelessWidget {
  final FaceDetectionController controller;
  const _CameraView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final camValue = controller.cameraController!.value;
    final camAspect = camValue.aspectRatio;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview — fills screen
        _buildCameraPreview(camAspect, size),

        // FIX #7 & #10: scaled + mirrored face overlay
        Obx(() => CustomPaint(
          size: size,
          painter: FaceOverlayPainter(
            faces: controller.faces.toList(),
            imageSize: controller.imageSize ?? Size(size.width, size.height),
            screenSize: size,
            isFrontCamera: controller.isFrontCamera,
          ),
        )),

        // HUD
        _buildHUD(context),

        // Face count badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          child: Obx(() => _FaceCountBadge(count: controller.faces.length)),
        ),

        // Switch camera button
        Positioned(
          bottom: 48,
          right: 24,
          child: _SwitchCameraButton(onTap: controller.switchCamera),
        ),
      ],
    );
  }

  Widget _buildCameraPreview(double camAspect, Size size) {
    return ClipRect(
      child: OverflowBox(
        maxWidth: size.width,
        maxHeight: size.height,
        child: AspectRatio(
          aspectRatio: 1 / camAspect,
          child: CameraPreview(controller.cameraController!),
        ),
      ),
    );
  }

  Widget _buildHUD(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAINTER — Fixed coordinate scaling & mirror
// ─────────────────────────────────────────────

class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size screenSize;
  final bool isFrontCamera;

  FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.screenSize,
    required this.isFrontCamera,
  });

  // FIX #7: compute scale factors from image space → screen space
  double get _scaleX => screenSize.width / imageSize.width;
  double get _scaleY => screenSize.height / imageSize.height;

  Offset _scalePoint(double x, double y) {
    // FIX #10: mirror X for front camera
    final sx = isFrontCamera ? screenSize.width - x * _scaleX : x * _scaleX;
    return Offset(sx, y * _scaleY);
  }

  Rect _scaleRect(Rect r) {
    final tl = _scalePoint(r.left, r.top);
    final br = _scalePoint(r.right, r.bottom);
    return Rect.fromPoints(tl, br);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.15)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final landmarkPaint = Paint()
      ..color = const Color(0xFFFF4081)
      ..style = PaintingStyle.fill;

    final contourPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final face in faces) {
      final rect = _scaleRect(face.boundingBox);

      // Glow + border
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), glowPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), boxPaint);

      // Corner accents
      _drawCorners(canvas, rect, boxPaint);

      // Tracking ID
      if (face.trackingId != null) {
        _drawLabel(canvas, rect, "ID ${face.trackingId}");
      }

      // Landmarks — FIX #7: scale points
      face.landmarks.forEach((type, landmark) {
        final pt = landmark?.position;
        if (pt != null) {
          final scaled = _scalePoint(pt.x.toDouble(), pt.y.toDouble());
          canvas.drawCircle(scaled, 3, landmarkPaint);
        }
      });

      // Contours — FIX #7: scale + draw as path
      face.contours.forEach((type, contour) {
        final pts = contour?.points;
        if (pts == null || pts.isEmpty) return;
        final path = Path();
        final first = _scalePoint(pts.first.x.toDouble(), pts.first.y.toDouble());
        path.moveTo(first.dx, first.dy);
        for (final pt in pts.skip(1)) {
          final s = _scalePoint(pt.x.toDouble(), pt.y.toDouble());
          path.lineTo(s.dx, s.dy);
        }
        path.close();
        canvas.drawPath(path, contourPaint);
      });

      // Emotion labels
      _drawEmotions(canvas, face, rect);
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint) {
    const len = 16.0;
    final paths = [
      // Top-left
      [rect.topLeft, rect.topLeft + const Offset(len, 0)],
      [rect.topLeft, rect.topLeft + const Offset(0, len)],
      // Top-right
      [rect.topRight, rect.topRight + const Offset(-len, 0)],
      [rect.topRight, rect.topRight + const Offset(0, len)],
      // Bottom-left
      [rect.bottomLeft, rect.bottomLeft + const Offset(len, 0)],
      [rect.bottomLeft, rect.bottomLeft + const Offset(0, -len)],
      // Bottom-right
      [rect.bottomRight, rect.bottomRight + const Offset(-len, 0)],
      [rect.bottomRight, rect.bottomRight + const Offset(0, -len)],
    ];
    for (final pair in paths) {
      canvas.drawLine(pair[0], pair[1], paint..strokeWidth = 3);
    }
  }

  void _drawLabel(Canvas canvas, Rect rect, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 11,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.topLeft + const Offset(4, -18));
  }

  void _drawEmotions(Canvas canvas, Face face, Rect rect) {
    final smiling = face.smilingProbability;
    final leftEye = face.leftEyeOpenProbability;
    if (smiling == null && leftEye == null) return;

    final lines = <String>[];
    if (smiling != null) lines.add("😊 ${(smiling * 100).toStringAsFixed(0)}%");
    if (leftEye != null) lines.add("👁 ${(leftEye * 100).toStringAsFixed(0)}%");

    var dy = rect.bottom + 6;
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + 4, dy));
      dy += 16;
    }
  }

  // FIX #8: compare actual face list content, not always repaint
  @override
  bool shouldRepaint(FaceOverlayPainter old) =>
      old.faces != faces ||
          old.imageSize != imageSize ||
          old.isFrontCamera != isFrontCamera;
}

class _FaceCountBadge extends StatelessWidget {
  final int count;
  const _FaceCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: count > 0
              ? const Color(0xFF00E5FF).withOpacity(0.8)
              : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: count > 0 ? const Color(0xFF00E5FF) : Colors.white38,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count == 0
                ? "NO FACE"
                : count == 1
                ? "1 FACE"
                : "$count FACES",
            style: TextStyle(
              color: count > 0 ? const Color(0xFF00E5FF) : Colors.white54,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchCameraButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SwitchCameraButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: const Icon(
          Icons.flip_camera_android_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

