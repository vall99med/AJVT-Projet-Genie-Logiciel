import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/post_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';

class EventAttendanceScreen extends ConsumerStatefulWidget {
  final int eventId;
  const EventAttendanceScreen({required this.eventId, super.key});

  @override
  ConsumerState<EventAttendanceScreen> createState() => _EventAttendanceScreenState();
}

class _EventAttendanceScreenState extends ConsumerState<EventAttendanceScreen> {
  List<Map<String, dynamic>>? _participants;
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await ref.read(eventRepositoryProvider).getParticipants(widget.eventId);
    if (mounted) {
      setState(() {
        _participants = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    }
  }

  Future<void> _toggle(int userId, bool newValue) async {
    if (_updating.contains(userId)) return;
    setState(() {
      _updating.add(userId);
      _participants = _participants?.map((p) {
        return p['user_id'] == userId ? {...p, 'attended': newValue} : p;
      }).toList();
    });
    try {
      await ref.read(eventRepositoryProvider).markAttendance(widget.eventId, userId, newValue);
    } catch (e) {
      // Annulation optimiste en cas d'erreur
      setState(() {
        _participants = _participants?.map((p) {
          return p['user_id'] == userId ? {...p, 'attended': !newValue} : p;
        }).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('manage_attendance')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _participants == null
          ? const Center(child: CircularProgressIndicator())
          : _participants!.isEmpty
              ? Center(child: Text(t.translate('no_members'), style: const TextStyle(color: AppColors.textMid)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _participants!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final p        = _participants![i];
                    final userId   = p['user_id']   as int;
                    final fullName = p['full_name']  as String? ?? '—';
                    final phone    = p['phone']      as String? ?? '';
                    final attended = p['attended']   as bool? ?? false;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: attended
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.border,
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: attended ? AppColors.success : AppColors.textMid,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                      trailing: _updating.contains(userId)
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : Switch(
                              value:     attended,
                              onChanged: (v) => _toggle(userId, v),
                              activeThumbColor: AppColors.success,
                              activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                            ),
                    );
                  },
                ),
    );
  }
}
