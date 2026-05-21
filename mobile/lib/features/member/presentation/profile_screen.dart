import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/member_state.dart';
import '../../../features/auth/domain/auth_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/ajvt_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../shared/widgets/main_nav_bar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  final _neighborhoodCtrl = TextEditingController();
  final _specialtyCtrl    = TextEditingController();
  final _studyLevelCtrl   = TextEditingController();
  final _jobTitleCtrl     = TextEditingController();

  @override
  void dispose() {
    _neighborhoodCtrl.dispose();
    _specialtyCtrl.dispose();
    _studyLevelCtrl.dispose();
    _jobTitleCtrl.dispose();
    super.dispose();
  }

  void _enterEdit(Map<String, dynamic> profile) {
    _neighborhoodCtrl.text = profile['neighborhood'] as String? ?? '';
    _specialtyCtrl.text    = profile['specialty']    as String? ?? '';
    _studyLevelCtrl.text   = profile['study_level']  as String? ?? '';
    _jobTitleCtrl.text     = profile['job_title']    as String? ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save(Map<String, dynamic> profile) async {
    final situation = profile['situation'] as String? ?? '';
    final data = <String, dynamic>{
      'neighborhood': _neighborhoodCtrl.text.trim(),
      if (situation == 'student') ...{
        'specialty':   _specialtyCtrl.text.trim(),
        'study_level': _studyLevelCtrl.text.trim(),
      },
      if (situation == 'employed')
        'job_title': _jobTitleCtrl.text.trim(),
    };
    final ok = await ref.read(memberNotifierProvider.notifier).updateProfile(data);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(profileProvider);
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.tr(context, 'save')),
        backgroundColor: AppColors.success,
      ));
    } else {
      final err = ref.read(memberNotifierProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          err.error?.toString().replaceFirst('Exception: ', '') ??
              AppLocalizations.tr(context, 'error'),
        ),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    if (!mounted) return;
    context.go('/phone');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final isMutating   = ref.watch(memberNotifierProvider).isLoading;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('profile_title')),
        automaticallyImplyLeading: false,
        actions: [
          const LanguageToggle(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.translate('logout'),
            onPressed: _logout,
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 3),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) => LoadingOverlay(
          isLoading: isMutating,
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(profileProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Avatar(name: profile['full_name'] as String? ?? '?'),
                  const SizedBox(height: 20),
                  if (_editing)
                    _EditForm(
                      profile: profile,
                      neighborhoodCtrl: _neighborhoodCtrl,
                      specialtyCtrl: _specialtyCtrl,
                      studyLevelCtrl: _studyLevelCtrl,
                      jobTitleCtrl: _jobTitleCtrl,
                      onSave: () => _save(profile),
                      onCancel: () => setState(() => _editing = false),
                      t: t,
                    )
                  else
                    _ProfileInfo(
                      profile: profile,
                      onEdit: () => _enterEdit(profile),
                      t: t,
                    ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.card_membership),
                    label: Text(t.translate('card_title')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.push('/card'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.people_outline),
                    label: Text(t.translate('members_list')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.push('/members'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Center(
      child: CircleAvatar(
        radius: 44,
        backgroundColor: AppColors.primary,
        child: Text(initials, style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;
  final AppLocalizations t;

  const _ProfileInfo({required this.profile, required this.onEdit, required this.t});

  String _situationLabel(String s) => switch (s) {
        'student'    => t.translate('student'),
        'employed'   => t.translate('employed'),
        'unemployed' => t.translate('unemployed'),
        _            => s,
      };

  Color _statusColor(String s) => switch (s) {
        'active'   => AppColors.success,
        'pending'  => AppColors.warning,
        'rejected' => AppColors.error,
        _          => AppColors.textMid,
      };

  IconData _statusIcon(String s) => switch (s) {
        'active'   => Icons.check_circle,
        'pending'  => Icons.hourglass_empty,
        'rejected' => Icons.cancel,
        _          => Icons.info_outline,
      };

  String _statusLabel(String s) => switch (s) {
        'active'   => t.translate('card_valid'),
        'pending'  => t.translate('status_pending'),
        'rejected' => t.translate('status_rejected'),
        _          => s,
      };

  @override
  Widget build(BuildContext context) {
    final status    = profile['status']    as String? ?? '';
    final situation = profile['situation'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(t.translate('full_name'),     profile['full_name'] as String? ?? '-'),
            _InfoRow('Tél',                        profile['phone']     as String? ?? '-'),
            _InfoRow(t.translate('situation'),     _situationLabel(situation)),
            if (situation == 'student') ...[
              _InfoRow(t.translate('specialty'),   profile['specialty']   as String? ?? '-'),
              _InfoRow(t.translate('study_level'), profile['study_level'] as String? ?? '-'),
            ],
            if (situation == 'employed')
              _InfoRow(t.translate('job_title'),   profile['job_title']   as String? ?? '-'),
            _InfoRow(t.translate('neighborhood'),  profile['neighborhood'] as String? ?? '-'),
            const Divider(height: 24),
            Row(
              children: [
                Icon(_statusIcon(status), size: 16, color: _statusColor(status)),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _statusColor(status)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AjvtButton(label: t.translate('edit_profile'), onPressed: onEdit),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  final Map<String, dynamic> profile;
  final TextEditingController neighborhoodCtrl;
  final TextEditingController specialtyCtrl;
  final TextEditingController studyLevelCtrl;
  final TextEditingController jobTitleCtrl;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final AppLocalizations t;

  const _EditForm({
    required this.profile,
    required this.neighborhoodCtrl,
    required this.specialtyCtrl,
    required this.studyLevelCtrl,
    required this.jobTitleCtrl,
    required this.onSave,
    required this.onCancel,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final situation = profile['situation'] as String? ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AjvtTextField(
              controller: neighborhoodCtrl,
              hint: t.translate('neighborhood'),
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textMid),
            ),
            if (situation == 'student') ...[
              const SizedBox(height: 12),
              AjvtTextField(
                controller: specialtyCtrl,
                hint: t.translate('specialty'),
                prefixIcon: const Icon(Icons.school_outlined, color: AppColors.textMid),
              ),
              const SizedBox(height: 12),
              AjvtTextField(
                controller: studyLevelCtrl,
                hint: t.translate('study_level'),
                prefixIcon: const Icon(Icons.grade_outlined, color: AppColors.textMid),
              ),
            ],
            if (situation == 'employed') ...[
              const SizedBox(height: 12),
              AjvtTextField(
                controller: jobTitleCtrl,
                hint: t.translate('job_title'),
                prefixIcon: const Icon(Icons.work_outline, color: AppColors.textMid),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(t.translate('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: AjvtButton(label: t.translate('save'), onPressed: onSave)),
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
