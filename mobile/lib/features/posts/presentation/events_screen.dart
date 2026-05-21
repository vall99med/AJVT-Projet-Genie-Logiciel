import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/post_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../shared/widgets/main_nav_bar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

String _fmtDate(String? iso, String lang) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    if (lang == 'ar') {
      const months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      return '${dt.day} ${months[dt.month]} ${dt.year} $h:$m';
    }
    const months = ['','Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
    return '${dt.day} ${months[dt.month]} ${dt.year} ${dt.hour}h${dt.minute == 0 ? '' : m}';
  } catch (_) {
    return '';
  }
}

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final role        = ref.watch(authNotifierProvider).role ?? '';
    final canCreate   = role == 'admin' || role == 'moderator';
    final t           = AppLocalizations.of(context);
    final lang        = Localizations.localeOf(context).languageCode;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.translate('events_title')),
          automaticallyImplyLeading: false,
          actions: [
            if (canCreate)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.translate('create_event'),
                onPressed: () => context.push('/event/create'),
              ),
            const LanguageToggle(),
          ],
          bottom: TabBar(
            labelColor:           AppColors.primary,
            unselectedLabelColor: AppColors.textMid,
            indicatorColor:       AppColors.primary,
            tabs: [
              Tab(text: t.translate('tab_upcoming')),
              Tab(text: t.translate('tab_ongoing')),
              Tab(text: t.translate('tab_past')),
            ],
          ),
        ),
        bottomNavigationBar: const MainNavBar(currentIndex: 1),
        body: eventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => _ErrorView(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(eventsProvider),
          ),
          data: (events) => TabBarView(
            children: [
              _EventTab(
                events: events.where((e) => (e as Map)['status'] == 'upcoming').toList(),
                lang: lang, t: t, ref: ref,
              ),
              _EventTab(
                events: events.where((e) => (e as Map)['status'] == 'ongoing').toList(),
                lang: lang, t: t, ref: ref,
              ),
              _EventTab(
                events: events.where((e) {
                  final s = (e as Map)['status'] as String? ?? '';
                  return s == 'past' || s == 'cancelled';
                }).toList(),
                lang: lang, t: t, ref: ref,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTab extends StatelessWidget {
  final List<dynamic> events;
  final String lang;
  final AppLocalizations t;
  final WidgetRef ref;

  const _EventTab({required this.events, required this.lang, required this.t, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 56, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text(t.translate('no_events'), style: const TextStyle(color: AppColors.textMid)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(eventsProvider),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _EventCard(
          event: events[i] as Map<String, dynamic>,
          lang: lang, t: t, ref: ref,
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String lang;
  final AppLocalizations t;
  final WidgetRef ref;

  const _EventCard({required this.event, required this.lang, required this.t, required this.ref});

  @override
  Widget build(BuildContext context) {
    final eventId         = event['id']                 as int;
    final title           = event['title']              as String? ?? '';
    final location        = event['location']           as String?;
    final imageUrl        = event['image_url']          as String?;
    final startsAt        = event['starts_at']          as String?;
    final maxP            = event['max_participants']   as int?;
    final count           = event['participants_count'] as int? ?? 0;
    final isParticipating = event['is_participating']   as bool? ?? false;
    final status          = event['status']             as String? ?? '';
    final isFull          = maxP != null && count >= maxP;
    final isPast          = status == 'past' || status == 'cancelled';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.push('/event/$eventId'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl:    imageUrl,
                height:      160,
                width:       double.infinity,
                fit:         BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  if (startsAt != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(_fmtDate(startsAt, lang), style: const TextStyle(fontSize: 12, color: AppColors.textMid)),
                    ]),
                  ],
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(child: Text(location, style: const TextStyle(fontSize: 12, color: AppColors.textMid), overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        maxP != null
                            ? '$count / $maxP ${t.translate('participants_label')}'
                            : '$count ${t.translate('participants_label')}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                      ),
                      if (isFull) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t.translate('event_full'), style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const Spacer(),
                      if (!isPast)
                        _JoinButton(eventId: eventId, isParticipating: isParticipating, isFull: isFull, t: t, ref: ref),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final int eventId;
  final bool isParticipating;
  final bool isFull;
  final AppLocalizations t;
  final WidgetRef ref;

  const _JoinButton({
    required this.eventId,
    required this.isParticipating,
    required this.isFull,
    required this.t,
    required this.ref,
  });

  Future<void> _toggle(BuildContext context) async {
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
      if (confirmed != true) return;
      await ref.read(eventNotifierProvider.notifier).leaveEvent(eventId);
    } else {
      await ref.read(eventNotifierProvider.notifier).joinEvent(eventId);
    }
    ref.invalidate(eventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(eventNotifierProvider).isLoading;
    if (isLoading) return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));

    return ElevatedButton(
      onPressed: (isFull && !isParticipating) ? null : () => _toggle(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: isParticipating ? AppColors.success : AppColors.primary,
        foregroundColor: Colors.white,
        padding:         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize:     const Size(0, 32),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        isParticipating ? t.translate('joined') : t.translate('join_event'),
        style: const TextStyle(fontSize: 12),
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
    );
  }
}
