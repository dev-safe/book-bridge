import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/profile_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/locale_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/core/presentation/viewmodels/theme_viewmodel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:book_bridge/features/payments/presentation/widgets/payment_bottom_sheet.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:book_bridge/injection_container.dart';
import 'package:book_bridge/features/notifications/presentation/viewmodels/notifications_viewmodel.dart';

/// User profile screen displaying user information and their listings.
///
/// This screen shows the current user's profile information, their active listings,
/// and provides options to manage or delete listings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileViewModel>().loadProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(
          AppLocalizations.of(context)!.account,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<NotificationsViewModel>(
            builder: (context, notifVm, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (notifVm.unreadCount > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/edit-profile');
              } else if (value == 'logout') {
                _confirmLogout(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    SizedBox(width: 12),
                    Text(AppLocalizations.of(context)!.editProfile),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.logout,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, profileViewModel, _) {
          if (profileViewModel.profileState == ProfileState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = profileViewModel.currentUser;
          if (user == null) {
            return Center(
              child: Text(AppLocalizations.of(context)!.userNotFound),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, user),
                _buildStatsSection(context, profileViewModel),
                _buildDonationCard(context, user),
                const Divider(height: 1),
                _buildMenuSection(
                  context,
                  AppLocalizations.of(context)!.myAccount,
                  [
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline,
                      title: AppLocalizations.of(context)!.myProfileEdit,
                      onTap: () => context.push('/edit-profile'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.favorite_border,
                      title: AppLocalizations.of(context)!.myFavourites,
                      onTap: () => context.push('/favorites'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.book_outlined,
                      title: AppLocalizations.of(context)!.myBooks,
                      onTap: () => context.push('/my-books'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: AppLocalizations.of(context)!.transactionHistory,
                      onTap: () => context.push('/transactions'),
                      isLast: true,
                    ),
                  ],
                ),
                const Divider(height: 1),
                _buildMenuSection(context, AppLocalizations.of(context)!.more, [
                  Consumer<ThemeViewModel>(
                    builder: (context, themeViewModel, child) {
                      final l10n = AppLocalizations.of(context)!;
                      final isDarkMode =
                          themeViewModel.themeMode == ThemeMode.dark ||
                          (themeViewModel.themeMode == ThemeMode.system &&
                              MediaQuery.of(context).platformBrightness ==
                                  Brightness.dark);
                      return SwitchListTile(
                        secondary: Icon(
                          isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: Text(l10n.darkMode),
                        subtitle: Text(
                          themeViewModel.themeMode == ThemeMode.system
                              ? l10n.systemDefault
                              : l10n.manual,
                        ),
                        value: isDarkMode,
                        onChanged: (value) {
                          themeViewModel.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      );
                    },
                  ),
                  _buildMenuSwitch(
                    context,
                    icon: Icons.location_on_outlined,
                    title: AppLocalizations.of(context)!.locationServices,
                    value: context.watch<LocationViewModel>().locationEnabled,
                    onChanged: (val) {
                      context.read<LocationViewModel>().toggle();
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.lock_outline,
                    title: AppLocalizations.of(context)!.privacyPolicy,
                    onTap: () => context.push('/privacy'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.description_outlined,
                    title: AppLocalizations.of(context)!.termsConditions,
                    onTap: () => context.push('/terms'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.language_outlined,
                    title: AppLocalizations.of(context)!.language,
                    onTap: () => _showLanguagePicker(context),
                  ),
                  _buildExpandableMenuItem(
                    context,
                    icon: Icons.help_outline,
                    title: AppLocalizations.of(context)!.helpSupport,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.help_outline,
                        title: AppLocalizations.of(context)!.faq,
                        onTap: () => context.push('/faq'),
                        indent: true,
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.feedback_outlined,
                        title: AppLocalizations.of(context)!.feedback,
                        onTap: () => context.push('/feedback'),
                        indent: true,
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.email_outlined,
                        title: AppLocalizations.of(context)!.contactUs,
                        onTap: () => context.push('/contact'),
                        indent: true,
                        isLast: true,
                      ),
                    ],
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.share_outlined,
                    title: AppLocalizations.of(context)!.inviteFriends,
                    onTap: () {
                      final l10n = AppLocalizations.of(context)!;
                      Share.share(
                        l10n.inviteMessage,
                        subject: l10n.inviteSubject,
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: AppLocalizations.of(context)!.aboutBookBridge,
                    onTap: () => context.push('/about'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.logout_rounded,
                    title: AppLocalizations.of(context)!.logout,
                    textColor: Colors.red,
                    onTap: () => _confirmLogout(context),
                    isLast: true,
                  ),
                ]),
                _buildFollowUs(context),
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage:
                user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : user.email[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName.isNotEmpty ? user.fullName : user.email,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                user.locality ?? AppLocalizations.of(context)!.unknownLocation,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ProfileViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              vm.userListings.length.toString(),
              AppLocalizations.of(context)!.activeBooks,
              AppTheme.scholarBlue,
            ),
          ),
          Container(height: 40, width: 1, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              context,
              AppLocalizations.of(context)!.priceFormat(
                NumberFormat.compact().format(
                  vm.userListings.fold<int>(
                    0,
                    (sum, item) => sum + item.priceFcfa,
                  ),
                ),
              ),
              AppLocalizations.of(context)!.totalValue,
              AppTheme.growthGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.7),
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...items,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    bool isLast = false,
    bool indent = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            size: 22,
            color:
                textColor ??
                Theme.of(context).iconTheme.color?.withValues(alpha: 0.8),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: onTap,
          trailing: Icon(
            Icons.chevron_right,
            size: 18,
            color: Colors.grey.withValues(alpha: 0.6),
          ),
          contentPadding: EdgeInsets.only(left: indent ? 40 : 20, right: 20),
          visualDensity: VisualDensity.compact,
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.only(left: indent ? 80 : 60),
            child: Divider(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuSwitch(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? textColor,
    bool isLast = false,
    bool indent = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            icon,
            size: 22,
            color:
                textColor ??
                Theme.of(context).iconTheme.color?.withValues(alpha: 0.8),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: textColor ?? theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.only(left: indent ? 40 : 20, right: 20),
          activeTrackColor: AppTheme.scholarBlue.withValues(alpha: 0.5),
          activeThumbColor: AppTheme.scholarBlue,
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.only(left: indent ? 80 : 60),
            child: Divider(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.1),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandableMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              icon,
              size: 22,
              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.8),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.expand_more,
              size: 18,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
            childrenPadding: EdgeInsets.zero,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20),
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 60),
          child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ],
    );
  }

  Widget _buildFollowUs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.followUs,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSocialIcon(
                  FontAwesomeIcons.whatsapp,
                  const Color(0xFF25D366),
                  'Community',
                  () => _launchUrl(
                    'https://chat.whatsapp.com/H6WZEE86OEoDkb4jjjtOHZ',
                  ),
                ),
                _buildSocialIcon(
                  FontAwesomeIcons.linkedinIn,
                  const Color(0xFF0A66C2),
                  AppLocalizations.of(context)!.linkedin,
                  () => _launchUrl(
                    'https://www.linkedin.com/in/verla-berinyuy-15b1262a5/',
                  ),
                ),
                _buildSocialIcon(
                  FontAwesomeIcons.youtube,
                  const Color(0xFFFF0000),
                  AppLocalizations.of(context)!.youtube,
                  () => _launchUrl('https://www.youtube.com/@VerlaBerinyuy'),
                ),
                _buildSocialIcon(
                  FontAwesomeIcons.instagram,
                  const Color(0xFFE4405F),
                  AppLocalizations.of(context)!.instagram,
                  () => _launchUrl(
                    'https://www.instagram.com/verlaberinyuyndey/',
                  ),
                ),
                _buildSocialIcon(
                  FontAwesomeIcons.facebook,
                  const Color(0xFF1877F2),
                  AppLocalizations.of(context)!.facebook,
                  () => _launchUrl(
                    'https://www.facebook.com/profile.php?id=61572639047021',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.logoutConfirmTitle),
        content: Text(AppLocalizations.of(context)!.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthViewModel>().signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.logout),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final localeViewModel = context.watch<LocaleViewModel>();
        final currentLocale = localeViewModel.locale;

        return SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.selectLanguage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLanguageOption(
                    context,
                    title: l10n.english,
                    flag: '🇺🇸',
                    isSelected: currentLocale.languageCode == 'en',
                    onTap: () {
                      localeViewModel.setLocale(const Locale('en'));
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  _buildLanguageOption(
                    context,
                    title: l10n.french,
                    flag: '🇫🇷',
                    isSelected: currentLocale.languageCode == 'fr',
                    onTap: () {
                      localeViewModel.setLocale(const Locale('fr'));
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildDonationCard(BuildContext context, user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => _showDonationAmountPicker(context, user),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.coffee, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.supportBookBridge,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.supportDescription,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDonationAmountPicker(BuildContext context, user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.selectDonationAmount,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAmountButton(context, 100, user),
                    _buildAmountButton(context, 500, user),
                    _buildAmountButton(context, 1000, user),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountButton(BuildContext context, int amount, user) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context); // close amount picker

        final userId = user?.id ?? 'anonymous';
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => ChangeNotifierProvider(
            create: (_) => getIt<PaymentViewModel>(),
            child: PaymentBottomSheet(
              amount: amount,
              title: AppLocalizations.of(context)!.supportBookBridge,
              externalReference: 'donation_${userId}_$timestamp',
              onSuccess: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.donationThanks),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A4D8C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        '$amount',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
