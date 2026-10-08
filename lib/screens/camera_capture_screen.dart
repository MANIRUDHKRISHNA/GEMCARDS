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
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
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
        title: const Text('Good capture'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 260,
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 40),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Retake'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Use photo'),
          ),
        ],
      ),
    );
    if (usePhoto != true) {
      if (mounted) {
        setState(() => _feedback = 'Position the document inside the frame');
      }
      return;
    }
    if (!mounted) return;
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
    Navigator.of(
      context,
    ).pop(CameraCaptureResult(path: file.path, ocrText: ocrText));
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = 'Flash is not available on this camera.');
      }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            const Text(
              'Document capture',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_loading && controller != null && controller.value.isInitialized)
            CameraPreview(controller)
          else if (_cameraFailed)
            Container(
              color: AppTheme.ink,
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.no_photography_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Camera unavailable',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Go back and use the clearly marked demo capture option.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CameraGuidePainter()),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.ink.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ALIGN YOUR DOCUMENT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _feedback,
                      key: ValueKey(_feedback),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 36,
            child: IconButton.filledTonal(
              tooltip: 'Toggle flash',
              onPressed: _controller == null || _cameraFailed
                  ? null
                  : _toggleFlash,
              icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Capture document',
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _controller == null || _cameraFailed
                          ? null
                          : _capture,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentDark,
                            width: 4,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.ink,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
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
    final overlay = Paint()
      ..color = Colors.black.withValues(alpha: .5)
      ..style = PaintingStyle.fill;
    final box = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .47),
      width: size.width * .84,
      height: size.width * .54,
    );

    final shade = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(18)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, shade, cutout),
      overlay,
    );

    final guide = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const corner = 32.0;
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
