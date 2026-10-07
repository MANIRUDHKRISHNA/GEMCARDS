// Legacy Material controls remain intentionally for this small, local form state.
// ignore_for_file: deprecated_member_use

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/kyc_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_card.dart';
import '../widgets/step_header.dart';
import 'camera_capture_screen.dart';
import 'liveness_screen.dart';

class KycFlowScreen extends StatefulWidget {
  const KycFlowScreen({super.key});

  @override
  State<KycFlowScreen> createState() => _KycFlowScreenState();
}

class _KycFlowScreenState extends State<KycFlowScreen> {
  final KycState kyc = KycState();
  final addressController = TextEditingController();
  int step = 1;
  bool submitting = false;

  static const countries = ['India', 'United Kingdom', 'United States'];
  static const documents = ['Passport', "Driver's License", 'National ID Card'];

  @override
  void dispose() {
    addressController.dispose();
    super.dispose();
  }

  Future<void> _captureDocument({required bool front}) async {
    final result = await Navigator.of(context).push<CameraCaptureResult>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          title: front ? 'Capture front' : 'Capture back',
          instruction: front
              ? 'Fit the front of your ID inside the frame'
              : 'Fit the back of your ID inside the frame',
          lensDirection: CameraLensDirection.back,
          runOcr: front,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      if (front) {
        kyc.frontCaptured = true;
        _applyOcr(result.ocrText);
      } else {
        kyc.backCaptured = true;
      }
    });
  }

  void _applyOcr(String text) {
    if (text.trim().isEmpty) return;
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.length >= 3)
        .toList();

    if (lines.isNotEmpty) {
      final candidate = lines.first.replaceAll(RegExp(r'[^A-Za-z .]'), '').trim();
      if (candidate.length >= 3) kyc.fullName = candidate;
    }

    final idCandidate = lines.firstWhere(
      (line) => RegExp(r'[A-Z0-9]{4,}').hasMatch(line),
      orElse: () => kyc.idNumber,
    );
    final cleanedId = idCandidate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleanedId.length >= 6) {
      kyc.idNumber = cleanedId.length > 16 ? cleanedId.substring(0, 16) : cleanedId;
    }

    final dateMatch = RegExp(
      r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})\b',
    ).firstMatch(text);
    if (dateMatch != null) kyc.dob = dateMatch.group(0)!;
  }

  Future<void> _runLiveness() async {
    final result = await Navigator.of(context).push<LivenessResult>(
      MaterialPageRoute(builder: (_) => const LivenessScreen()),
    );
    if (!mounted || result == null) return;
    setState(() {
      kyc.livenessPassed = result.passed;
      kyc.faceMatchScore = result.score;
    });
  }

  Future<void> _pickAddressDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (!mounted || result.isEmpty) return;
    setState(() => kyc.addressDocument = result.single.name);
  }

  bool _canContinue() {
    switch (step) {
      case 1:
        return kyc.country.isNotEmpty && kyc.documentType.isNotEmpty;
      case 2:
        return kyc.frontCaptured && kyc.backCaptured;
      case 3:
        return kyc.livenessPassed;
      case 4:
        return addressController.text.trim().isNotEmpty && kyc.addressDocument.isNotEmpty;
      case 5:
        return kyc.termsAccepted;
      default:
        return true;
    }
  }

  Future<void> _continue() async {
    if (!_canContinue()) return;
    if (step == 5) {
      setState(() => submitting = true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        submitting = false;
        step = 6;
      });
      return;
    }
    if (step < 6) setState(() => step++);
  }

  void _reset() {
    setState(() {
      kyc.reset();
      addressController.clear();
      step = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jiffy KYC',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                color: AppTheme.accentDark,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(step: step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: step == 6
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: PrimaryButton(
                  label: step == 5 ? 'Submit for Verification' : 'Continue',
                  icon: step == 5 ? Icons.verified_user_rounded : null,
                  onPressed: submitting ? null : (_canContinue() ? _continue : null),
                ),
              ),
            ),
    );
  }

  Widget _buildStep() {
    switch (step) {
      case 1:
        return _buildIdentity();
      case 2:
        return _buildDocument();
      case 3:
        return _buildSelfie();
      case 4:
        return _buildAddress();
      case 5:
        return _buildReview();
      case 6:
        return _buildOutcome();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          step: 1,
          title: 'Verify your identity',
          subtitle: 'A secure digital KYC journey. It should take around 2 minutes.',
        ),
        const SizedBox(height: 24),
        const StatusCard(
          icon: Icons.lock_outline_rounded,
          title: 'Your information stays protected',
          message: 'This demo never asks for real identity credentials. Production verification must use approved regulated providers.',
        ),
        const SizedBox(height: 22),
        const Text('Country / issue region', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: kyc.country,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.public_rounded)),
          items: countries
              .map((country) => DropdownMenuItem(value: country, child: Text(country)))
              .toList(),
          onChanged: (value) => setState(() => kyc.country = value ?? kyc.country),
        ),
        const SizedBox(height: 24),
        const Text('Choose your identity document', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...documents.map(
          (document) => RadioListTile<String>(
            value: document,
            groupValue: kyc.documentType,
            title: Text(document),
            onChanged: (value) => setState(() => kyc.documentType = value ?? kyc.documentType),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.accentDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDocument() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          step: 2,
          title: 'Capture your ID',
          subtitle: 'Use good lighting. Keep the document flat, visible and free from glare.',
        ),
        const SizedBox(height: 22),
        _CaptureTile(
          title: 'Front of document',
          complete: kyc.frontCaptured,
          onTap: () => _captureDocument(front: true),
        ),
        const SizedBox(height: 12),
        _CaptureTile(
          title: 'Back of document',
          complete: kyc.backCaptured,
          onTap: () => _captureDocument(front: false),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Name', value: kyc.fullName),
              _DetailRow(label: 'Date of birth', value: kyc.dob),
              _DetailRow(label: 'ID number', value: kyc.idNumber),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'OCR values are editable in the next production iteration. For this prototype they are shown as demo-safe values.',
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildSelfie() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          step: 3,
          title: 'Confirm it’s really you',
          subtitle: 'A short liveness check helps prevent simple photo or replay attacks.',
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                width: 150,
                height: 195,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent, width: 3),
                  borderRadius: BorderRadius.circular(90),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white24, size: 90),
              ),
              const SizedBox(height: 18),
              Text(
                kyc.livenessPassed
                    ? 'Liveness check passed'
                    : 'Position your face inside the oval',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Demo prompts: look straight, turn left, turn right, blink.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (kyc.livenessPassed)
          StatusCard(
            icon: Icons.face_rounded,
            title: 'Face match: ${(kyc.faceMatchScore * 100).toStringAsFixed(0)}%',
            message: 'Prototype result only. A real implementation must use an approved liveness and face-match provider.',
          )
        else
          PrimaryButton(
            label: 'Start liveness check',
            icon: Icons.camera_front_rounded,
            onPressed: _runLiveness,
          ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () => _showAccessibilityFallback(),
          icon: const Icon(Icons.accessibility_new_rounded),
          label: const Text('I cannot complete the movement prompt'),
        ),
      ],
    );
  }

  void _showAccessibilityFallback() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accessibility path', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('In production, this should route the customer to an alternative regulated verification method instead of forcing a physical movement.'),
            SizedBox(height: 12),
            Text('Prototype behaviour: contact-assisted verification would be offered here.'),
          ],
        ),
      ),
    );
  }

  Widget _buildAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          step: 4,
          title: 'Confirm your address',
          subtitle: 'Upload a recent proof of address and provide the address you want associated with the account.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: addressController,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Address',
            hintText: 'House number, street, city, state, PIN',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickAddressDocument,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
              color: AppTheme.surface,
            ),
            child: Row(
              children: [
                const Icon(Icons.upload_file_rounded, color: AppTheme.accentDark, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Proof of address', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        kyc.addressDocument.isEmpty
                            ? 'Utility bill, bank statement or tax document'
                            : kyc.addressDocument,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          step: 5,
          title: 'Review and declare',
          subtitle: 'Check the details before the verification request is submitted.',
        ),
        const SizedBox(height: 24),
        _ReviewCard(
          title: 'Identity',
          children: [
            _DetailRow(label: 'Document', value: kyc.documentType),
            _DetailRow(label: 'Name', value: kyc.fullName),
            _DetailRow(label: 'DOB', value: kyc.dob),
            _DetailRow(label: 'ID', value: kyc.idNumber),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          title: 'Verification',
          children: [
            _DetailRow(label: 'Document capture', value: kyc.frontCaptured && kyc.backCaptured ? 'Complete' : 'Incomplete'),
            _DetailRow(label: 'Liveness', value: kyc.livenessPassed ? 'Passed' : 'Incomplete'),
            _DetailRow(label: 'Address proof', value: kyc.addressDocument.isEmpty ? 'Missing' : 'Attached'),
          ],
        ),
        const SizedBox(height: 18),
        CheckboxListTile(
          value: kyc.pepDeclared,
          onChanged: (value) => setState(() => kyc.pepDeclared = value ?? false),
          contentPadding: EdgeInsets.zero,
          title: const Text('I confirm the politically exposed person declaration is accurate.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: kyc.termsAccepted,
          onChanged: (value) => setState(() => kyc.termsAccepted = value ?? false),
          contentPadding: EdgeInsets.zero,
          title: const Text('I accept the terms and consent to this verification process.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildOutcome() {
    return Column(
      children: [
        const SizedBox(height: 32),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: .2, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 62, color: AppTheme.accentDark),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Verification complete',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const Text(
          'This is a simulated pass for the prototype. No real KYC decision has been made.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 24),
        const StatusCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Demo account tier unlocked',
          message: 'Basic digital onboarding complete. Production limits, risk checks and account activation belong behind the approved backend flow.',
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Start again',
          icon: Icons.restart_alt_rounded,
          onPressed: _reset,
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(6, (index) {
          final active = index + 1 <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 5 ? 0 : 5),
              decoration: BoxDecoration(
                color: active ? AppTheme.accentDark : AppTheme.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.title, required this.complete, required this.onTap});

  final String title;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: complete ? AppTheme.accent.withValues(alpha: .10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: complete ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: complete ? AppTheme.accent : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                complete ? Icons.check_rounded : Icons.document_scanner_outlined,
                color: complete ? Colors.white : AppTheme.accentDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text(complete ? 'Captured' : 'Capture', style: const TextStyle(color: AppTheme.accentDark, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
