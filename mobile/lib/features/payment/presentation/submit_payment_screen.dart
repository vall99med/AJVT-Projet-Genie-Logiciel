import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/payment_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../member/domain/member_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class _ModeData {
  final String key;
  final Color  color;
  const _ModeData(this.key, this.color);
}

const _modes = [
  _ModeData('bankily',  Color(0xFF0B7BDC)),
  _ModeData('masrivi',  Color(0xFFFF6B00)),
  _ModeData('sedad',    Color(0xFF00A651)),
  _ModeData('bimbank',  Color(0xFF1B3A6B)),
  _ModeData('clique',   Color(0xFF7B2D8B)),
  _ModeData('amanty',   Color(0xFF009688)),
  _ModeData('cash',     Color(0xFF388E3C)),
  _ModeData('transfer', Color(0xFF607D8B)),
];

String _modeLabel(String key, AppLocalizations t) => switch (key) {
  'cash'     => t.translate('cash_mode'),
  'transfer' => t.translate('transfer_mode'),
  'bimbank'  => 'BimBank',
  _          => key.isNotEmpty ? '${key[0].toUpperCase()}${key.substring(1)}' : key,
};

class SubmitPaymentScreen extends ConsumerStatefulWidget {
  const SubmitPaymentScreen({super.key});

  @override
  ConsumerState<SubmitPaymentScreen> createState() => _SubmitPaymentScreenState();
}

class _SubmitPaymentScreenState extends ConsumerState<SubmitPaymentScreen> {
  String? _selectedMode;
  XFile?  _receipt;
  final   _refCtrl = TextEditingController();

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await ImagePicker().pickImage(
      source:       source,
      imageQuality: 85,
      maxWidth:     1920,
    );
    if (xFile != null) setState(() => _receipt = xFile);
  }

  Future<void> _showSourceSheet() async {
    final t = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.translate('receipt_gallery')),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(t.translate('receipt_camera')),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedMode == null || _receipt == null) return;
    final ok = await ref.read(paymentNotifierProvider.notifier).submitPayment(
      year:           DateTime.now().year,
      amount:         1000.0,
      paymentMode:    _selectedMode!,
      receiptImage:   _receipt!,
      transactionRef: _refCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(cardProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.tr(context, 'payment_submitted')),
        backgroundColor: AppColors.success,
      ));
    } else {
      final err = ref.read(paymentNotifierProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          err.error?.toString().replaceFirst('Exception: ', '') ??
              AppLocalizations.tr(context, 'error'),
        ),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t          = AppLocalizations.of(context);
    final isMutating = ref.watch(paymentNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('payment_title')),
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
      body: LoadingOverlay(
        isLoading: isMutating,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Montant ────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    const Text(
                      '1 000 MRU',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      DateTime.now().year.toString(),
                      style: const TextStyle(color: AppColors.textMid, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Mode de paiement ───────────────────────────────────
              Text(
                t.translate('payment_mode'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount:  2,
                shrinkWrap:      true,
                physics:         const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: _modes.map((m) {
                  final selected = _selectedMode == m.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMode = m.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? m.color.withValues(alpha: 0.12)
                            : AppColors.surface,
                        border: Border.all(
                          color: selected ? m.color : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _modeLabel(m.key, t),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? m.color : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Référence transaction (optionnel) ──────────────────
              TextField(
                controller: _refCtrl,
                decoration: InputDecoration(
                  hintText: t.translate('transaction_ref'),
                  prefixIcon: const Icon(Icons.tag, color: AppColors.textMid),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Zone upload reçu ───────────────────────────────────
              GestureDetector(
                onTap: _showSourceSheet,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary.withValues(alpha: 0.03),
                  ),
                  child: _receipt == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_a_photo_outlined,
                              size: 40,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                t.translate('receipt_upload'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textMid,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(
                                File(_receipt!.path),
                                fit: BoxFit.cover,
                                width:  double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _receipt = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color:  Colors.black54,
                                    shape:  BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Bouton Envoyer ─────────────────────────────────────
              AjvtButton(
                label:     t.translate('submit'),
                onPressed: (_selectedMode != null && _receipt != null) ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
