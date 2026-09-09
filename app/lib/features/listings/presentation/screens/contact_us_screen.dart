import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchWhatsApp() async {
    const phoneNumber = '237675010547'; // Adding Cameroon country code
    final url = 'https://wa.me/$phoneNumber';
    await _launchUrl(url);
  }

  Future<void> _launchEmail() async {
    const email = 'verlaberinyuy8@gmail.com';
    const subject = 'BookBridge Support';
    final url = 'mailto:$email?subject=${Uri.encodeComponent(subject)}';
    await _launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.contactUs),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.getInTouch,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.contactSubtitle,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildContactCard(
              context,
              icon: FontAwesomeIcons.whatsapp,
              title: AppLocalizations.of(context)!.whatsappSupport,
              subtitle: AppLocalizations.of(context)!.chatDirectly,
              color: Colors.green,
              onTap: _launchWhatsApp,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context,
              icon: Icons.email_outlined,
              title: AppLocalizations.of(context)!.emailUs,
              subtitle: 'verlaberinyuy8@gmail.com',
              color: Colors.redAccent,
              onTap: _launchEmail,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context,
              icon: FontAwesomeIcons.linkedinIn,
              title: 'LinkedIn',
              subtitle: AppLocalizations.of(
                context,
              )!.connectWithAuthor('Verla Berinyuy'),
              color: const Color(0xFF0077B5),
              onTap: () => _launchUrl(
                'https://www.linkedin.com/in/verla-berinyuy-15b1262a5/',
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                AppLocalizations.of(context)!.availableHours,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
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
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
