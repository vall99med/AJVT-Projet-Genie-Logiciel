import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/member_state.dart';
import '../../../features/auth/domain/auth_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/ajvt_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String phone;

  const RegisterScreen({super.key, required this.phone});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _nameCtrl         = TextEditingController();
  final _specialtyCtrl    = TextEditingController();
  final _studyLevelCtrl   = TextEditingController();
  final _jobTitleCtrl     = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  String _situation = 'student';
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    _studyLevelCtrl.dispose();
    _jobTitleCtrl.dispose();
    _neighborhoodCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{
      'phone': widget.phone,
      'full_name': _nameCtrl.text.trim(),
      'situation': _situation,
      'neighborhood': _neighborhoodCtrl.text.trim(),
      if (_situation == 'student') ...{
        'specialty': _specialtyCtrl.text.trim(),
        'study_level': _studyLevelCtrl.text.trim(),
      },
      if (_situation == 'employed')
        'job_title': _jobTitleCtrl.text.trim(),
    };
    final ok = await ref.read(memberNotifierProvider.notifier).register(data);
    if (!mounted) return;
    if (ok) {
      setState(() => _submitted = true);
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
    final isLoading = ref.watch(memberNotifierProvider).isLoading;
    final t = AppLocalizations.of(context);

    if (_submitted) return _SuccessView(onLogout: _logout, t: t);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('register_title')),
        actions: const [LanguageToggle()],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  AjvtTextField(
                    controller: _nameCtrl,
                    hint: t.translate('full_name'),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMid),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.translate('situation'),
                    style: const TextStyle(fontSize: 14, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 8),
                  _SituationSelector(
                    value: _situation,
                    onChanged: (v) => setState(() => _situation = v),
                    t: t,
                  ),
                  const SizedBox(height: 20),
                  if (_situation == 'student') ...[
                    AjvtTextField(
                      controller: _specialtyCtrl,
                      hint: t.translate('specialty'),
                      prefixIcon: const Icon(Icons.school_outlined, color: AppColors.textMid),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    AjvtTextField(
                      controller: _studyLevelCtrl,
                      hint: t.translate('study_level'),
                      prefixIcon: const Icon(Icons.grade_outlined, color: AppColors.textMid),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_situation == 'employed') ...[
                    AjvtTextField(
                      controller: _jobTitleCtrl,
                      hint: t.translate('job_title'),
                      prefixIcon: const Icon(Icons.work_outline, color: AppColors.textMid),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AjvtTextField(
                    controller: _neighborhoodCtrl,
                    hint: t.translate('neighborhood'),
                    prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 32),
                  AjvtButton(
                    label: t.translate('submit'),
                    isLoading: isLoading,
                    onPressed: _submit,
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

class _SituationSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final AppLocalizations t;

  const _SituationSelector({required this.value, required this.onChanged, required this.t});

  Widget _option(String sit, String labelKey, IconData icon) {
    final sel = value == sit;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(sit),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surface,
            border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: sel ? Colors.white : AppColors.textMid, size: 22),
              const SizedBox(height: 4),
              Text(
                t.translate(labelKey),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _option('student', 'student', Icons.school_outlined),
        const SizedBox(width: 8),
        _option('employed', 'employed', Icons.work_outline),
        const SizedBox(width: 8),
        _option('unemployed', 'unemployed', Icons.person_search_outlined),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onLogout;
  final AppLocalizations t;

  const _SuccessView({required this.onLogout, required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: AppColors.success),
              const SizedBox(height: 24),
              Text(
                t.translate('register_success'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.textDark, height: 1.6),
              ),
              const SizedBox(height: 40),
              AjvtButton(
                label: t.translate('logout'),
                backgroundColor: AppColors.textMid,
                onPressed: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
