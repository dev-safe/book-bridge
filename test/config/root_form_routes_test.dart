import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression guard for the edit-listing keyboard bug.
///
/// Root-level screens (My Books, Listing details) used to push the shell's
/// '/sell' route. That duplicates the shell navigator's page keys, so opening
/// the keyboard rebuilt the router, remounted the form (keyboard closed) and
/// could blank the screen. The app now pushes root-level '/edit-listing' and
/// '/new-listing' routes instead; this mirrors that route layout.
class _FormProbe extends StatefulWidget {
  const _FormProbe();

  static int mounts = 0;

  @override
  State<_FormProbe> createState() => _FormProbeState();
}

class _FormProbeState extends State<_FormProbe> {
  @override
  void initState() {
    super.initState();
    _FormProbe.mounts++;
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: TextField(key: Key('field')));
}

GoRouter _router() => GoRouter(
  initialLocation: '/my-books',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(body: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const Text('h'))],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/sell', builder: (_, _) => const _FormProbe()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/my-books',
      builder: (context, state) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => context.push('/edit-listing', extra: 1),
              child: const Text('edit'),
            ),
            TextButton(
              onPressed: () => context.push('/new-listing'),
              child: const Text('new'),
            ),
          ],
        ),
      ),
    ),
    GoRoute(path: '/edit-listing', builder: (_, _) => const _FormProbe()),
    GoRoute(path: '/new-listing', builder: (_, _) => const _FormProbe()),
  ],
);

void main() {
  for (final button in ['edit', 'new']) {
    testWidgets('form opened via "$button" keeps focus when keyboard opens', (
      tester,
    ) async {
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      final mountsBefore = _FormProbe.mounts;

      tester.view.viewInsets = const FakeViewPadding(bottom: 800);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_FormProbe.mounts, mountsBefore, reason: 'form was remounted');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    });
  }
}
