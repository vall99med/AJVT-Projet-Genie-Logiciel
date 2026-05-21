import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/member_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class MembersListScreen extends ConsumerStatefulWidget {
  const MembersListScreen({super.key});

  @override
  ConsumerState<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends ConsumerState<MembersListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<dynamic> _filter(List<dynamic> members) {
    if (_query.isEmpty) return members;
    final q = _query.toLowerCase();
    return members.where((m) {
      final member = m as Map<String, dynamic>;
      final name  = (member['full_name']    as String? ?? '').toLowerCase();
      final city  = (member['neighborhood'] as String? ?? '').toLowerCase();
      final sit   = (member['situation']    as String? ?? '').toLowerCase();
      return name.contains(q) || city.contains(q) || sit.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(activeMembersProvider);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('members_list')),
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
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            hint: t.translate('search_hint'),
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(activeMembersProvider),
              ),
              data: (all) {
                final members = _filter(all);
                if (members.isEmpty) {
                  return Center(
                    child: Text(
                      t.translate('no_members'),
                      style: const TextStyle(color: AppColors.textLight, fontSize: 15),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(activeMembersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: members.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72, endIndent: 16),
                    itemBuilder: (_, i) =>
                        _MemberTile(member: members[i] as Map<String, dynamic>, t: t),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final AppLocalizations t;

  const _MemberTile({required this.member, required this.t});

  Color _situationColor(String s) => switch (s) {
        'student'    => AppColors.primary,
        'employed'   => AppColors.success,
        'unemployed' => AppColors.warning,
        _            => AppColors.textMid,
      };

  String _situationLabel(String s) => switch (s) {
        'student'    => t.translate('student'),
        'employed'   => t.translate('employed'),
        'unemployed' => t.translate('unemployed'),
        _            => s,
      };

  @override
  Widget build(BuildContext context) {
    final name      = member['full_name']    as String? ?? '—';
    final city      = member['neighborhood'] as String? ?? '';
    final situation = member['situation']    as String? ?? '';
    final color     = _situationColor(situation);
    final initials  = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          initials,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
      ),
      subtitle: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _situationLabel(situation),
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(width: 8),
            const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textLight),
            const SizedBox(width: 2),
            Text(
              city,
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
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
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMid)),
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
