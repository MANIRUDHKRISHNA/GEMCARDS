// Legacy Material controls remain intentionally for this small, local form state.
// ignore_for_file: deprecated_member_use

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/kyc_state.dart';
import '../repositories/kyc_repository.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_header.dart';
import 'camera_capture_screen.dart';
import 'liveness_screen.dart';

class KycFlowScreen extends StatefulWidget {
  const KycFlowScreen({this.repository, super.key});

  final KycRepository? repository;

  @override
  State<KycFlowScreen> createState() => _KycFlowScreenState();
}

class _KycFlowScreenState extends State<KycFlowScreen> {
  final KycState kyc = KycState();
  late final KycRepository repository =
      widget.repository ?? ResilientKycRepository();
  final addressController = TextEditingController();
  final addressFocusNode = FocusNode();
  int step = 1;
  bool submitting = false;
  bool _addressFocused = false;

  static const countries = ['India', 'United Kingdom', 'United States'];
  static const documents = ['Passport', "Driver's License", 'National ID'];
  static const _sampleAddresses = [
    '42 Residency Road, Ashok Nagar, Bengaluru 560025',
    '18 Park Street, Kolkata 700016',
    '7 Linking Road, Bandra West, Mumbai 400050',
  ];

  @override
  void initState() {
    super.initState();
    addressFocusNode.addListener(() {
      if (mounted) setState(() => _addressFocused = addressFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    addressController.dispose();
    addressFocusNode.dispose();
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
    if (front && mounted) _editOcrDetails(result.ocrText.isEmpty);
    if (front) kyc.journeyStage = KycJourneyStage.documentFront;
    if (!front) {
      kyc.journeyStage = KycJourneyStage.documentBack;
      await repository.saveDocument(kyc);
      kyc.journeyStage = KycJourneyStage.documentVerified;
    }
  }

  Future<void> _editOcrDetails(bool failed) async {
    final name = TextEditingController(text: kyc.fullName);
    final dob = TextEditingController(text: kyc.dob);
    final id = TextEditingController(text: kyc.idNumber);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failed
                      ? "We couldn't read the document automatically"
                      : 'Review your details',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 7),
                Text(
                  failed
                      ? 'Enter the details manually to continue this demo.'
                      : 'Check the extracted information and make any corrections.',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dob,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: id,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Document number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Confirm details',
                  onPressed: () {
                    setState(() {
                      kyc.fullName = name.text.trim();
                      kyc.dob = dob.text.trim();
                      kyc.idNumber = id.text.trim();
                    });
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    dob.dispose();
    id.dispose();
  }

  void _applyOcr(String text) {
    if (text.trim().isEmpty) return;
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.length >= 3)
        .toList();

    if (lines.isNotEmpty) {
      final candidate = lines.first
          .replaceAll(RegExp(r'[^A-Za-z .]'), '')
          .trim();
      if (candidate.length >= 3) kyc.fullName = candidate;
    }

    final idCandidate = lines.firstWhere(
      (line) => RegExp(r'[A-Z0-9]{4,}').hasMatch(line),
      orElse: () => kyc.idNumber,
    );
    final cleanedId = idCandidate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleanedId.length >= 6) {
      kyc.idNumber = cleanedId.length > 16
          ? cleanedId.substring(0, 16)
          : cleanedId;
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
      kyc.selfieCaptured = result.passed;
      kyc.faceMatchScore = result.score;
      kyc.journeyStage = KycJourneyStage.livenessVerified;
    });
    await repository.saveSelfie(kyc);
  }

  Future<void> _pickAddressDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (!mounted || result.isEmpty) return;
    final file = result.single;
    final size = await file.length() ?? 0;
    if (!mounted) return;
    if (size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a file smaller than 10 MB.')),
      );
      return;
    }
    setState(() {
      kyc.addressDocument = file.name;
      kyc.addressDocumentBytes = size;
    });
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
        return addressController.text.trim().isNotEmpty &&
            kyc.addressDocument.isNotEmpty;
      case 5:
        return kyc.declarationsComplete;
      default:
        return true;
    }
  }

  String get _maskedId {
    final id = kyc.idNumber;
    if (id.length <= 4) return id;
    return '•••• ${id.substring(id.length - 4)}';
  }

  String _displayValue(String value, {String fallback = 'Not provided'}) =>
      value.isEmpty ? fallback : value;

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _continue() async {
    if (!_canContinue()) return;
    if (step == 1 && kyc.sessionId == null) {
      setState(() => submitting = true);
      try {
        kyc.sessionId = await repository.startSession(
          country: kyc.country,
          documentType: kyc.documentType,
        );
      } catch (_) {
        kyc.sessionId = 'offline-demo';
      }
      if (!mounted) return;
      setState(() {
        submitting = false;
        step = 2;
      });
      kyc.journeyStage = KycJourneyStage.identityComplete;
      return;
    }
    if (step == 4) {
      kyc.address = addressController.text.trim();
      kyc.journeyStage = KycJourneyStage.addressVerified;
      setState(() => submitting = true);
      await repository.saveAddress(kyc);
      if (!mounted) return;
      setState(() {
        submitting = false;
        step++;
      });
      return;
    }
    if (step == 5) {
      setState(() {
        submitting = true;
        kyc.processingStatus = ProcessingStatus.processing;
      });
      kyc.journeyStage = KycJourneyStage.processing;
      final result = await repository.submit(kyc);
      if (!mounted) return;
      setState(() {
        submitting = false;
        kyc.processingStatus = result;
        kyc.journeyStage = result == ProcessingStatus.verified
            ? KycJourneyStage.verified
            : KycJourneyStage.underReview;
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        leading: step > 1 && step < 6
            ? IconButton(
                tooltip: 'Go back',
                onPressed: () => setState(() => step--),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GEMCARDS'),
            Text(
              'Customer onboarding',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: AppTheme.accentDark,
                ),
                const SizedBox(width: 5),
                Text(
                  'DEMO',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.accentDark),
                ),
              ],
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.025, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(step), child: _buildStep()),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: step == 6
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  10,
                  24,
                  bottomInset > 0 ? 8 : 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      label: submitting
                          ? 'Please wait…'
                          : step == 5
                          ? 'Submit for verification'
                          : step == 1
                          ? 'Continue to verification'
                          : 'Continue',
                      icon: step == 5 ? Icons.verified_user_rounded : null,
                      onPressed: submitting
                          ? null
                          : (_canContinue() ? _continue : null),
                    ),
                    if (step < 5) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Your progress is saved on this device',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
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
          title: 'Let’s get to know you',
          subtitle: 'Choose your document and the country that issued it.',
        ),
        const SizedBox(height: 28),
        Text('Issuing country', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: kyc.country,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.public_rounded),
            hintText: 'Select a country',
          ),
          items: countries
              .map(
                (country) =>
                    DropdownMenuItem(value: country, child: Text(country)),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => kyc.country = value ?? kyc.country),
        ),
        const SizedBox(height: 30),
        Text(
          'Identity document',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          'Select the document you’ll use to verify your identity.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        ...documents.map((document) {
          final icon = switch (document) {
            'Passport' => Icons.menu_book_outlined,
            "Driver's License" => Icons.directions_car_outlined,
            _ => Icons.badge_outlined,
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DocumentChoiceTile(
              title: document,
              icon: icon,
              selected: kyc.documentType == document,
              onTap: () => setState(() => kyc.documentType = document),
            ),
          );
        }),
        const SizedBox(height: 8),
        const _InlineNotice(
          icon: Icons.lock_outline_rounded,
          message:
              'Demo flow only. Do not enter or capture real identity documents.',
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
          title: 'Verify your document',
          subtitle:
              'Place the document inside the frame. Make sure all four edges are visible.',
        ),
        const SizedBox(height: 24),
        _DocumentPreview(
          frontCaptured: kyc.frontCaptured,
          onCapture: () => _captureDocument(front: !kyc.frontCaptured),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _CaptureTile(
                title: 'Front',
                complete: kyc.frontCaptured,
                onTap: () => _captureDocument(front: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CaptureTile(
                title: 'Back',
                complete: kyc.backCaptured,
                onTap: () => _captureDocument(front: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _InlineNotice(
          icon: Icons.light_mode_outlined,
          message: 'Avoid glare and keep your document steady.',
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              kyc.frontCaptured = true;
              kyc.backCaptured = true;
              if (kyc.fullName.isEmpty) kyc.fullName = 'Alex Morgan';
              if (kyc.dob.isEmpty) kyc.dob = '14 Aug 2000';
              if (kyc.idNumber.isEmpty) kyc.idNumber = 'DEMO 4821';
            }),
            icon: const Icon(Icons.accessibility_new_rounded, size: 19),
            label: const Text('Camera unavailable? Use demo capture'),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Review extracted details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () => _editOcrDetails(false),
              child: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _ReviewCard(
          title: 'Document details',
          children: [
            _DetailRow(
              label: 'Name',
              value: kyc.fullName.isEmpty ? 'Pending capture' : kyc.fullName,
            ),
            _DetailRow(
              label: 'Date of birth',
              value: kyc.dob.isEmpty ? 'Pending capture' : kyc.dob,
            ),
            _DetailRow(
              label: 'Document number',
              value: kyc.idNumber.isEmpty ? 'Pending capture' : _maskedId,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Details are read automatically where possible. Check them before continuing.',
          style: Theme.of(context).textTheme.bodySmall,
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
          title: 'A quick face check',
          subtitle: 'Follow a few simple prompts to confirm your identity.',
        ),
        const SizedBox(height: 22),
        _LivenessPreview(complete: kyc.livenessPassed),
        const SizedBox(height: 20),
        if (kyc.livenessPassed)
          _VerificationSummary(
            icon: Icons.verified_user_outlined,
            title: 'Liveness verified',
            status: 'DEMO CHECK',
            detail:
                'Identity match simulated • ${(kyc.faceMatchScore * 100).toStringAsFixed(0)}% demo match',
          )
        else
          PrimaryButton(
            label: 'Start face check',
            icon: Icons.camera_front_rounded,
            onPressed: _runLiveness,
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showAccessibilityFallback,
            icon: const Icon(Icons.accessibility_new_rounded, size: 18),
            label: const Text('Need an accessible alternative?'),
          ),
        ),
      ],
    );
  }

  void _showAccessibilityFallback() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.accessibility_new_rounded,
          color: AppTheme.accentDark,
        ),
        title: const Text('Accessible alternative'),
        content: const SingleChildScrollView(
          child: Text(
            'In production, this offers an alternative verification method. For this prototype, continue with a clearly simulated assisted check.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              setState(() {
                kyc.selfieCaptured = true;
                kyc.livenessPassed = true;
                kyc.faceMatchScore = .96;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Continue with demo check'),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      ),
    );
  }

  Widget _buildAddress() {
    final query = addressController.text.trim().toLowerCase();
    final suggestions = _sampleAddresses
        .where(
          (address) => query.isEmpty || address.toLowerCase().contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          step: 4,
          title: 'Where can we reach you?',
          subtitle:
              'Add your current residential address and a recent proof of address.',
        ),
        const SizedBox(height: 26),
        Text(
          'Residential address',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: addressController,
          focusNode: addressFocusNode,
          textInputAction: TextInputAction.done,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'House, street, city, postal code',
            alignLabelWithHint: false,
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        if (_addressFocused && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: .05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var index = 0; index < suggestions.length; index++)
                  Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.place_outlined,
                          color: AppTheme.accentDark,
                        ),
                        title: Text(
                          suggestions[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        onTap: () {
                          addressController.text = suggestions[index];
                          addressController.selection = TextSelection.collapsed(
                            offset: addressController.text.length,
                          );
                          addressFocusNode.unfocus();
                          setState(() {});
                        },
                      ),
                      if (index < suggestions.length - 1)
                        const Divider(height: 1, indent: 56),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        Text(
          'Proof of address',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          'PDF, JPG or PNG • Maximum 10 MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: kyc.addressDocument.isEmpty
              ? 'Upload proof of address, PDF JPG or PNG up to 10 megabytes'
              : 'Replace uploaded file ${kyc.addressDocument}',
          child: InkWell(
            onTap: _pickAddressDocument,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kyc.addressDocument.isEmpty
                      ? AppTheme.border
                      : AppTheme.success.withValues(alpha: .5),
                ),
                color: kyc.addressDocument.isEmpty
                    ? AppTheme.surface
                    : AppTheme.success.withValues(alpha: .05),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      kyc.addressDocument.isEmpty
                          ? Icons.upload_file_rounded
                          : Icons.check_rounded,
                      color: kyc.addressDocument.isEmpty
                          ? AppTheme.accentDark
                          : AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kyc.addressDocument.isEmpty
                              ? 'Choose a document'
                              : kyc.addressDocument,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          kyc.addressDocument.isEmpty
                              ? 'Utility bill, bank statement or tax document'
                              : _formatFileSize(kyc.addressDocumentBytes ?? 0),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    kyc.addressDocument.isEmpty
                        ? Icons.arrow_upward_rounded
                        : Icons.check_circle_rounded,
                    color: kyc.addressDocument.isEmpty
                        ? AppTheme.accentDark
                        : AppTheme.success,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (kyc.addressDocument.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() {
              kyc.addressDocument = '';
              kyc.addressDocumentBytes = null;
            }),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Replace or remove file'),
          ),
        const SizedBox(height: 10),
        const _InlineNotice(
          icon: Icons.info_outline_rounded,
          message: 'Use a recent bill, bank statement or tax document.',
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
          title: 'A final look',
          subtitle: 'Review your details and confirm before submitting.',
        ),
        const SizedBox(height: 22),
        _ReviewCard(
          title: 'IDENTITY',
          status: 'READY',
          children: [
            _DetailRow(label: 'Name', value: _displayValue(kyc.fullName)),
            _DetailRow(label: 'Date of birth', value: _displayValue(kyc.dob)),
            _DetailRow(label: 'Document', value: kyc.documentType),
            _DetailRow(label: 'ID number', value: _displayValue(_maskedId)),
            _DetailRow(
              label: 'Capture',
              value: kyc.frontCaptured && kyc.backCaptured
                  ? 'Front & back ready'
                  : 'Incomplete',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          title: 'ADDRESS',
          status: 'READY',
          children: [
            _DetailRow(
              label: 'Address',
              value: _displayValue(kyc.address, fallback: 'Not provided'),
            ),
            _DetailRow(
              label: 'Proof of address',
              value: kyc.addressDocument.isEmpty
                  ? 'Not attached'
                  : kyc.addressDocument,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          title: 'FACE VERIFICATION',
          status: 'DEMO CHECK',
          children: [
            _DetailRow(
              label: 'Liveness',
              value: kyc.livenessPassed ? 'Verified' : 'Incomplete',
            ),
            _DetailRow(
              label: 'Match status',
              value:
                  'Simulated • ${(kyc.faceMatchScore * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'DECLARATIONS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        _DeclarationRow(
          value: kyc.accuracyDeclared,
          text: 'I confirm the information provided is accurate.',
          onChanged: (value) =>
              setState(() => kyc.accuracyDeclared = value ?? false),
        ),
        _DeclarationRow(
          value: kyc.pepDeclared,
          text:
              'I am not a politically exposed person (prototype declaration).',
          onChanged: (value) =>
              setState(() => kyc.pepDeclared = value ?? false),
        ),
        _DeclarationRow(
          value: kyc.termsAccepted,
          text: 'I agree to the terms and conditions.',
          onChanged: (value) =>
              setState(() => kyc.termsAccepted = value ?? false),
        ),
        const SizedBox(height: 10),
        const _InlineNotice(
          icon: Icons.info_outline_rounded,
          message: 'Verification results shown here are for demo purposes.',
        ),
      ],
    );
  }

  Widget _buildOutcome() {
    final isVerified = kyc.processingStatus == ProcessingStatus.verified;
    final isUnderReview =
        kyc.processingStatus == ProcessingStatus.underReview ||
        kyc.processingStatus == ProcessingStatus.processing;
    final isActionRequired =
        kyc.processingStatus == ProcessingStatus.actionRequired;
    final title = switch (kyc.processingStatus) {
      ProcessingStatus.verified => "You're verified",
      ProcessingStatus.underReview ||
      ProcessingStatus.processing => 'Verification in progress',
      ProcessingStatus.actionRequired => 'A little more is needed',
      ProcessingStatus.failed => 'We couldn’t verify your details',
      ProcessingStatus.draft => 'Verification not submitted',
    };
    final message = switch (kyc.processingStatus) {
      ProcessingStatus.verified => 'Your GEMCARDS onboarding is complete.',
      ProcessingStatus.underReview || ProcessingStatus.processing =>
        'We’re reviewing your information. We’ll update you when it’s ready.',
      ProcessingStatus.actionRequired =>
        kyc.errorMessage ?? 'Your document image is too blurry.',
      ProcessingStatus.failed =>
        kyc.errorMessage ?? 'We couldn’t complete verification this time.',
      ProcessingStatus.draft => 'Submit your details to continue.',
    };
    final statusColor = isVerified
        ? AppTheme.success
        : isActionRequired || kyc.processingStatus == ProcessingStatus.failed
        ? AppTheme.warning
        : AppTheme.accentDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 28),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: .75, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: isUnderReview
                ? SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  )
                : Icon(
                    isVerified
                        ? Icons.check_rounded
                        : Icons.priority_high_rounded,
                    size: 48,
                    color: statusColor,
                  ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'ONBOARDING STATUS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isVerified
                    ? Icons.credit_card_outlined
                    : Icons.schedule_rounded,
                color: AppTheme.accentDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified
                          ? 'Card application ready'
                          : isUnderReview
                          ? 'Estimated response'
                          : 'Next step',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isVerified
                          ? 'Continue to the next step in your card application.'
                          : isUnderReview
                          ? 'Within 2 hours'
                          : 'Review your details and try again.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (isVerified)
          PrimaryButton(
            label: 'Go to dashboard',
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const GemcardsDashboardScreen(),
              ),
              (_) => false,
            ),
          )
        else if (isActionRequired ||
            kyc.processingStatus == ProcessingStatus.failed) ...[
          PrimaryButton(
            label: 'Try again',
            onPressed: () => setState(() {
              step = 2;
              kyc.frontCaptured = false;
              kyc.backCaptured = false;
              kyc.processingStatus = ProcessingStatus.draft;
            }),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => step = 5),
            child: const Text('Return to review'),
          ),
        ] else ...[
          const _InlineNotice(
            icon: Icons.science_outlined,
            message:
                'This is a simulated demo result, not a real identity decision.',
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: _reset, child: const Text('Start a new demo')),
        ],
      ],
    );
  }
}

