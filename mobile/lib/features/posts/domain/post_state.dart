import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/post_repository.dart';
import '../data/event_repository.dart';

final postRepositoryProvider  = Provider<PostRepository>((ref)  => PostRepository());
final eventRepositoryProvider = Provider<EventRepository>((ref) => EventRepository());

// ── Providers de lecture ──────────────────────────────────────────────────────

final postsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(postRepositoryProvider).getPosts();
});

final postDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
  return ref.watch(postRepositoryProvider).getPost(id);
});

final eventsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(eventRepositoryProvider).getEvents();
});

final eventDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
  return ref.watch(eventRepositoryProvider).getEvent(id);
});

final eventParticipantsProvider = FutureProvider.family<List<dynamic>, int>((ref, id) {
  return ref.watch(eventRepositoryProvider).getParticipants(id);
});

// ── Notifier articles ─────────────────────────────────────────────────────────

class PostNotifier extends StateNotifier<AsyncValue<void>> {
  PostNotifier(this._repo) : super(const AsyncValue.data(null));
  final PostRepository _repo;

  Future<bool> createPost({
    required String title,
    required String body,
    XFile? image,
    bool publishAfterCreate = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final post = await _repo.createPost(title: title, body: body, image: image);
      if (publishAfterCreate) {
        await _repo.publishPost(post['id'] as int);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> publishPost(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.publishPost(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final postNotifierProvider = StateNotifierProvider<PostNotifier, AsyncValue<void>>((ref) {
  return PostNotifier(ref.watch(postRepositoryProvider));
});

// ── Notifier événements ───────────────────────────────────────────────────────

class EventNotifier extends StateNotifier<AsyncValue<void>> {
  EventNotifier(this._repo) : super(const AsyncValue.data(null));
  final EventRepository _repo;

  Future<bool> joinEvent(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.joinEvent(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> leaveEvent(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.leaveEvent(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> createEvent({
    required String title,
    required String description,
    required String location,
    required DateTime startsAt,
    required DateTime endsAt,
    int? maxParticipants,
    XFile? image,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createEvent(
        title:           title,
        description:     description,
        location:        location,
        startsAt:        startsAt,
        endsAt:          endsAt,
        maxParticipants: maxParticipants,
        image:           image,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final eventNotifierProvider = StateNotifierProvider<EventNotifier, AsyncValue<void>>((ref) {
  return EventNotifier(ref.watch(eventRepositoryProvider));
});
