import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/post_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../shared/widgets/ajvt_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

String _fmtDateFull(String? iso, String lang) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    if (lang == 'ar') {
      const months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      return '${dt.day} ${months[dt.month]} ${dt.year} — $h:$m';
    }
    const months = ['','Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    return '${dt.day} ${months[dt.month]} ${dt.year} à ${dt.hour}h${dt.minute == 0 ? '' : m}';
  } catch (_) {
    return '';
  }
}

class EventDetailScreen extends ConsumerWidget {
  final int id;
  const EventDetailScreen({required this.id, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(id));
    final role       = ref.watch(authNotifierProvider).role ?? '';
    final isAdminMod = role == 'admin' || role == 'moderator';
    final lang       = Localizations.localeOf(context).languageCode;
    final t          = AppLocalizations.of(context);

    return eventAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(e.toString().replaceFirst('Exception: ', ''), style: const TextStyle(color: AppColors.error))),
      ),
      data: (event) {
        final title           = event['title']              as String? ?? '';
        final description     = event['description']        as String? ?? '';
        final location        = event['location']           as String? ?? '';
        final imageUrl        = event['image_url']          as String?;
        final startsAt        = event['starts_at']          as String?;
        final endsAt          = event['ends_at']            as String?;
        final maxP            = event['max_participants']   as int?;
        final count           = event['participants_count'] as int? ?? 0;
        final isParticipating = event['is_participating']   as bool? ?? false;
        final status          = event['status']             as String? ?? '';
        final isFull          = maxP != null && count >= maxP;
        final isPast          = status == 'past' || status == 'cancelled';
        final hasImage        = imageUrl != null;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: hasImage ? 250 : 0,
                pinned:         true,
                backgroundColor: hasImage ? Colors.transparent : AppColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: hasImage
                    ? FlexibleSpaceBar(
                        background: CachedNetworkImage(
                          imageUrl:    imageUrl,
                          fit:         BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surface),
                        ),
                      )
                    : null,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      _InfoRow(icon: Icons.schedule, text: _fmtDateFull(startsAt, lang)),
                      if (endsAt != null)
                        _InfoRow(icon: Icons.flag_outlined, text: _fmtDateFull(endsAt, lang)),
                      if (location.isNotEmpty)
                        _InfoRow(icon: Icons.location_on_outlined, text: location),
                      const SizedBox(height: 16),

                      // ── Barre de progression participants ─────────────
                      if (maxP != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$count / $maxP ${t.translate('participants_label')}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
                            if (isFull)
                              Text(t.translate('event_full'),
                                  style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (count / maxP).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(isFull ? AppColors.error : AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Text('$count ${t.translate('participants_label')}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
                        const SizedBox(height: 16),
                      ],

                      const Divider(),
                      const SizedBox(height: 12),
                      Text(description, style: const TextStyle(fontSize: 15, color: AppColors.textMid, height: 1.7)),
                      const SizedBox(height: 16),

                      if (isAdminMod)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.checklist),
                          label: Text(t.translate('manage_attendance')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => context.push('/event/$id/attendance'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bouton sticky Join/Leave ──────────────────────────────────
          bottomNavigationBar: isPast
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _JoinLeaveButton(
                      eventId:        id,
                      isParticipating: isParticipating,
                      isFull:         isFull,
                      t:              t,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textLight),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMid))),
        ],
      ),
    );
  }
}

class _JoinLeaveButton extends ConsumerWidget {
  final int eventId;
  final bool isParticipating;
  final bool isFull;
  final AppLocalizations t;

  const _JoinLeaveButton({
    required this.eventId,
    required this.isParticipating,
    required this.isFull,
    required this.t,
  });

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (isParticipating) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(t.translate('leave_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.translate('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(t.translate('leave_event')),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await ref.read(eventNotifierProvider.notifier).leaveEvent(eventId);
    } else {
      await ref.read(eventNotifierProvider.notifier).joinEvent(eventId);
    }
    ref.invalidate(eventDetailProvider(eventId));
    ref.invalidate(eventsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(eventNotifierProvider).isLoading;

    return AjvtButton(
      label:           isParticipating ? t.translate('leave_event') : t.translate('join_event'),
      isLoading:       isLoading,
      onPressed:       (isFull && !isParticipating) ? null : () => _toggle(context, ref),
      backgroundColor: isParticipating ? AppColors.error : AppColors.primary,
    );
  }
}
