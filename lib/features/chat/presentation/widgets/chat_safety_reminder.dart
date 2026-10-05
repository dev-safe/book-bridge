import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time online-safety reminder shown to users under 18 before they send
/// their first chat message (Google Play Families Policy, social features).
class ChatSafetyReminder {
  const ChatSafetyReminder._();

  static const String _prefsKeyPrefix = 'chat_safety_ack_';

  static String prefsKeyFor(String userId) => '$_prefsKeyPrefix$userId';

  /// Treats a user as a minor when their date of birth puts them under 18,
  /// or when no date of birth is known and they have not declared as adult.
  static bool isMinor(User? user, {DateTime? now}) {
    if (user == null) return true;
    final dob = user.dateOfBirth;
    if (dob == null) return user.ageDeclaration != 'adult';
    final today = now ?? DateTime.now();
    var age = today.year - dob.year;
    final hadBirthday =
        today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthday) age--;
    return age < 18;
  }

  /// Returns true when the user may send. Shows the reminder dialog when
  /// required and records the acknowledgement so it is shown only once.
  static Future<bool> ensureAcknowledged({
    required BuildContext context,
    required User? user,
    required String userId,
    required SharedPreferences prefs,
  }) async {
    if (!isMinor(user)) return true;
    final key = prefsKeyFor(userId);
    if (prefs.getBool(key) ?? false) return true;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          key: const Key('chatSafetyReminderDialog'),
          icon: const Icon(Icons.shield_outlined),
          title: Text(l10n.chatSafetyTitle),
          content: SingleChildScrollView(child: Text(l10n.chatSafetyBody)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('chatSafetyAcceptButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.chatSafetyAccept),
            ),
          ],
        );
      },
    );

    if (accepted != true) return false;
    await prefs.setBool(key, true);
    return true;
  }
}
