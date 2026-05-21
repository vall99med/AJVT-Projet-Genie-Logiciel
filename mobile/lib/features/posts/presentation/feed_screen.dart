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

String _relativeDate(String? iso, String lang) {
  if (iso == null) return '';
  try {
    final dt   = DateTime.parse(iso);
    final diff = DateTime.now().difference(dt);
    if (lang == 'ar') {
      if (diff.inDays >= 365) return 'منذ ${diff.inDays ~/ 365} سنة';
      if (diff.inDays >= 30)  return 'منذ ${diff.inDays ~/ 30} شهر';
      if (diff.inDays >= 1)   return 'منذ ${diff.inDays} يوم';
      if (diff.inHours >= 1)  return 'منذ ${diff.inHours} ساعة';
      return 'منذ ${diff.inMinutes} دقيقة';
    }
    if (diff.inDays >= 365) return 'il y a ${diff.inDays ~/ 365} an(s)';
    if (diff.inDays >= 30)  return 'il y a ${diff.inDays ~/ 30} mois';
    if (diff.inDays >= 1)   return 'il y a ${diff.inDays} jour(s)';
    if (diff.inHours >= 1)  return 'il y a ${diff.inHours} heure(s)';
    return 'il y a ${diff.inMinutes} min';
  } catch (_) {
    return '';
  }
}

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final role       = ref.watch(authNotifierProvider).role ?? '';
    final canCreate  = role == 'admin' || role == 'moderator';
    final t          = AppLocalizations.of(context);
    final lang       = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/AJVT-logo.jpeg', height: 40),
        automaticallyImplyLeading: false,
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: t.translate('create_post'),
              onPressed: () => context.push('/post/create'),
            ),
          const LanguageToggle(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.translate('logout'),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/phone');
            },
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 0),
      body: postsAsync.when(
        loading: () => const _SkeletonFeed(),
        error: (e, _) => _ErrorView(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(postsProvider),
        ),
        data: (posts) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(postsProvider),
          child: posts.isEmpty
              ? _EmptyFeed(t: t)
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PostCard(
                    post:       posts[i] as Map<String, dynamic>,
                    canCreate:  canCreate,
                    lang:       lang,
                    t:          t,
                    onPublish: () async {
                      final ok = await ref.read(postNotifierProvider.notifier)
                          .publishPost(posts[i]['id'] as int);
                      if (ok && context.mounted) {
                        ref.invalidate(postsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(t.translate('publish_success')),
                          backgroundColor: AppColors.success,
                        ));
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool canCreate;
  final String lang;
  final AppLocalizations t;
  final VoidCallback onPublish;

  const _PostCard({
    required this.post,
    required this.canCreate,
    required this.lang,
    required this.t,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft    = post['status'] == 'draft';
    final imageUrl   = post['image_url']   as String?;
    final title      = post['title']       as String? ?? '';
    final body       = post['body']        as String? ?? '';
    final authorName = post['author_name'] as String? ?? '';
    final dateStr    = _relativeDate(post['published_at'] as String?, lang);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.push('/post/${post['id']}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl:   imageUrl,
                height:     200,
                width:      double.infinity,
                fit:        BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canCreate && isDraft)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.translate('draft_badge'),
                            style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onPublish,
                          icon: const Icon(Icons.publish, size: 16),
                          label: Text(t.translate('publish'), style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          authorName,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                      ),
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

class _EmptyFeed extends StatelessWidget {
  final AppLocalizations t;
  const _EmptyFeed({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.feed_outlined, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              t.translate('no_posts'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMid, fontSize: 15),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
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
      ),
    );
  }
}

class _SkeletonFeed extends StatelessWidget {
  const _SkeletonFeed();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const _SkeletonPostCard(),
    );
  }
}

class _SkeletonPostCard extends StatelessWidget {
  const _SkeletonPostCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 220,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 11,
                  width: 260,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 10,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
