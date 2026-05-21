import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/directory_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class MemberProfileScreen extends StatefulWidget {
  final int userId;
  const MemberProfileScreen({required this.userId, super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _repo = DirectoryRepository();
  Map<String, dynamic>? _member;
  bool    _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _repo.getMemberDetail(widget.userId);
      setState(() { _member = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final number = phone.replaceAll('+', '').replaceAll(' ', '');
    final uri    = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_member?['full_name'] as String? ?? t.translate('member_profile_title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _fetch)
              : _buildContent(context, t),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations t) {
    final member     = _member!;
    final name       = member['full_name']    as String? ?? '—';
    final situation  = member['situation']    as String? ?? '';
    final specialty  = member['specialty']    as String? ?? '';
    final jobTitle   = member['job_title']    as String? ?? '';
    final region     = member['neighborhood'] as String? ?? '';
    final phone      = member['phone']        as String? ?? '';
    final photoUrl   = member['photo']        as String?;
    final role       = member['role']         as String? ?? 'member';
    final cotStatus  = member['cotisation_status'] as String? ?? 'pending';
    final since      = member['member_since'] as int?;

    final subtitleText = situation == 'student' ? specialty : jobTitle;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Avatar ────────────────────────────────────────────
          Center(
            child: CircleAvatar(
              radius: 56,
              backgroundColor: _avatarColor(name),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),

          // ── Nom + badge rôle ──────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(name,
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark,
                    )),
                const SizedBox(height: 6),
                _RoleBadge(role: role),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Infos ─────────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.work_outline,
                    label: t.translate('situation'),
                    value: _situationLabel(situation, t),
                  ),
                  if (subtitleText.isNotEmpty)
                    _InfoTile(
                      icon: situation == 'student'
                          ? Icons.school_outlined
                          : Icons.business_center_outlined,
                      label: situation == 'student'
                          ? t.translate('specialty')
                          : t.translate('job_title'),
                      value: subtitleText,
                    ),
                  if (region.isNotEmpty)
                    _InfoTile(
                      icon: Icons.location_on_outlined,
                      label: t.translate('neighborhood'),
                      value: region,
                    ),
                  if (since != null)
                    _InfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: t.translate('member_since'),
                      value: since.toString(),
                    ),
                  _InfoTile(
                    icon: cotStatus == 'paid'
                        ? Icons.check_circle_outline
                        : Icons.access_time_outlined,
                    label: t.translate('cotisation_status'),
                    value: _cotisationLabel(cotStatus, t),
                    valueColor: _cotisationColor(cotStatus),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Bouton WhatsApp ───────────────────────────────────
          if (phone.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_outlined),
              label: Text(t.translate('contact_whatsapp')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openWhatsApp(phone),
            ),
        ],
      ),
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF1A56DB), Color(0xFF0D9488), Color(0xFF7C3AED),
      Color(0xFFDB2777), Color(0xFFD97706), Color(0xFF059669),
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  String _situationLabel(String s, AppLocalizations t) => switch (s) {
    'student'    => t.translate('student'),
    'employed'   => t.translate('employed'),
    'unemployed' => t.translate('unemployed'),
    _            => s,
  };

  String _cotisationLabel(String s, AppLocalizations t) => switch (s) {
    'paid'      => t.translate('card_status_paid'),
    'submitted' => t.translate('status_submitted'),
    'rejected'  => t.translate('status_rejected'),
    _           => t.translate('card_status_pending'),
  };

  Color _cotisationColor(String s) => switch (s) {
    'paid'      => AppColors.success,
    'submitted' => AppColors.primary,
    'rejected'  => AppColors.error,
    _           => AppColors.warning,
  };
}

// ── Badge rôle ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'admin'     => ('Admin',     AppColors.error),
      'moderator' => ('Modérateur', AppColors.warning),
      _           => ('Membre',    AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Ligne d'info ──────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textDark,
              )),
        ],
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
