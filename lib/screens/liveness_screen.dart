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

class _LivenessScreenState extends State<LivenessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);
  CameraController? _controller;
  Timer? _timer;
  int _promptIndex = 0;
  bool _checking = false;
  bool _cameraUnavailable = false;

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
      if (mounted) setState(() => _cameraUnavailable = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _scanController.dispose();
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
        title: const Text('Face verification'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                '${_promptIndex + 1} of ${prompts.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller?.value.isInitialized == true)
            CameraPreview(controller!)
          else if (_cameraUnavailable)
            Container(color: AppTheme.ink)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                width: (constraints.maxWidth * .62)
                    .clamp(190.0, 260.0)
                    .toDouble(),
                height: (constraints.maxHeight * .48)
                    .clamp(230.0, 340.0)
                    .toDouble(),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _checking ? AppTheme.success : AppTheme.accent,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(160),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: .35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white54,
                      size: 72,
                    ),
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) => Positioned(
                        top: 30 + 180 * _scanController.value,
                        left: 22,
                        right: 22,
                        child: child!,
                      ),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: .7),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                color: AppTheme.ink.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Follow the prompts on screen',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        'DEMO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (_promptIndex + 1) / prompts.length,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_cameraUnavailable) ...[
                    const Text(
                      'Camera unavailable • demo check only',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    prompts[_promptIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 26,
            child: PrimaryButton(
              label: _checking ? 'Verifying…' : 'Complete demo check',
              icon: Icons.face_retouching_natural_rounded,
              onPressed: _checking ? null : _complete,
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 82,
            child: Center(
              child: TextButton(
                onPressed: _checking ? null : _complete,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Use accessible alternative'),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 5,
            child: SafeArea(
              top: false,
              child: Center(
                child: Text(
                  'Simulated demo check • no real identity decision',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
