import 'dart:async';
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

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String mode;

  const OtpScreen({super.key, required this.phone, this.mode = 'signup'});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  String _otp = '';
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown == 0) { t.cancel(); } else { setState(() => _countdown--); }
    });
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    return '${phone.substring(0, phone.length - 6)}***${phone.substring(phone.length - 3)}';
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;

    if (widget.mode == 'reset') {
      if (!mounted) return;
      context.push('/pin', extra: {
        'phone': widget.phone,
        'isLogin': false,
        'isReset': true,
        'otpCode': _otp,
      });
      return;
    }

    await ref.read(authNotifierProvider.notifier).verifyOtp(widget.phone, _otp);
    if (!mounted) return;
    final s = ref.read(authNotifierProvider);
    if (s.status == AuthStatus.otpVerified) {
      ref.read(authNotifierProvider.notifier).reset();
      context.push('/pin', extra: {
        'phone': widget.phone,
        'isLogin': false,
        'isReset': false,
        'otpCode': null,
      });
    } else if (s.status == AuthStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.errorMessage ?? AppLocalizations.tr(context, 'otp_invalid')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resend() async {
    _controller.clear();
    setState(() => _otp = '');
    if (widget.mode == 'reset') {
      await ref.read(authNotifierProvider.notifier).sendResetOtp(widget.phone);
    } else {
      await ref.read(authNotifierProvider.notifier).sendOtp(widget.phone);
    }
    if (!mounted) return;
    ref.read(authNotifierProvider.notifier).reset();
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.tr(context, 'otp_resend')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final t = AppLocalizations.of(context);

    final defaultTheme = PinTheme(
      width: 52,
      height: 52,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
    );

    final focusedTheme = PinTheme(
      width: 52,
      height: 52,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(t.translate('otp_title')),
        actions: const [LanguageToggle()],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  t.translate('otp_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('otp_subtitle')} ${_maskPhone(widget.phone)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textMid, height: 1.6),
                ),
                const SizedBox(height: 36),
                Center(
                  child: Pinput(
                    controller: _controller,
                    length: 6,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: defaultTheme,
                    focusedPinTheme: focusedTheme,
                    onChanged: (v) => setState(() => _otp = v),
                  ),
                ),
                const SizedBox(height: 32),
                AjvtButton(
                  label: t.translate('confirm'),
                  isLoading: isLoading,
                  onPressed: _otp.length == 6 ? _verify : null,
                ),
                const SizedBox(height: 20),
                Center(
                  child: _countdown > 0
                      ? Text(
                          '${t.translate('otp_resend_in')} $_countdown s',
                          style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                        )
                      : TextButton(
                          onPressed: _resend,
                          child: Text(
                            t.translate('otp_resend'),
                            style: const TextStyle(color: AppColors.primary, fontSize: 14),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
