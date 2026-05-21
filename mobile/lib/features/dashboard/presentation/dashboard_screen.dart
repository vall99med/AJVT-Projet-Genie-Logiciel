import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../member/domain/member_state.dart';
import '../../../features/auth/domain/auth_state.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../shared/widgets/main_nav_bar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync   = ref.watch(statsProvider);
    final pendingAsync = ref.watch(pendingMembersProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('dashboard_title')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: t.translate('members_list'),
            onPressed: () => context.push('/members'),
          ),
          const LanguageToggle(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.translate('logout'),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/phone');
            },
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 2),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          ref.invalidate(pendingMembersProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () {
              ref.invalidate(statsProvider);
              ref.invalidate(pendingMembersProvider);
            },
          ),
          data: (stats) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(t.translate('total_members')),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _StatCard(
                      label: t.translate('total_members'),
                      value: '${stats['total_members'] ?? 0}',
                      color: AppColors.primary,
                      icon: Icons.people,
                    ),
                    _StatCard(
                      label: t.translate('pending_members'),
                      value: '${stats['pending_members'] ?? 0}',
                      color: AppColors.warning,
                      icon: Icons.hourglass_empty,
                    ),
                    _StatCard(
                      label: t.translate('cotisation_paid'),
                      value: '${stats['members_paid_year'] ?? 0}',
                      color: AppColors.success,
                      icon: Icons.check_circle,
                    ),
                    _StatCard(
                      label: t.translate('total_cotisations'),
                      value: '${stats['total_cotisations_year'] ?? '0'} MRU',
                      color: const Color(0xFF7C3AED),
                      icon: Icons.account_balance_wallet,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _SectionTitle(t.translate('situation')),
                const SizedBox(height: 12),
                _SituationBreakdown(
                  stats: stats['by_situation'] as Map<String, dynamic>? ?? {},
                  total: (stats['total_members'] as int?) ?? 1,
                  t: t,
                ),

                const SizedBox(height: 24),
                _SectionTitle(t.translate('pending_list')),
                const SizedBox(height: 12),
                pendingAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text(
                    e.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: AppColors.error),
                  ),
                  data: (pending) => pending.isEmpty
                      ? _EmptyPending(t: t)
                      : _PendingList(
                          members: pending,
                          t: t,
                          onValidate: (id, approved, reason) async {
                            await ref
                                .read(memberRepositoryProvider)
                                .validateMember(id, approved, rejectionReason: reason);
                            ref.invalidate(pendingMembersProvider);
                            ref.invalidate(statsProvider);
                          },
                        ),
                ),

                const SizedBox(height: 24),
                _ExportButton(repo: ref.read(memberRepositoryProvider), t: t),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _SituationBreakdown extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int total;
  final AppLocalizations t;

  const _SituationBreakdown({required this.stats, required this.total, required this.t});

  @override
  Widget build(BuildContext context) {
    final student    = (stats['student']    as int?) ?? 0;
    final employed   = (stats['employed']   as int?) ?? 0;
    final unemployed = (stats['unemployed'] as int?) ?? 0;
    final safeTotal  = total > 0 ? total : 1;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _BarRow(t.translate('student'),    student,    safeTotal, AppColors.primary),
            const SizedBox(height: 10),
            _BarRow(t.translate('employed'),   employed,   safeTotal, AppColors.success),
            const SizedBox(height: 10),
            _BarRow(t.translate('unemployed'), unemployed, safeTotal, AppColors.warning),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BarRow(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = (count / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMid),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _EmptyPending extends StatelessWidget {
  final AppLocalizations t;
  const _EmptyPending({required this.t});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            t.translate('pending_list'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _PendingList extends StatelessWidget {
  final List<dynamic> members;
  final AppLocalizations t;
  final Future<void> Function(int id, bool approved, String? reason) onValidate;

  const _PendingList({
    required this.members,
    required this.t,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, i) => _PendingTile(
          member: members[i] as Map<String, dynamic>,
          t: t,
          onValidate: onValidate,
        ),
      ),
    );
  }
}

class _PendingTile extends StatefulWidget {
  final Map<String, dynamic> member;
  final AppLocalizations t;
  final Future<void> Function(int id, bool approved, String? reason) onValidate;

  const _PendingTile({
    required this.member,
    required this.t,
    required this.onValidate,
  });

  @override
  State<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends State<_PendingTile> {
  bool _loading = false;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.t.translate('approve')),
        content: Text(widget.t.translate('approve_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(widget.t.translate('approve')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await widget.onValidate(widget.member['id'] as int, true, null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.t.translate('validate_success')),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.t.translate('reject')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: widget.t.translate('reject_reason_hint'),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(widget.t.translate('reject')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await widget.onValidate(
        widget.member['id'] as int,
        false,
        reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.t.translate('reject_success')),
        backgroundColor: AppColors.warning,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name  = widget.member['full_name'] as String? ?? '—';
    final phone = widget.member['phone']     as String? ?? '';
    final sit   = widget.member['situation'] as String? ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.warning.withValues(alpha: 0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text('$phone · $sit',
          style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      trailing: _loading
          ? const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                  tooltip: widget.t.translate('approve'),
                  onPressed: _approve,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  tooltip: widget.t.translate('reject'),
                  onPressed: _reject,
                ),
              ],
            ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  final dynamic repo;
  final AppLocalizations t;

  const _ExportButton({required this.repo, required this.t});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _loading = false;

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      await widget.repo.exportExcel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.t.translate('export_excel')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download),
      label: Text(widget.t.translate('export_excel')),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _loading ? null : _export,
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMid)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.tr(context, 'retry')),
            ),
          ],
        ),
      ),
    );
  }
}
