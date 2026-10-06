import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/moderation/presentation/viewmodels/moderation_viewmodel.dart';
import 'package:book_bridge/features/moderation/presentation/widgets/moderation_actions.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Lists the people the user has blocked, with an Unblock button each.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final userId = context.read<AuthViewModel>().currentUser?.id;
    return context.read<ModerationViewModel>().load(userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<ModerationViewModel>();
    final users = vm.blockedUsers;

    Widget body;
    if (vm.isLoading && users.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (vm.loadFailure != null && users.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.somethingWentWrong),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    } else if (users.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.blockedUsersEmpty, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            final avatar = user.avatarUrl;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: avatar != null && avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(ModerationActions.displayName(l10n, user.name)),
              trailing: OutlinedButton(
                onPressed: _busy.contains(user.id)
                    ? null
                    : () async {
                        setState(() => _busy.add(user.id));
                        await ModerationActions.unblock(context, user);
                        if (mounted) setState(() => _busy.remove(user.id));
                      },
                child: Text(l10n.unblockUser),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      body: body,
    );
  }
}
