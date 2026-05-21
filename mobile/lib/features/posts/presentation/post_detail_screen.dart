import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/post_state.dart';
import '../../auth/domain/auth_state.dart';
import '../../../core/constants/app_colors.dart';

String _formatDate(String? iso, String lang) {
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
    return '${dt.day} ${months[dt.month]} ${dt.year} à ${dt.hour}h${dt.minute == 0 ? '' : m}';
  } catch (_) {
    return '';
  }
}

class PostDetailScreen extends ConsumerWidget {
  final int id;
  const PostDetailScreen({required this.id, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(id));
    final lang      = Localizations.localeOf(context).languageCode;

    return postAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (post) {
        final imageUrl   = post['image_url']   as String?;
        final title      = post['title']       as String? ?? '';
        final body       = post['body']        as String? ?? '';
        final authorName = post['author_name'] as String? ?? '';
        final dateStr    = _formatDate(post['published_at'] as String?, lang);
        final hasImage   = imageUrl != null;

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
                          imageUrl:   imageUrl,
                          fit:        BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surface),
                        ),
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      await ref.read(authNotifierProvider.notifier).logout();
                      router.go('/phone');
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                if (dateStr.isNotEmpty)
                                  Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textMid,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
