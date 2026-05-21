import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class EventRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(DioException e) {
    try {
      return e.response?.data['message'] as String? ?? 'Une erreur est survenue.';
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  Future<List<dynamic>> getEvents() async {
    try {
      final res = await _dio.get(ApiConstants.events);
      return (res.data['results'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> getEvent(int id) async {
    try {
      final res = await _dio.get(ApiConstants.eventDetail(id));
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required String location,
    required DateTime startsAt,
    required DateTime endsAt,
    int? maxParticipants,
    XFile? image,
  }) async {
    try {
      final startsIso = startsAt.toUtc().toIso8601String();
      final endsIso   = endsAt.toUtc().toIso8601String();
      dynamic data;
      if (image != null) {
        data = FormData.fromMap({
          'title':       title,
          'description': description,
          'location':    location,
          'starts_at':   startsIso,
          'ends_at':     endsIso,
          if (maxParticipants != null) 'max_participants': maxParticipants.toString(),
          'image': await MultipartFile.fromFile(image.path, filename: 'event.jpg'),
        });
      } else {
        data = {
          'title':       title,
          'description': description,
          'location':    location,
          'starts_at':   startsIso,
          'ends_at':     endsIso,
          if (maxParticipants != null) 'max_participants': maxParticipants,
        };
      }
      await _dio.post(ApiConstants.eventsCreate, data: data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> joinEvent(int id) async {
    try {
      await _dio.post(ApiConstants.eventJoin(id), data: <String, dynamic>{});
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> leaveEvent(int id) async {
    try {
      await _dio.delete(ApiConstants.eventLeave(id));
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<List<dynamic>> getParticipants(int id) async {
    try {
      final res = await _dio.get(ApiConstants.eventParticipants(id));
      return (res.data['data'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> markAttendance(int eventId, int userId, bool attended) async {
    try {
      await _dio.patch(
        ApiConstants.eventAttendance(eventId),
        data: {'user_id': userId, 'attended': attended},
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
