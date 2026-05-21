import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/post_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../shared/widgets/ajvt_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

String _fmtDt(DateTime? dt, String lang) {
  if (dt == null) return '';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  if (lang == 'ar') {
    const months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${dt.day} ${months[dt.month]} ${dt.year} $h:$m';
  }
  const months = ['','Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
  return '${dt.day} ${months[dt.month]} ${dt.year} ${dt.hour}h${dt.minute == 0 ? '' : m}';
}

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _maxCtrl      = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  XFile?    _image;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context:     context,
      initialDate: initial ?? now.add(const Duration(days: 1)),
      firstDate:   now,
      lastDate:    now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      _locationCtrl.text.trim().isNotEmpty &&
      _startsAt != null &&
      _endsAt != null;

  Future<void> _submit(AppLocalizations t) async {
    if (!_isValid) return;
    final maxP = int.tryParse(_maxCtrl.text.trim());
    final ok = await ref.read(eventNotifierProvider.notifier).createEvent(
      title:           _titleCtrl.text.trim(),
      description:     _descCtrl.text.trim(),
      location:        _locationCtrl.text.trim(),
      startsAt:        _startsAt!,
      endsAt:          _endsAt!,
      maxParticipants: maxP,
      image:           _image,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(eventsProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.translate('create_success')),
        backgroundColor: AppColors.success,
      ));
    } else {
      final err = ref.read(eventNotifierProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err.error?.toString().replaceFirst('Exception: ', '') ?? t.translate('error')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t         = AppLocalizations.of(context);
    final lang      = Localizations.localeOf(context).languageCode;
    final isLoading = ref.watch(eventNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('create_event')),
        actions: const [LanguageToggle()],
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
                hint: t.translate('event_title_hint'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextField(
                controller:  _descCtrl,
                minLines:    4,
                maxLines:    null,
                onChanged:   (_) => setState(() {}),
                decoration:  InputDecoration(
                  hintText:       t.translate('event_desc_hint'),
                  border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 14),
              AjvtTextField(
                controller: _locationCtrl,
                hint: t.translate('event_location_hint'),
                prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textMid),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // ── Date de début ─────────────────────────────────────────
              _DateField(
                label:    t.translate('event_start'),
                value:    _fmtDt(_startsAt, lang),
                hint:     t.translate('select_start'),
                onTap: () async {
                  final dt = await _pickDateTime(_startsAt);
                  if (dt != null) setState(() => _startsAt = dt);
                },
              ),
              const SizedBox(height: 14),

              // ── Date de fin ───────────────────────────────────────────
              _DateField(
                label:    t.translate('event_end'),
                value:    _fmtDt(_endsAt, lang),
                hint:     t.translate('select_end'),
                onTap: () async {
                  final dt = await _pickDateTime(_endsAt ?? _startsAt);
                  if (dt != null) setState(() => _endsAt = dt);
                },
              ),
              const SizedBox(height: 14),

              // ── Max participants (optionnel) ───────────────────────────
              TextField(
                controller:  _maxCtrl,
                keyboardType: TextInputType.number,
                decoration:  InputDecoration(
                  hintText:       t.translate('event_max_hint'),
                  prefixIcon:     const Icon(Icons.people_outline, color: AppColors.textMid),
                  border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // ── Zone image ─────────────────────────────────────────────
              GestureDetector(
                onTap: () => _showSourceSheet(t),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary.withValues(alpha: 0.03),
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
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
              const SizedBox(height: 28),

              AjvtButton(
                label:     t.translate('create_event'),
                onPressed: _isValid ? () => _submit(t) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.value, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText:      label,
          prefixIcon:     const Icon(Icons.calendar_today_outlined, color: AppColors.textMid),
          border:         OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          value.isNotEmpty ? value : hint,
          style: TextStyle(
            fontSize: 14,
            color: value.isNotEmpty ? AppColors.textDark : AppColors.textLight,
          ),
        ),
      ),
    );
  }
}
