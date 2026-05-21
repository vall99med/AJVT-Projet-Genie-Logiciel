import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/payment_state.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

String _modeLabel(String key, AppLocalizations t) => switch (key) {
  'cash'     => t.translate('cash_mode'),
  'transfer' => t.translate('transfer_mode'),
  'bimbank'  => 'BimBank',
  _          => key.isNotEmpty ? '${key[0].toUpperCase()}${key.substring(1)}' : key,
};

class ReviewPaymentsScreen extends ConsumerStatefulWidget {
  const ReviewPaymentsScreen({super.key});

  @override
  ConsumerState<ReviewPaymentsScreen> createState() => _ReviewPaymentsScreenState();
}

class _ReviewPaymentsScreenState extends ConsumerState<ReviewPaymentsScreen> {
  List<Map<String, dynamic>>? _items;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    // Peuple la liste locale à chaque (re)chargement
    ref.listen<AsyncValue<List<dynamic>>>(submittedPaymentsProvider, (_, next) {
      if (next is AsyncData<List<dynamic>>) {
        setState(() => _items = next.value.cast<Map<String, dynamic>>());
      }
    });

    final asyncData = ref.watch(submittedPaymentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('review_receipts')),
        actions: const [LanguageToggle()],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () {
            setState(() => _items = null);
            ref.invalidate(submittedPaymentsProvider);
          },
        ),
        data: (_) {
          final items = _items;
          if (items == null) return const Center(child: CircularProgressIndicator());
          if (items.isEmpty) {
            return Center(
              child: Text(
                t.translate('no_pending_receipts'),
                style: const TextStyle(color: AppColors.textMid),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _items = null);
              ref.invalidate(submittedPaymentsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) => _ReviewTile(
                payment:   items[i],
                t:         t,
                onApprove: () => _onAction(items[i]['id'] as int, 'approve', null),
                onReject:  (reason) => _onAction(items[i]['id'] as int, 'reject', reason),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onAction(int id, String action, String? reason) async {
    // Suppression optimiste
    setState(() => _items = _items?.where((p) => p['id'] != id).toList());

    final ok = await ref.read(paymentNotifierProvider.notifier)
        .reviewPayment(id, action, rejectionReason: reason);

    if (!mounted) return;
    if (!ok) {
      // Rétablit la liste depuis le serveur en cas d'erreur
      setState(() => _items = null);
      ref.invalidate(submittedPaymentsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ref.read(paymentNotifierProvider).error
              ?.toString().replaceFirst('Exception: ', '') ??
              AppLocalizations.tr(context, 'error'),
        ),
        backgroundColor: AppColors.error,
      ));
    } else {
      final msg = action == 'approve'
          ? AppLocalizations.tr(context, 'validate_success')
          : AppLocalizations.tr(context, 'reject_success');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(msg),
        backgroundColor: action == 'approve' ? AppColors.success : AppColors.warning,
      ));
    }
  }
}

class _ReviewTile extends StatefulWidget {
  final Map<String, dynamic> payment;
  final AppLocalizations t;
  final VoidCallback onApprove;
  final void Function(String reason) onReject;

  const _ReviewTile({
    required this.payment,
    required this.t,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<_ReviewTile> {
  Future<void> _showRejectSheet() async {
    final ctrl   = TextEditingController();
    String? result;
    final t = widget.t;

    await showModalBottomSheet<void>(
      context:          context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize:  MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.translate('rejection_reason'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: t.translate('reject_reason_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines:   3,
                autofocus:  true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t.translate('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (ctrl.text.trim().isEmpty) return;
                        result = ctrl.text.trim();
                        Navigator.pop(ctx);
                      },
                      child: Text(t.translate('reject')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (result != null) widget.onReject(result!);
  }

  @override
  Widget build(BuildContext context) {
    final p          = widget.payment;
    final t          = widget.t;
    final name       = p['member_name']    as String? ?? '—';
    final year       = p['year']           as int?    ?? DateTime.now().year;
    final amount     = p['amount']         as String? ?? '0.00';
    final mode       = p['payment_mode']   as String? ?? '';
    final txRef      = p['transaction_ref'] as String? ?? '';
    final receiptUrl = p['receipt_image_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête membre ────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius:          20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color:      AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          )),
                      Text(
                        '$year  ·  ${_modeLabel(mode, t)}  ·  $amount MRU',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Référence transaction ─────────────────────────────
            if (txRef.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(txRef,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
                ],
              ),
            ],

            // ── Miniature reçu + boutons ──────────────────────────
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Miniature cliquable
                if (receiptUrl != null)
                  GestureDetector(
                    onTap: () => context.push('/payment/receipt', extra: receiptUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl:    receiptUrl,
                        width:       64,
                        height:      64,
                        fit:         BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 64, height: 64,
                          color: AppColors.surface,
                          child: const Icon(Icons.image, color: AppColors.textLight),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 64, height: 64,
                          color: AppColors.surface,
                          child: const Icon(Icons.broken_image, color: AppColors.textLight),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                // Bouton Rejeter
                OutlinedButton(
                  onPressed: _showRejectSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side:            const BorderSide(color: AppColors.error),
                    padding:         const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(t.translate('reject')),
                ),
                const SizedBox(width: 10),
                // Bouton Approuver
                ElevatedButton(
                  onPressed: widget.onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(t.translate('approve')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMid)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh),
              label: Text(AppLocalizations.tr(context, 'retry')),
            ),
          ],
        ),
      ),
    );
  }
}