class _DocumentChoiceTile extends StatelessWidget {
  const _DocumentChoiceTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title${selected ? ', selected' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentDark.withValues(alpha: .045)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.accentDark : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentDark : AppTheme.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppTheme.accentDark,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentDark : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.accentDark : AppTheme.border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.accentDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.frontCaptured,
    required this.onCapture,
  });

  final bool frontCaptured;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: frontCaptured
          ? 'Front of document captured. Tap to capture the back.'
          : 'Document camera preview. Tap to capture the front.',
      child: InkWell(
        onTap: onCapture,
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 1.48,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border.withValues(alpha: .8)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: frontCaptured
                            ? AppTheme.success
                            : AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          frontCaptured
                              ? 'Front captured'
                              : 'Searching for document',
                          key: ValueKey(frontCaptured),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppTheme.ink),
                        ),
                      ),
                    ),
                    if (frontCaptured)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: AppTheme.success,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DocumentCornersPainter(
                            color: frontCaptured
                                ? AppTheme.success
                                : AppTheme.accentDark,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: .75,
                        child: AspectRatio(
                          aspectRatio: 1.65,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.ink.withValues(alpha: .06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 35,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 24,
                                    color: AppTheme.muted,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SAMPLE DOCUMENT',
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppTheme.accentDark,
                                              fontSize: 8,
                                              letterSpacing: .4,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 4,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: AppTheme.border,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      FractionallySizedBox(
                                        widthFactor: .7,
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppTheme.border,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  frontCaptured
                      ? 'Tap to capture the reverse side'
                      : 'Tap to open camera',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentCornersPainter extends CustomPainter {
  const _DocumentCornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const inset = 2.0;
    const length = 20.0;
    final path = Path()
      ..moveTo(inset, length)
      ..lineTo(inset, inset)
      ..lineTo(length, inset)
      ..moveTo(size.width - length, inset)
      ..lineTo(size.width - inset, inset)
      ..lineTo(size.width - inset, length)
      ..moveTo(inset, size.height - length)
      ..lineTo(inset, size.height - inset)
      ..lineTo(length, size.height - inset)
      ..moveTo(size.width - length, size.height - inset)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - inset, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DocumentCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LivenessPreview extends StatelessWidget {
  const _LivenessPreview({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    const prompts = ['Look straight', 'Turn left', 'Turn right', 'Blink once'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FACE CHECK',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(label: complete ? 'COMPLETE' : 'DEMO', dark: true),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 218,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 156,
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: complete ? AppTheme.success : AppTheme.accent,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      complete
                          ? Icons.check_rounded
                          : Icons.person_outline_rounded,
                      color: Colors.white.withValues(alpha: .78),
                      size: 72,
                    ),
                  ),
                  if (!complete) const _AnimatedScanLine(),
                ],
              ),
            ),
          ),
          Text(
            complete ? 'Liveness verified' : 'Center your face in the frame',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              for (var index = 0; index < prompts.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: complete
                              ? AppTheme.success
                              : Colors.white.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: complete
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        prompts[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedScanLine extends StatefulWidget {
  const _AnimatedScanLine();

  @override
  State<_AnimatedScanLine> createState() => _AnimatedScanLineState();
}

class _AnimatedScanLineState extends State<_AnimatedScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Positioned(
        left: 18,
        right: 18,
        top: 28 + 145 * _controller.value,
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
    );
  }
}

class _VerificationSummary extends StatelessWidget {
  const _VerificationSummary({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.success.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _StatusChip(label: status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .12)
            : AppTheme.accentDark.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: dark ? Colors.white : AppTheme.accentDark,
          fontSize: 10,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _DeclarationRow extends StatelessWidget {
  const _DeclarationRow({
    required this.value,
    required this.text,
    required this.onChanged,
  });

  final bool value;
  final String text;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: text,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GemcardsDashboardScreen extends StatelessWidget {
  const GemcardsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GEMCARDS'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Your customer onboarding is complete.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.accentDark,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.credit_card_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 25),
                    Text(
                      'CARD APPLICATION',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Ready for your next step',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _InlineNotice(
                icon: Icons.science_outlined,
                message:
                    'Demo dashboard. Verification and card readiness are simulated.',
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Start a new onboarding',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const KycFlowScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(6, (index) {
          final active = index + 1 <= step;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: index == 5 ? 0 : 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: active ? AppTheme.accentDark : AppTheme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.title,
    required this.complete,
    required this.onTap,
  });

  final String title;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: complete
              ? AppTheme.success.withValues(alpha: .05)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: complete
                ? AppTheme.success.withValues(alpha: .45)
                : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  complete
                      ? Icons.check_circle_rounded
                      : Icons.document_scanner_outlined,
                  color: complete ? AppTheme.success : AppTheme.accentDark,
                  size: 20,
                ),
                const Spacer(),
                Icon(
                  complete
                      ? Icons.refresh_rounded
                      : Icons.arrow_forward_rounded,
                  color: AppTheme.muted,
                  size: 17,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              complete ? 'Captured' : 'Tap to capture',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: complete ? AppTheme.success : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.children, this.status});

  final String title;
  final List<Widget> children;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withValues(alpha: .75)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (status != null) _StatusChip(label: status!),
            ],
          ),
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
          Expanded(
            flex: 4,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
