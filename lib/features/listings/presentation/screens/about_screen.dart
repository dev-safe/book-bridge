import 'package:book_bridge/core/constants/contact_links.dart';
import 'package:book_bridge/core/utils/external_links.dart';
import 'package:book_bridge/features/payments/presentation/widgets/donation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.aboutBookBridge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/app_icon.png', // Assuming app_icon exists
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.primary,
                    child: const Icon(
                      Icons.book,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Name & Version
            Text(
              'BookBridge',
              style: GoogleFonts.lato(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) => Text(
                snapshot.hasData
                    ? AppLocalizations.of(context)!.version(
                        '${snapshot.data!.version} (${snapshot.data!.buildNumber})',
                      )
                    : '',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Description
            Text(
              AppLocalizations.of(context)!.aboutDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 48),

            // Links Section
            _buildLinkTile(
              context,
              icon: Icons.favorite_rounded,
              title: AppLocalizations.of(context)!.supportCommunity,
              subtitle: AppLocalizations.of(context)!.supportDescription,
              onTap: () => showDonationSheet(context),
            ),
            const SizedBox(height: 16),
            _buildLinkTile(
              context,
              icon: FontAwesomeIcons.whatsapp.data,
              title: AppLocalizations.of(context)!.whatsappSupport,
              subtitle: ContactLinks.supportWhatsAppDisplay,
              onTap: () =>
                  openExternalUrl(context, ContactLinks.supportWhatsAppUrl),
            ),
            const SizedBox(height: 16),
            _buildLinkTile(
              context,
              icon: FontAwesomeIcons.linkedinIn.data,
              title: AppLocalizations.of(context)!.linkedin,
              subtitle: AppLocalizations.of(
                context,
              )!.connectWithAuthor('Verla Berinyuy'),
              onTap: () => openExternalUrl(context, ContactLinks.linkedInUrl),
            ),
            const SizedBox(height: 16),
            _buildLinkTile(
              context,
              icon: Icons.code,
              title: AppLocalizations.of(context)!.projectSourceCode,
              subtitle: AppLocalizations.of(context)!.viewOnGitHub,
              onTap: () => openExternalUrl(
                context,
                'https://github.com/DCT-Berinyuy/book-bridge',
              ),
            ),
            const SizedBox(height: 16),
            _buildLinkTile(
              context,
              icon: Icons.language,
              title: AppLocalizations.of(context)!.officialWebsite,
              subtitle: AppLocalizations.of(context)!.visitWebPlatform,
              onTap: () =>
                  openExternalUrl(context, 'https://bookbridge.devsafe.cm/'),
            ),
            const SizedBox(height: 16),
            _buildLinkTile(
              context,
              icon: Icons.person,
              title: 'Mr.DCT',
              subtitle: AppLocalizations.of(
                context,
              )!.connectWithAuthor('Mr.DCT'),
              onTap: () => openExternalUrl(
                context,
                'https://linktr.ee/DeepCodeThinking',
              ),
            ),

            const SizedBox(height: 48),
            Text(
              AppLocalizations.of(
                context,
              )!.copyright(DateTime.now().year.toString()),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('poweredByDevSafe'),
              onPressed: () =>
                  openExternalUrl(context, 'https://www.devsafe.cm'),
              child: Text(
                AppLocalizations.of(context)!.poweredByDevSafe,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).iconTheme.color,
            ),
          ],
        ),
      ),
    );
  }
}
