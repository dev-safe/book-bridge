import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/locale_viewmodel.dart';

/// Sign Up screen for new user registration.
///
/// Provides a form for users to create a new account with email, password, and full name.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _localityController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _agreeToTerms = false;

  // Save reference to avoid accessing context in dispose()
  late AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    // Add a listener to handle UI feedback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authViewModel = context.read<AuthViewModel>();
      _authViewModel.addListener(_onAuthStateChanged);
    });
  }

  @override
  void dispose() {
    // Remove the listener before disposing using saved reference
    _authViewModel.removeListener(_onAuthStateChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    _localityController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    // Check if the widget is still mounted before accessing context
    if (!mounted) return;

    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.authState == AuthState.error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              authViewModel.errorMessage ??
                  AppLocalizations.of(context)!.unknownError,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      // Clear the error in the view model after showing it
      authViewModel.clearError();
    } else if (authViewModel.authState == AuthState.authenticated) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.signUpSuccess),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    size: 24,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/sign-in'),
                ),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.signUpButton,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Consumer<LocaleViewModel>(
                  builder: (context, localeViewModel, _) {
                    final isEnglish =
                        localeViewModel.locale.languageCode == 'en';
                    return GestureDetector(
                      onTap: () => localeViewModel.toggleLocale(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isEnglish ? '🇺🇸 EN' : '🇫🇷 FR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<AuthViewModel>(
        builder: (context, authViewModel, _) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.asset('assets/logo.png', height: 100),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.appMarketingHeadline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Form Fields
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Full Name
                        Text(
                          AppLocalizations.of(context)!.fullNameLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _fullNameController,
                          enabled: authViewModel.authState != AuthState.loading,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.fullNameHint,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return AppLocalizations.of(
                                context,
                              )!.fullNameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        Text(
                          AppLocalizations.of(context)!.emailLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          enabled: authViewModel.authState != AuthState.loading,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.emailHint,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return AppLocalizations.of(
                                context,
                              )!.emailRequired;
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            ).hasMatch(value!)) {
                              return AppLocalizations.of(context)!.emailInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Locality
                        Text(
                          AppLocalizations.of(context)!.localityLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _localityController,
                          enabled: authViewModel.authState != AuthState.loading,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.localityHint,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return AppLocalizations.of(
                                context,
                              )!.localityRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // WhatsApp Number
                        Text(
                          AppLocalizations.of(context)!.whatsappLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _whatsappController,
                          enabled: authViewModel.authState != AuthState.loading,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.whatsappHint,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return AppLocalizations.of(
                                context,
                              )!.whatsappRequired;
                            }
                            // Basic Cameroon phone number validation (9 digits)
                            if (!RegExp(r'^\d{9}$').hasMatch(value!)) {
                              return AppLocalizations.of(
                                context,
                              )!.whatsappInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        Text(
                          AppLocalizations.of(context)!.passwordLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          enabled: authViewModel.authState != AuthState.loading,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.passwordRequirement,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 15,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return AppLocalizations.of(
                                context,
                              )!.passwordRequired;
                            }
                            if (value!.length < 6) {
                              return AppLocalizations.of(
                                context,
                              )!.passwordTooShort;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Terms & Conditions Checkbox Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: GestureDetector(
                                  onTap: () => context.push('/terms'),
                                  child: RichText(
                                    text: TextSpan(
                                      text: 'I agree to the ',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Terms & Conditions',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' and trust guidelines.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Sign Up button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                authViewModel.authState == AuthState.loading
                                ? null
                                : () async {
                                    FocusScope.of(context).unfocus();
                                    if (!(_formKey.currentState?.validate() ??
                                        false)) {
                                      return;
                                    }
                                    if (!_agreeToTerms) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Please read and agree to the Terms & Conditions before signing up.',
                                            ),
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        );
                                      return;
                                    }
                                    authViewModel.signUp(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text.trim(),
                                      fullName: _fullNameController.text.trim(),
                                      locality: _localityController.text.trim(),
                                      whatsappNumber: _whatsappController.text
                                          .trim(),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: authViewModel.authState == AuthState.loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!.signUpButton,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Column(
                    children: [
                      const SizedBox(height: 16),

                      // FCFA indicator
                      Text(
                        AppLocalizations.of(context)!.pricesListedIn,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In link
                      Text(
                        AppLocalizations.of(context)!.haveAccount,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/sign-in'),
                        child: Text(
                          AppLocalizations.of(context)!.logInButton,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Home indicator
                      Container(
                        width: 96,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
