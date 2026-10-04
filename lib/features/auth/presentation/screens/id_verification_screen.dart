import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

/// Minimum age accepted by the `submit_id_verification` RPC.
const int idVerificationMinAge = 10;

/// Below this age a guardian's CNI and MoMo number are also required.
const int idVerificationGuardianAge = 15;

/// From this age the user's own CNI is required instead of a school ID.
const int idVerificationAdultAge = 18;

final RegExp _cameroonMobile = RegExp(r'^6[0-9]{8}$');

/// Whole years between [dob] and [now].
int ageOn(DateTime dob, DateTime now) {
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  return age;
}

/// Strips spaces and an optional `+237`/`237` prefix.
String normalizeCameroonPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[\s+\-]'), '');
  if (digits.startsWith('237') && digits.length == 12) {
    digits = digits.substring(3);
  }
  return digits;
}

/// Lets a user submit ID photos for admin review, and shows the review status.
///
/// - 10–14: school ID + guardian's CNI + guardian MoMo number
/// - 15–17: school ID
/// - 18+: CNI
class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  final _phoneController = TextEditingController();
  DateTime? _dob;
  final List<Uint8List?> _photos = [null, null];

  @override
  void initState() {
    super.initState();
    // The cached status may predate an admin decision.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().refreshUser();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  int? get _age => _dob == null ? null : ageOn(_dob!, DateTime.now());

  bool get _tooYoung => _age != null && _age! < idVerificationMinAge;

  bool get _needsGuardian =>
      _age != null && !_tooYoung && _age! < idVerificationGuardianAge;

  int get _requiredPhotos => _needsGuardian ? 2 : 1;

  bool get _phoneValid =>
      _cameroonMobile.hasMatch(normalizeCameroonPhone(_phoneController.text));

  bool get _canSubmit {
    if (_age == null || _tooYoung) return false;
    for (var i = 0; i < _requiredPhotos; i++) {
      if (_photos[i] == null) return false;
    }
    return !_needsGuardian || _phoneValid;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 16, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickPhoto(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.idVerifyCamera),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.idVerifyGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photos[index] = bytes);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<AuthViewModel>();
    final documents = _photos.take(_requiredPhotos).whereType<Uint8List>();
    final ok = await viewModel.submitIdVerification(
      dateOfBirth: _dob!,
      documents: documents.toList(),
      guardianPhone: _needsGuardian
          ? normalizeCameroonPhone(_phoneController.text)
          : null,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.idVerifySubmitted
              : l10n.idVerifyError(viewModel.errorMessage ?? ''),
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<AuthViewModel>();
    final user = viewModel.currentUser;
    final status = user?.idVerificationStatus ?? 'unverified';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.idVerifyTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: switch (status) {
          'verified' => _StatusCard(
            icon: Icons.verified,
            color: Colors.green,
            title: l10n.idVerifyVerifiedTitle,
            body: l10n.idVerifyVerifiedBody,
          ),
          'pending' => _StatusCard(
            icon: Icons.hourglass_top,
            color: Colors.orange,
            title: l10n.idVerifyPendingTitle,
            body: l10n.idVerifyPendingBody,
          ),
          _ => _buildForm(context, l10n, user, viewModel.isSubmittingId),
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    User? user,
    bool submitting,
  ) {
    final rejectionReason = user?.idRejectionReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user?.idVerificationStatus == 'rejected') ...[
          _StatusCard(
            icon: Icons.error_outline,
            color: Colors.red,
            title: l10n.idVerifyRejectedTitle,
            body: [
              if (rejectionReason != null && rejectionReason.isNotEmpty)
                l10n.idVerifyRejectedReason(rejectionReason),
              l10n.idVerifyRejectedBody,
            ].join('\n'),
          ),
          const SizedBox(height: 24),
        ],
        Text(l10n.idVerifySubtitle, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        InkWell(
          onTap: submitting ? null : _pickDob,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.idVerifyDobLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _dob == null
                  ? l10n.idVerifyDobHint
                  : MaterialLocalizations.of(context).formatMediumDate(_dob!),
            ),
          ),
        ),
        if (_tooYoung) ...[
          const SizedBox(height: 16),
          Text(
            l10n.idVerifyTooYoung,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        if (_age != null && !_tooYoung) ...[
          const SizedBox(height: 24),
          _PhotoSlot(
            label: _age! < idVerificationAdultAge
                ? l10n.idVerifyDocSchoolId
                : l10n.idVerifyDocCni,
            addLabel: l10n.idVerifyAddPhoto,
            bytes: _photos[0],
            onTap: submitting ? null : () => _pickPhoto(0),
          ),
          if (_needsGuardian) ...[
            const SizedBox(height: 16),
            _PhotoSlot(
              label: l10n.idVerifyDocGuardianCni,
              addLabel: l10n.idVerifyAddPhoto,
              bytes: _photos[1],
              onTap: submitting ? null : () => _pickPhoto(1),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              enabled: !submitting,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.idVerifyGuardianPhoneLabel,
                prefixText: '+237 ',
                errorText: _phoneController.text.isEmpty || _phoneValid
                    ? null
                    : l10n.idVerifyGuardianPhoneInvalid,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.idVerifyGuardianNote,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: !_canSubmit || submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    l10n.idVerifySubmit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.addLabel,
    required this.bytes,
    required this.onTap,
  });

  final String label;
  final String addLabel;
  final Uint8List? bytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_a_photo,
                          size: 32,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(addLabel),
                      ],
                    ),
                  )
                : Image.memory(bytes!, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}
