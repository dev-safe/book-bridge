import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/chat/presentation/widgets/chat_safety_reminder.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user({DateTime? dob, String? declaration}) => User(
  id: 'u1',
  email: 'u1@example.com',
  fullName: 'Test User',
  dateOfBirth: dob,
  ageDeclaration: declaration,
  createdAt: DateTime(2024),
);

void main() {
  group('ChatSafetyReminder.isMinor', () {
    final now = DateTime(2026, 6, 15);

    test('treats unknown user as minor', () {
      expect(ChatSafetyReminder.isMinor(null, now: now), isTrue);
    });

    test('uses declaration when no date of birth', () {
      expect(
        ChatSafetyReminder.isMinor(_user(declaration: 'adult'), now: now),
        isFalse,
      );
      expect(
        ChatSafetyReminder.isMinor(_user(declaration: 'guardian'), now: now),
        isTrue,
      );
      expect(ChatSafetyReminder.isMinor(_user(), now: now), isTrue);
    });

    test('is minor the day before 18th birthday', () {
      final user = _user(dob: DateTime(2008, 6, 16), declaration: 'adult');
      expect(ChatSafetyReminder.isMinor(user, now: now), isTrue);
    });

    test('is adult on 18th birthday', () {
      final user = _user(dob: DateTime(2008, 6, 15));
      expect(ChatSafetyReminder.isMinor(user, now: now), isFalse);
    });
  });

  group('ChatSafetyReminder.ensureAcknowledged', () {
    Future<bool?> run(
      WidgetTester tester, {
      required User? user,
      required SharedPreferences prefs,
      bool accept = true,
    }) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ChatSafetyReminder.ensureAcknowledged(
                  context: context,
                  user: user,
                  userId: 'u1',
                  prefs: prefs,
                );
              },
              child: const Text('send'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('send'));
      await tester.pumpAndSettle();
      if (find
          .byKey(const Key('chatSafetyReminderDialog'))
          .evaluate()
          .isNotEmpty) {
        if (accept) {
          await tester.tap(find.byKey(const Key('chatSafetyAcceptButton')));
        } else {
          await tester.tap(find.byType(TextButton));
        }
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('minor must accept once, then is not asked again', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final minor = _user(
        dob: DateTime.now().subtract(const Duration(days: 365 * 12)),
      );

      expect(await run(tester, user: minor, prefs: prefs), isTrue);
      expect(prefs.getBool(ChatSafetyReminder.prefsKeyFor('u1')), isTrue);

      await tester.tap(find.text('send'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chatSafetyReminderDialog')), findsNothing);
    });

    testWidgets('cancel blocks sending and does not persist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(
        await run(tester, user: _user(), prefs: prefs, accept: false),
        isFalse,
      );
      expect(prefs.getBool(ChatSafetyReminder.prefsKeyFor('u1')), isNull);
    });

    testWidgets('adult is never shown the reminder', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(
        await run(
          tester,
          user: _user(declaration: 'adult'),
          prefs: prefs,
        ),
        isTrue,
      );
      expect(find.byKey(const Key('chatSafetyReminderDialog')), findsNothing);
    });
  });
}
