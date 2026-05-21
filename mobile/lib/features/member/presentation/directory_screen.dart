import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/directory_repository.dart';
import '../../../shared/widgets/main_nav_bar.dart';
import '../../../shared/widgets/language_toggle.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final _repo       = DirectoryRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  String  _query      = '';
  String? _situation;
  int     _page       = 1;
  int     _total      = 0;
  bool    _isLoading  = true;
  bool    _loadingMore = false;
  bool    _hasMore    = true;
  String? _error;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetch({bool reset = true}) async {
    if (reset) {
      setState(() { _isLoading = true; _error = null; _page = 1; _members = []; _hasMore = true; });
    }
    try {
      final result = await _repo.searchMembers(
        query: _query,
        situation: _situation,
        page: reset ? 1 : _page,
      );
      final items = (result['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _members    = reset ? items : [..._members, ...items];
        _total      = result['count'] as int? ?? 0;
        _hasMore    = result['next'] != null;
        _isLoading  = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error      = e.toString().replaceFirst('Exception: ', '');
        _isLoading  = false;
        _loadingMore = false;
      });
    }
  }

  void _loadMore() {
    setState(() { _loadingMore = true; _page++; });
    _fetch(reset: false);
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _query = v.trim();
      _fetch();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _query = '';
    _fetch();
  }

  void _setSituation(String? s) {
    setState(() => _situation = s);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('directory_title')),
        automaticallyImplyLeading: false,
        actions: const [LanguageToggle()],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 2),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            hint: t.translate('search_hint_directory'),
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
          ),
          _FilterRow(selected: _situation, onSelect: _setSituation, t: t),
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_total ${t.translate('members_count')}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                ),
              ),
            ),
          Expanded(child: _buildBody(t)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_isLoading) return const _SkeletonList();
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _fetch);
    }
    if (_members.isEmpty) {
      return Center(
        child: Text(t.translate('no_results'),
            style: const TextStyle(color: AppColors.textMid, fontSize: 15)),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _members.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _members.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _MemberCard(
            member: _members[i],
            t: t,
            onTap: () => context.push('/member/${_members[i]['id']}'),
          );
        },
      ),
    );
  }
}

// ── Barre de recherche ─────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textLight),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

// ── Chips de filtre ────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  final AppLocalizations t;

  const _FilterRow({required this.selected, required this.onSelect, required this.t});

  @override
  Widget build(BuildContext context) {
    final filters = <String?, String>{
      null:         t.translate('filter_all'),
      'student':    t.translate('filter_student'),
      'employed':   t.translate('filter_employed'),
      'unemployed': t.translate('filter_unemployed'),
    };

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filters.entries.map((e) {
          final active = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? Colors.white : AppColors.textDark,
                  )),
              selected: active,
              onSelected: (_) => onSelect(e.key),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: active ? AppColors.primary : AppColors.border,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Carte membre ──────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final AppLocalizations t;
  final VoidCallback onTap;

  const _MemberCard({required this.member, required this.t, required this.onTap});

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF1A56DB), const Color(0xFF0D9488), const Color(0xFF7C3AED),
      const Color(0xFFDB2777), const Color(0xFFD97706), const Color(0xFF059669),
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  Color _situationColor(String sit) => switch (sit) {
    'student'    => const Color(0xFF1A56DB),
    'employed'   => const Color(0xFF059669),
    'unemployed' => AppColors.textMid,
    _            => AppColors.textLight,
  };

  String _situationLabel(String sit) => switch (sit) {
    'student'    => t.translate('filter_student'),
    'employed'   => t.translate('filter_employed'),
    'unemployed' => t.translate('filter_unemployed'),
    _            => sit,
  };

  Future<void> _openWhatsApp(String phone) async {
    final number = phone.replaceAll('+', '').replaceAll(' ', '');
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name      = member['full_name']   as String? ?? '?';
    final situation = member['situation']   as String? ?? '';
    final specialty = member['specialty']   as String? ?? '';
    final jobTitle  = member['job_title']   as String? ?? '';
    final region    = member['neighborhood'] as String? ?? '';
    final phone     = member['phone']       as String? ?? '';
    final photoUrl  = member['photo']       as String?;
    final subtitle  = situation == 'student' ? specialty : jobTitle;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarColor(name),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _situationColor(situation).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _situationLabel(situation),
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _situationColor(situation),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMid),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (region.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textLight),
                          const SizedBox(width: 2),
                          Text(
                            region,
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Bouton WhatsApp
              if (phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                  tooltip: t.translate('contact_whatsapp'),
                  onPressed: () => _openWhatsApp(phone),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton de chargement ────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: 5,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 13, width: 140, decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(height: 11, width: 100, decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(height: 10, width: 80, decoration: BoxDecoration(
                    color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vue d'erreur ──────────────────────────────────────────────────────────────

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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMid)),
            const SizedBox(height: 16),
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
