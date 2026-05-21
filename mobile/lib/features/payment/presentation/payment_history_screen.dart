import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/payment_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

String _modeLabel(String key, AppLocalizations t) => switch (key) {
  'cash'     => t.translate('cash_mode'),
  'transfer' => t.translate('transfer_mode'),
  'bimbank'  => 'BimBank',
  _          => key.isNotEmpty ? '${key[0].toUpperCase()}${key.substring(1)}' : key,
};

Color _statusColor(String status) => switch (status) {
  'paid'      => AppColors.success,
  'submitted' => AppColors.primary,
  'rejected'  => AppColors.error,
  _           => AppColors.warning,
};

IconData _statusIcon(String status) => switch (status) {
  'paid'      => Icons.check_circle_outline,
  'submitted' => Icons.access_time,
  'rejected'  => Icons.cancel_outlined,
  _           => Icons.hourglass_empty,
};

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(myPaymentsProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('payment_history')),
        actions: [
          const LanguageToggle(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.translate('logout'),
            onPressed: () async {
              final router = GoRouter.of(context);
              await ref.read(authNotifierProvider.notifier).logout();
              router.go('/phone');
            },
          ),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(myPaymentsProvider),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return Center(
              child: Text(
                t.translate('no_members'),
                style: const TextStyle(color: AppColors.textMid),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPaymentsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (_, i) =>
                  _PaymentTile(payment: payments[i] as Map<String, dynamic>, t: t),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Map<String, dynamic> payment;
  final AppLocalizations t;

  const _PaymentTile({required this.payment, required this.t});

  @override
  Widget build(BuildContext context) {
    final status          = payment['status']           as String? ?? 'pending';
    final year            = payment['year']             as int?    ?? DateTime.now().year;
    final amount          = payment['amount']           as String? ?? '0.00';
    final mode            = payment['payment_mode']     as String? ?? '';
    final rejectionReason = payment['rejection_reason'] as String? ?? '';
    final receiptUrl      = payment['receipt_image_url'] as String?;
    final color           = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Année + montant + icône statut ────────────────────
            Row(
              children: [
                Text(
                  year.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '$amount MRU',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(_statusIcon(status), color: color, size: 20),
              ],
            ),
            const SizedBox(height: 6),

            // ── Mode de paiement ──────────────────────────────────
            Text(
              _modeLabel(mode, t),
              style: const TextStyle(color: AppColors.textMid, fontSize: 13),
            ),
            const SizedBox(height: 10),

            // ── Badge statut ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                _statusLabelFor(status),
                style: TextStyle(
                  color:      color,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── Motif de rejet ────────────────────────────────────
            if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                rejectionReason,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon:  const Icon(Icons.refresh, size: 16),
                label: Text(t.translate('retry_payment')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize:    Size.zero,
                  tapTargetSize:  MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.push('/payment/submit'),
              ),
            ],

            // ── Voir reçu (si soumis) ─────────────────────────────
            if (status == 'submitted' && receiptUrl != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                icon:  const Icon(Icons.receipt_long, size: 16),
                label: const Text('Voir le reçu'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:        EdgeInsets.zero,
                  minimumSize:    Size.zero,
                  tapTargetSize:  MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.push('/payment/receipt', extra: receiptUrl),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabelFor(String status) => switch (status) {
    'paid'      => t.translate('card_status_paid'),
    'submitted' => t.translate('status_submitted'),
    'rejected'  => t.translate('status_rejected'),
    _           => t.translate('status_pending'),
  };
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
