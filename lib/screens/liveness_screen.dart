import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../widgets/primary_button.dart';

class LivenessResult {
  const LivenessResult({required this.passed, required this.score});

  final bool passed;
  final double score;
}

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  CameraController? _controller;
  Timer? _timer;
  int _promptIndex = 0;
  bool _checking = false;

  final prompts = const [
    'Look straight at the camera',
    'Slowly turn your head left',
    'Slowly turn your head right',
    'Blink once',
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      final camera = front.isNotEmpty ? front.first : cameras.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted || _checking) return;
        setState(() {
          if (_promptIndex < prompts.length - 1) _promptIndex++;
        });
      });
    } catch (_) {
      // The demo can still complete without a physical camera.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _checking = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pop(const LivenessResult(passed: true, score: .96));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Liveness check'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller?.value.isInitialized == true)
            CameraPreview(controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Center(
            child: Container(
              width: 235,
              height: 310,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 4),
                borderRadius: BorderRadius.circular(120),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Live face verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prompts[_promptIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: PrimaryButton(
              label: _checking ? 'Checking...' : 'Complete demo check',
              icon: Icons.face_retouching_natural_rounded,
              onPressed: _checking ? null : _complete,
            ),
          ),
        ],
      ),
    );
  }
}
