import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/auth_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/ajvt_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

enum _AuthMode { connexion, inscription }

class PhoneScreen extends ConsumerStatefulWidget {
  final bool startWithLogin;
  const PhoneScreen({super.key, this.startWithLogin = true});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  late _AuthMode _mode;
  final _controller = TextEditingController();
  final _formKey    = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _mode = widget.startWithLogin ? _AuthMode.connexion : _AuthMode.inscription;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.tr(context, 'phone_invalid');
    }
    final v = value.trim();
    if (!v.startsWith('+')) return AppLocalizations.tr(context, 'phone_invalid');
    final digits = v.substring(1).replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return AppLocalizations.tr(context, 'phone_invalid');
    }
    if (digits.length < 7 || digits.length > 15) {
      return AppLocalizations.tr(context, 'phone_invalid');
    }
    return null;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _controller.text.trim();

    if (_mode == _AuthMode.connexion) {
      context.push('/pin', extra: {
        'phone':   phone,
        'isLogin': true,
        'isReset': false,
        'otpCode': null,
      });
      return;
    }

    // Inscription : envoyer OTP
    await ref.read(authNotifierProvider.notifier).sendOtp(phone);
    if (!mounted) return;
    final s = ref.read(authNotifierProvider);
    if (s.status == AuthStatus.otpSent) {
      ref.read(authNotifierProvider.notifier).reset();
      context.push('/otp', extra: {'phone': phone, 'mode': 'signup'});
    } else if (s.status == AuthStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.errorMessage ?? AppLocalizations.tr(context, 'error')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading   = ref.watch(authNotifierProvider).isLoading;
    final t           = AppLocalizations.of(context);
    final isConnexion = _mode == _AuthMode.connexion;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [LanguageToggle()],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height
                    - MediaQuery.of(context).padding.top
                    - kToolbarHeight
                    - MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),

                      // ── Logo ────────────────────────────────────────────
                      Image.asset(
                        'assets/images/AJVT-logo.jpeg',
                        height: 120,
                        width: 120,
                      ),

                      const Spacer(flex: 2),

                      // ── Toggle Connexion / Inscription ───────────────────
                      SegmentedButton<_AuthMode>(
                        segments: [
                          ButtonSegment(
                            value: _AuthMode.connexion,
                            icon: const Icon(Icons.login, size: 18),
                            label: Text(t.translate('mode_login')),
                          ),
                          ButtonSegment(
                            value: _AuthMode.inscription,
                            icon: const Icon(Icons.person_add_outlined, size: 18),
                            label: Text(t.translate('mode_signup')),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) {
                          setState(() {
                            _mode = s.first;
                            _controller.clear();
                            _formKey.currentState?.reset();
                          });
                        },
                        style: SegmentedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textMid,
                          selectedForegroundColor: AppColors.primary,
                          selectedBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          side: const BorderSide(color: AppColors.border, width: 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Titre contextuel ─────────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(_mode),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnexion
                                  ? t.translate('login_welcome_back')
                                  : t.translate('signup_join_title'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isConnexion
                                  ? t.translate('login_subtitle')
                                  : t.translate('signup_subtitle'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMid,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Champ téléphone ──────────────────────────────────
                      AjvtTextField(
                        controller: _controller,
                        hint: t.translate('phone_hint'),
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.textMid,
                        ),
                        validator: _validatePhone,
                      ),

                      const SizedBox(height: 20),

                      // ── Bouton principal ─────────────────────────────────
                      AjvtButton(
                        label: isConnexion
                            ? t.translate('login_button')
                            : t.translate('continue'),
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),

                      // ── Aide contexte inscription ────────────────────────
                      if (!isConnexion) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: AppColors.textLight),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t.translate('signup_otp_hint'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
