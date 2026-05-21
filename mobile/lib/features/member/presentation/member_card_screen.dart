import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/member_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class MemberCardScreen extends ConsumerWidget {
  const MemberCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardAsync = ref.watch(cardProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('card_title')),
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
      body: cardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(cardProvider),
        ),
        data: (card) {
          final status          = card['cotisation_status'] as String? ?? 'pending';
          final rejectionReason = card['rejection_reason']  as String? ?? '';

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cardProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _MemberCard(card: card, t: t),
                  const SizedBox(height: 28),
                  _CotisationBanner(
                    status:          status,
                    rejectionReason: rejectionReason,
                    t:               t,
                  ),
                  const SizedBox(height: 16),
                  _InfoGrid(card: card, t: t),
                  if (status == 'pending' || status == 'rejected') ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon:  const Icon(Icons.payment),
                      label: Text(t.translate('payment_title')),
                      style: ElevatedButton.styleFrom(
                        minimumSize:     const Size(double.infinity, 52),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => context.push('/payment/submit'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final AppLocalizations t;

  const _MemberCard({required this.card, required this.t});

  String get _status => (card['cotisation_status'] as String?) ?? 'pending';

  List<Color> get _gradientColors => switch (_status) {
    'paid'      => [const Color(0xFF15803D), const Color(0xFF0F5132)],
    'submitted' => [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
    'rejected'  => [const Color(0xFFB91C1C), const Color(0xFF7F1D1D)],
    _           => [const Color(0xFFB45309), const Color(0xFF78350F)],
  };

  String _situationLabel(String s) => switch (s) {
    'student'    => t.translate('student'),
    'employed'   => t.translate('employed'),
    'unemployed' => t.translate('unemployed'),
    _            => s,
  };

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    return '${phone.substring(0, phone.length - 6)}***${phone.substring(phone.length - 3)}';
  }

  String _memberId(dynamic id) =>
      'AJVT-${(id ?? 0).toString().padLeft(5, '0')}';

  @override
  Widget build(BuildContext context) {
    final memberId  = card['member_id'];
    final name      = card['full_name']      as String? ?? '—';
    final phone     = card['phone']           as String? ?? '';
    final region    = card['neighborhood']    as String? ?? '—';
    final situation = card['situation']       as String? ?? '';
    final detail    = card['detail']          as String? ?? '';
    final year      = card['cotisation_year'] as int?    ?? DateTime.now().year;
    final since     = card['member_since']    as int?    ?? year;

    return Container(
      width:  double.infinity,
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcATop,
                      ),
                      child: Image.asset(
                        'assets/images/AJVT-logo.jpeg',
                        height: 48,
                        width: 48,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.translate('card_title').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white60, fontSize: 9, letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    year.toString(),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Identité ───────────────────────────────────────────
            Text(
              name,
              style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              detail.isNotEmpty
                  ? '${_situationLabel(situation)}  ·  $detail'
                  : _situationLabel(situation),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 18),

            // ── Bas de carte ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _maskPhone(phone),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 13, letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 11),
                        const SizedBox(width: 3),
                        Text(region,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t.translate('member_since'),
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                    Text(
                      since.toString(),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── ID membre ──────────────────────────────────────────
            Text(
              _memberId(memberId),
              style: const TextStyle(
                color: Colors.white38, fontSize: 10,
                letterSpacing: 1.5, fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Map<String, dynamic> card;
  final AppLocalizations t;

  const _InfoGrid({required this.card, required this.t});

  @override
  Widget build(BuildContext context) {
    final situation = card['situation']    as String? ?? '';
    final detail    = card['detail']       as String? ?? '';
    final region    = card['neighborhood'] as String? ?? '—';
    final since     = card['member_since'] as int?    ?? DateTime.now().year;

    final rows = <_InfoRow>[
      _InfoRow(Icons.location_on_outlined, t.translate('neighborhood'), region),
      if (detail.isNotEmpty)
        _InfoRow(
          situation == 'student' ? Icons.school_outlined : Icons.work_outline,
          situation == 'student' ? t.translate('specialty') : t.translate('job_title'),
          detail,
        ),
      _InfoRow(Icons.calendar_today_outlined, t.translate('member_since'), since.toString()),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: rows
              .map((r) => _InfoTile(icon: r.icon, label: r.label, value: r.value))
              .toList(),
        ),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _CotisationBanner extends StatelessWidget {
  final String status;
  final String rejectionReason;
  final AppLocalizations t;

  const _CotisationBanner({
    required this.status,
    required this.rejectionReason,
    required this.t,
  });

  Color get _color => switch (status) {
    'paid'      => AppColors.success,
    'submitted' => AppColors.primary,
    'rejected'  => AppColors.error,
    _           => AppColors.warning,
  };

  IconData get _icon => switch (status) {
    'paid'      => Icons.check_circle,
    'submitted' => Icons.access_time,
    'rejected'  => Icons.cancel,
    _           => Icons.access_time,
  };

  String _statusText() => switch (status) {
    'paid'      => t.translate('card_status_paid'),
    'submitted' => t.translate('status_submitted'),
    'rejected'  => t.translate('status_rejected'),
    _           => t.translate('card_status_pending'),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _color.withValues(alpha: 0.1),
        border:       Border.all(color: _color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText(),
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _color,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rejectionReason,
              style: TextStyle(fontSize: 13, color: _color.withValues(alpha: 0.85)),
            ),
          ],
        ],
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
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
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
