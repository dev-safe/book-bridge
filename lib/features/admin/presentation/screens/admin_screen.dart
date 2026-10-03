import 'package:book_bridge/features/admin/domain/entities/admin_cases.dart';
import 'package:book_bridge/features/admin/presentation/viewmodels/admin_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Internal tool for resolving disputes and unmatched payments. Opened by
/// long-pressing "About BookBridge" on the profile screen; the server
/// decides who may use it. English-only, like the rest of the admin tooling.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom:
              vm.state == AdminLoadState.denied ||
                  vm.state == AdminLoadState.checking
              ? null
              : TabBar(
                  tabs: [
                    Tab(text: 'Disputes (${vm.disputes.length})'),
                    Tab(text: 'Unmatched (${vm.unmatched.length})'),
                  ],
                ),
        ),
        body: switch (vm.state) {
          AdminLoadState.checking => const Center(
            child: CircularProgressIndicator(),
          ),
          AdminLoadState.denied => _Message(
            icon: Icons.lock_outline,
            text: vm.error ?? 'Admin access required',
            onRetry: vm.open,
          ),
          _ => Column(
            children: [
              if (vm.state == AdminLoadState.loading)
                const LinearProgressIndicator(),
              if (vm.error != null)
                MaterialBanner(
                  content: Text(vm.error!),
                  actions: [
                    TextButton(
                      onPressed: vm.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    _CaseList(
                      empty: 'No open disputes',
                      onRefresh: vm.refresh,
                      children: [
                        for (final d in vm.disputes) _DisputeCard(dispute: d),
                      ],
                    ),
                    _CaseList(
                      empty: 'No unmatched payments',
                      onRefresh: vm.refresh,
                      children: [
                        for (final p in vm.unmatched)
                          _UnmatchedCard(payment: p),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  const _Message({
    required this.icon,
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CaseList extends StatelessWidget {
  final String empty;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const _CaseList({
    required this.empty,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: children.isEmpty
            ? [const SizedBox(height: 120), Center(child: Text(empty))]
            : children,
      ),
    );
  }
}

String _when(DateTime? at) =>
    at == null ? 'unknown' : DateFormat('d MMM yyyy, HH:mm').format(at);

class _DisputeCard extends StatelessWidget {
  final AdminDispute dispute;

  const _DisputeCard({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final busy = vm.busyId != null;
    final d = dispute;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.listingTitle ?? 'Unknown listing'} · ${d.amount} FCFA',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Buyer: ${d.buyerName ?? '—'}  ·  Seller: ${d.sellerName ?? '—'}',
            ),
            Text('Disputed: ${_when(d.disputedAt)}'),
            Text('Paid from: ${d.payerPhoneHint ?? 'not recorded'}'),
            const SizedBox(height: 8),
            Text('Reason: ${d.disputeReason ?? '—'}'),
            SelectableText(
              'Transaction ${d.transactionId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (vm.busyId == d.transactionId) const LinearProgressIndicator(),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _resolve(
                          context,
                          title: 'Refund buyer',
                          consequence:
                              'Sends ${d.amount} FCFA back to the buyer and '
                              'closes the sale as refunded. The seller is not '
                              'paid.',
                          askPhone: true,
                          phoneHint: d.payerPhoneHint,
                          run: (note, phone) => vm.refundDispute(
                            d.transactionId,
                            note,
                            phone: phone,
                          ),
                        ),
                  child: const Text('Refund buyer'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _resolve(
                          context,
                          title: 'Release to seller',
                          consequence:
                              "Pays the seller's payout number as if the "
                              'buyer had confirmed receipt. The buyer is not '
                              'refunded.',
                          run: (note, _) =>
                              vm.releaseDispute(d.transactionId, note),
                        ),
                  child: const Text('Release to seller'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnmatchedCard extends StatelessWidget {
  final UnmatchedPayment payment;

  const _UnmatchedCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminViewModel>();
    final busy = vm.busyId != null;
    final p = payment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p.amount ?? '?'} FCFA · ${p.transId ?? 'no transId'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Received: ${_when(p.receivedAt)}'),
            Text('Paid from: ${p.payerPhoneHint ?? 'not recorded'}'),
            Text('Why unmatched: ${p.reason ?? '—'}'),
            const SizedBox(height: 8),
            if (vm.busyId == p.id) const LinearProgressIndicator(),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _resolve(
                          context,
                          title: 'Dismiss',
                          consequence:
                              'Marks this payment handled without paying '
                              'anything. Use this only if it was settled '
                              'another way; say how in the note.',
                          run: (note, _) => vm.dismissUnmatched(p.id, note),
                        ),
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _resolve(
                          context,
                          title: 'Refund payer',
                          consequence:
                              'Sends back the amount Fapshi recorded for this '
                              'payment.',
                          askPhone: true,
                          phoneHint: p.payerPhoneHint,
                          run: (note, phone) =>
                              vm.refundUnmatched(p.id, note, phone: phone),
                        ),
                  child: const Text('Refund payer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _resolve(
  BuildContext context, {
  required String title,
  required String consequence,
  bool askPhone = false,
  String? phoneHint,
  required Future<String?> Function(String note, String? phone) run,
}) async {
  final decision = await showDialog<_Decision>(
    context: context,
    builder: (_) => _ResolveDialog(
      title: title,
      consequence: consequence,
      askPhone: askPhone,
      phoneHint: phoneHint,
    ),
  );
  if (decision == null) return;
  final error = await run(decision.note, decision.phone);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error ?? '$title: done')));
}

class _Decision {
  final String note;
  final String? phone;

  const _Decision(this.note, this.phone);
}

/// Mirrors the server's checks so mistakes show before anything is sent.
String? validateAdminNote(String? value) {
  final note = value?.trim() ?? '';
  if (note.isEmpty) return 'A note is required';
  if (note.length > 1000) return 'At most 1000 characters';
  return null;
}

/// Accepts an empty value (use the recorded number) or a Cameroonian mobile
/// number, with or without the 237 prefix.
String? normalizeRefundPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('237') && digits.length > 9) {
    digits = digits.substring(3);
  }
  return RegExp(r'^6\d{8}$').hasMatch(digits) ? digits : null;
}

class _ResolveDialog extends StatefulWidget {
  final String title;
  final String consequence;
  final bool askPhone;
  final String? phoneHint;

  const _ResolveDialog({
    required this.title,
    required this.consequence,
    required this.askPhone,
    this.phoneHint,
  });

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final phone = _phone.text.trim().isEmpty
        ? null
        : normalizeRefundPhone(_phone.text);
    Navigator.of(context).pop(_Decision(_note.text.trim(), phone));
  }

  @override
  Widget build(BuildContext context) {
    final recorded = widget.phoneHint;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.consequence),
              const SizedBox(height: 4),
              const Text(
                'This cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (widget.askPhone) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Refund to number',
                    helperText: recorded == null
                        ? 'Required: no paying number was recorded'
                        : 'Leave empty to use $recorded',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return recorded == null ? 'Enter the number' : null;
                    }
                    return normalizeRefundPhone(text) == null
                        ? 'Enter a 9-digit number starting with 6'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Note (kept in the audit trail)',
                  hintText: 'What you checked and why',
                ),
                validator: validateAdminNote,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.title)),
      ],
    );
  }
}
