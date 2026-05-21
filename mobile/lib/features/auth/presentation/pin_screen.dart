import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../domain/auth_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class PinScreen extends ConsumerStatefulWidget {
  final String phone;
  final bool isLogin;
  final bool isReset;
  final String? otpCode;

  const PinScreen({
    super.key,
    required this.phone,
    this.isLogin = false,
    this.isReset = false,
    this.otpCode,
  });

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pinCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _pin     = '';
  String _confirm = '';

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);

    if (widget.isLogin) {
      if (_pin.length != 4) return;
      await ref.read(authNotifierProvider.notifier).login(widget.phone, _pin);
      if (!mounted) return;
      final s = ref.read(authNotifierProvider);
      if (s.status == AuthStatus.authenticated) {
        context.go('/feed');
      } else if (s.status == AuthStatus.error) {
        _showError(s.errorMessage ?? t.translate('error'));
      }
      return;
    }

    if (widget.isReset) {
      if (_pin.length != 4 || _confirm.length != 4) return;
      if (_pin != _confirm) { _showError(t.translate('pin_mismatch')); return; }
      await ref.read(authNotifierProvider.notifier).resetPin(widget.phone, widget.otpCode ?? '', _pin);
      if (!mounted) return;
      final s = ref.read(authNotifierProvider);
      if (s.status == AuthStatus.pinReset) {
        ref.read(authNotifierProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.translate('confirm')), backgroundColor: AppColors.success),
        );
        context.go('/login');
      } else if (s.status == AuthStatus.error) {
        _showError(s.errorMessage ?? t.translate('error'));
      }
      return;
    }

    if (_pin.length != 4 || _confirm.length != 4) return;
    if (_pin != _confirm) { _showError(AppLocalizations.tr(context, 'pin_mismatch')); return; }
    await ref.read(authNotifierProvider.notifier).setPin(widget.phone, _pin);
    if (!mounted) return;
    final s = ref.read(authNotifierProvider);
    if (s.status == AuthStatus.pinSet) {
      ref.read(authNotifierProvider.notifier).reset();
      context.go('/register', extra: widget.phone);
    } else if (s.status == AuthStatus.error) {
      _showError(s.errorMessage ?? t.translate('error'));
    }
  }

  Future<void> _forgotPin() async {
    await ref.read(authNotifierProvider.notifier).sendResetOtp(widget.phone);
    if (!mounted) return;
    final s = ref.read(authNotifierProvider);
    if (s.status == AuthStatus.otpSent) {
      ref.read(authNotifierProvider.notifier).reset();
      context.push('/otp', extra: {'phone': widget.phone, 'mode': 'reset'});
    } else if (s.status == AuthStatus.error) {
      _showError(s.errorMessage ?? AppLocalizations.tr(context, 'error'));
    }
  }

  PinTheme get _defaultTheme => PinTheme(
        width: 64, height: 64,
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
        ),
      );

  PinTheme get _focusedTheme => PinTheme(
        width: 64, height: 64,
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surface,
        ),
      );

  Widget _pinput({
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    bool autofocus = false,
  }) =>
      Pinput(
        controller: ctrl,
        length: 4,
        obscureText: true,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        defaultPinTheme: _defaultTheme,
        focusedPinTheme: _focusedTheme,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final t = AppLocalizations.of(context);

    final bool canSubmit = widget.isLogin
        ? _pin.length == 4
        : _pin.length == 4 && _confirm.length == 4;

    final String title = widget.isLogin
        ? t.translate('pin_login_title')
        : widget.isReset
            ? t.translate('pin_create_title')
            : t.translate('pin_create_title');

    final String subtitle = widget.isLogin
        ? ''
        : t.translate('pin_create_subtitle');

    final String buttonLabel = widget.isLogin
        ? t.translate('login_button')
        : t.translate('confirm');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        actions: const [LanguageToggle()],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMid),
                  ),
                ],
                const SizedBox(height: 36),
                Center(
                  child: _pinput(
                    ctrl: _pinCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _pin = v),
                  ),
                ),
                if (!widget.isLogin) ...[
                  const SizedBox(height: 24),
                  Text(
                    t.translate('pin_confirm_label'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMid),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: _pinput(
                      ctrl: _confirmCtrl,
                      onChanged: (v) => setState(() => _confirm = v),
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                AjvtButton(
                  label: buttonLabel,
                  isLoading: isLoading,
                  onPressed: canSubmit ? _submit : null,
                ),
                if (widget.isLogin) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isLoading ? null : _forgotPin,
                    child: Text(
                      t.translate('pin_forgot'),
                      style: const TextStyle(color: AppColors.textMid, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
