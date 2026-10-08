import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/theme/app_theme.dart';

class CameraCaptureResult {
  const CameraCaptureResult({required this.path, this.ocrText = ''});

  final String path;
  final String ocrText;
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    required this.title,
    required this.instruction,
    required this.lensDirection,
    this.runOcr = false,
    super.key,
  });

  final String title;
  final String instruction;
  final CameraLensDirection lensDirection;
  final bool runOcr;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _loading = true;
  bool _cameraFailed = false;
  bool _flashOn = false;
  String _feedback = 'Position the document inside the frame';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final matches = cameras.where(
        (camera) => camera.lensDirection == widget.lensDirection,
      );
      final camera = matches.isNotEmpty ? matches.first : cameras.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cameraFailed = true;
        _feedback = 'Camera unavailable. Check camera permission.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<String> _runOcr(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(path));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _feedback = 'Capturing... hold still');
    final file = await controller.takePicture();
    if (!mounted) return;
    final usePhoto = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use this photo?'),
        content: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(file.path), fit: BoxFit.cover)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Retake')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Use photo')),
        ],
      ),
    );
    if (usePhoto != true) { if (mounted) setState(() => _feedback = 'Position the document inside the frame'); return; }
    var ocrText = '';
    if (widget.runOcr) {
      setState(() => _feedback = 'Reading document text...');
      try {
        ocrText = await _runOcr(file.path);
      } catch (_) {
        ocrText = '';
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      CameraCaptureResult(path: file.path, ocrText: ocrText),
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } catch (_) {
      if (mounted) setState(() => _feedback = 'Flash is not available on this camera.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_loading && controller != null && controller.value.isInitialized)
            CameraPreview(controller)
          else if (_cameraFailed)
            Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.no_photography_outlined, color: Colors.white, size: 52), const SizedBox(height: 16), const Text('Camera unavailable', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Return to the document screen and use the demo fallback to continue.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))])) )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CameraGuidePainter()),
            ),
          ),
          Positioned(
            top: 20,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    widget.instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _feedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18, bottom: 36,
            child: IconButton.filledTonal(
              tooltip: 'Toggle flash',
              onPressed: _controller == null ? null : _toggleFlash,
              icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent, width: 5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: .38);
    final box = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .47),
      width: size.width * .82,
      height: size.height * .33,
    );

    canvas.drawRect(Offset.zero & size, overlay);
    canvas.drawRect(box, Paint()..blendMode = BlendMode.clear);

    final guide = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const corner = 28.0;
    final path = Path()
      ..moveTo(box.left, box.top + corner)
      ..lineTo(box.left, box.top)
      ..lineTo(box.left + corner, box.top)
      ..moveTo(box.right - corner, box.top)
      ..lineTo(box.right, box.top)
      ..lineTo(box.right, box.top + corner)
      ..moveTo(box.left, box.bottom - corner)
      ..lineTo(box.left, box.bottom)
      ..lineTo(box.left + corner, box.bottom)
      ..moveTo(box.right - corner, box.bottom)
      ..lineTo(box.right, box.bottom)
      ..lineTo(box.right, box.bottom - corner);

    canvas.drawPath(path, guide);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
