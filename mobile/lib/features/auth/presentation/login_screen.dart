import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/ajvt_text_field.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.tr(context, 'phone_invalid');
    }
    final v = value.trim();
    if (!v.startsWith('+')) return AppLocalizations.tr(context, 'phone_invalid');
    final digits = v.substring(1).replaceAll(RegExp(r'\s'), '');
    if (digits.length < 7 || digits.length > 15) {
      return AppLocalizations.tr(context, 'phone_invalid');
    }
    return null;
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _controller.text.trim();
    context.push('/pin', extra: {
      'phone': phone,
      'isLogin': true,
      'isReset': false,
      'otpCode': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [LanguageToggle()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Image.asset(
                  'assets/images/AJVT-logo.jpeg',
                  height: 120,
                  width: 120,
                ),
                const Spacer(flex: 2),
                Text(
                  t.translate('pin_login_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 28),
                AjvtTextField(
                  controller: _controller,
                  hint: t.translate('phone_hint'),
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textMid),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 20),
                AjvtButton(
                  label: t.translate('continue'),
                  onPressed: _continue,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/phone'),
                  child: Text(
                    t.translate('already_member'),
                    style: const TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
