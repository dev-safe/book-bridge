import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/profile_viewmodel.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/presentation/widgets/academic_filter_bar.dart';
import 'package:book_bridge/injection_container.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _localityController;
  late TextEditingController _whatsappController;

  // Save reference to avoid accessing context in dispose()
  late ProfileViewModel _profileViewModel;

  final ListingRepository _listingRepository = getIt<ListingRepository>();
  School? _school;
  bool _schoolChanged = false;

  @override
  void initState() {
    super.initState();
    _profileViewModel = context.read<ProfileViewModel>();
    _fullNameController = TextEditingController(
      text: _profileViewModel.currentUser?.fullName ?? '',
    );
    _localityController = TextEditingController(
      text: _profileViewModel.currentUser?.locality ?? '',
    );
    _whatsappController = TextEditingController(
      text: _profileViewModel.currentUser?.whatsappNumber ?? '',
    );

    // Add a listener to handle UI feedback after profile update
    _profileViewModel.addListener(_onProfileStateChanged);
    _loadCurrentSchool();
  }

  Future<void> _loadCurrentSchool() async {
    final schoolId = _profileViewModel.currentUser?.schoolId;
    if (schoolId == null) return;
    final result = await _listingRepository.getSchoolById(schoolId);
    if (!mounted || _schoolChanged) return;
    result.fold((_) {}, (school) => setState(() => _school = school));
  }

  Future<void> _pickSchool() async {
    final l10n = AppLocalizations.of(context)!;
    final pick = await showSchoolPicker(
      context,
      searchSchools: (query) async => (await _listingRepository.searchSchools(
        query,
      )).getOrElse(() => const []),
      selected: _school,
      clearLabel: l10n.noSchool,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _school = pick.value;
      _schoolChanged = true;
    });
  }

  @override
  void dispose() {
    // Remove the listener before disposing using saved reference
    _profileViewModel.removeListener(_onProfileStateChanged);
    _fullNameController.dispose();
    _localityController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _onProfileStateChanged() {
    // Check if the widget is still mounted before accessing context
    if (!mounted) return;

    final profileViewModel = context.read<ProfileViewModel>();
    if (profileViewModel.profileState == ProfileState.error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              profileViewModel.errorMessage ??
                  AppLocalizations.of(context)!.profileUpdateFailed,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } else if (profileViewModel.profileState == ProfileState.loaded) {
      // Assuming successful update means we are in loaded state
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileUpdatedSuccess),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      // Navigate back after a short delay to ensure UI updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check again if still mounted before navigating
          context.pop(); // Navigate back after successful update
        }
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compress image
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      await _profileViewModel.uploadProfilePicture(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.editProfile)),
      body: Consumer<ProfileViewModel>(
        builder: (context, profileViewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Picture Upload
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child:
                                profileViewModel.currentUser?.avatarUrl !=
                                        null &&
                                    profileViewModel
                                        .currentUser!
                                        .avatarUrl!
                                        .isNotEmpty
                                ? Image.network(
                                    profileViewModel.currentUser!.avatarUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                  )
                                : Container(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: Center(
                                      child: Text(
                                        profileViewModel
                                                    .currentUser
                                                    ?.fullName
                                                    .isNotEmpty ??
                                                false
                                            ? profileViewModel
                                                  .currentUser!
                                                  .fullName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (profileViewModel.isLoading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            radius: 18,
                            child: IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: profileViewModel.isLoading
                                  ? null
                                  : _pickAndUploadImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _fullNameController,
                    enabled: !profileViewModel.isLoading,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fullName,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterFullName;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _localityController,
                    enabled: !profileViewModel.isLoading,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      )!.localityNeighborhood,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _whatsappController,
                    enabled: !profileViewModel.isLoading,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.whatsappNumber,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.mySchoolLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  PickerFormField(
                    value: _school?.displayName,
                    hint: AppLocalizations.of(
                      context,
                    )!.selectSchoolOptionalHint,
                    onTap: profileViewModel.isLoading ? null : _pickSchool,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: profileViewModel.isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              profileViewModel.updateUser(
                                fullName: _fullNameController.text.trim(),
                                locality: _localityController.text.trim(),
                                whatsappNumber: _whatsappController.text.trim(),
                                schoolId: _schoolChanged ? _school?.id : null,
                                clearSchool: _schoolChanged && _school == null,
                              );
                            }
                          },
                    child: profileViewModel.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.saveChanges),
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
