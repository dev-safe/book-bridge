import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

/// Values accepted by the `declare_age` RPC.
const String ageDeclarationAdult = 'adult';
const String ageDeclarationGuardian = 'guardian';

/// One-time 18+ / guardian self-declaration (interim, not a verification).
class AgeDeclarationScreen extends StatefulWidget {
  const AgeDeclarationScreen({super.key});

  @override
  State<AgeDeclarationScreen> createState() => _AgeDeclarationScreenState();
}

class _AgeDeclarationScreenState extends State<AgeDeclarationScreen> {
  String? _choice;
  bool _submitting = false;

  Future<void> _submit() async {
    final choice = _choice;
    if (choice == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _submitting = true);

    final ok = await context.read<AuthViewModel>().declareAge(choice);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      router.go('/home');
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.ageDeclarationError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _option(String value, String label) {
    final selected = _choice == value;
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? primary : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        title: Text(label),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ageDeclarationTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthViewModel>().signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: RadioGroup<String>(
          groupValue: _choice,
          onChanged: (value) {
            if (_submitting) return;
            setState(() => _choice = value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.ageDeclarationTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.ageDeclarationSubtitle,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _option(ageDeclarationAdult, l10n.ageDeclarationAdult),
              const SizedBox(height: 12),
              _option(ageDeclarationGuardian, l10n.ageDeclarationGuardian),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.ageDeclarationNotVerified,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _choice == null || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          l10n.ageDeclarationContinue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
