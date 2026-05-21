import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/post_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/ajvt_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  XFile? _image;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1920);
    if (xFile != null) setState(() => _image = xFile);
  }

  Future<void> _showSourceSheet(AppLocalizations t) async {
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

  bool get _isValid => _titleCtrl.text.trim().isNotEmpty && _bodyCtrl.text.trim().isNotEmpty;

  Future<void> _submit({required bool publish}) async {
    if (!_isValid) return;
    final t  = AppLocalizations.of(context);
    final ok = await ref.read(postNotifierProvider.notifier).createPost(
      title:             _titleCtrl.text.trim(),
      body:              _bodyCtrl.text.trim(),
      image:             _image,
      publishAfterCreate: publish,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(postsProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(publish ? t.translate('publish_success') : t.translate('create_success')),
        backgroundColor: AppColors.success,
      ));
    } else {
      final err = ref.read(postNotifierProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.error?.toString().replaceFirst('Exception: ', '') ?? t.translate('error')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t         = AppLocalizations.of(context);
    final isLoading = ref.watch(postNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('create_post')),
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
        isLoading: isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AjvtTextField(
                controller: _titleCtrl,
                hint: t.translate('post_title_hint'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextField(
                controller:  _bodyCtrl,
                minLines:    6,
                maxLines:    null,
                onChanged:   (_) => setState(() {}),
                decoration:  InputDecoration(
                  hintText:        t.translate('post_body_hint'),
                  border:          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding:  const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),

              // ── Zone image ────────────────────────────────────────────
              GestureDetector(
                onTap: () => _showSourceSheet(t),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary.withValues(alpha: 0.03),
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 38, color: AppColors.primary),
                            const SizedBox(height: 8),
                            Text(t.translate('image_optional'), style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
                          ],
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(File(_image!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                            ),
                            Positioned(
                              top: 6, right: 6,
                              child: GestureDetector(
                                onTap: () => setState(() => _image = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Boutons ───────────────────────────────────────────────
              AjvtButton(
                label:     t.translate('publish'),
                onPressed: _isValid ? () => _submit(publish: true) : null,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isValid ? () => _submit(publish: false) : null,
                style: OutlinedButton.styleFrom(
                  minimumSize:     const Size(double.infinity, 52),
                  foregroundColor: AppColors.primary,
                  side:            const BorderSide(color: AppColors.primary),
                  shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(t.translate('save_draft')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
