import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/member_repository.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) => MemberRepository());

// ── Providers de lecture (FutureProvider → cache + invalidation) ──────────────

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(memberRepositoryProvider).getProfile();
});

final cardProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(memberRepositoryProvider).getMemberCard();
});

final statsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(memberRepositoryProvider).getDashboardStats();
});

final activeMembersProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(memberRepositoryProvider).getActiveMembers();
});

final pendingMembersProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(memberRepositoryProvider).getPendingMembers();
});

// ── Notifier pour les mutations (register, updateProfile) ─────────────────────

class MemberNotifier extends StateNotifier<AsyncValue<void>> {
  final MemberRepository _repo;

  MemberNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> register(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repo.register(data);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateProfile(data);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final memberNotifierProvider =
    StateNotifierProvider<MemberNotifier, AsyncValue<void>>((ref) {
  return MemberNotifier(ref.watch(memberRepositoryProvider));
});
