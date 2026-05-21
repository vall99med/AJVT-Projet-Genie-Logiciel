import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class MemberRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(DioException e) {
    try {
      return e.response?.data['message'] as String? ?? 'Une erreur est survenue.';
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  Future<void> register(Map<String, dynamic> data) async {
    try {
      await _dio.post(ApiConstants.register, data: data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final res = await _dio.get(ApiConstants.me);
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch(ApiConstants.me, data: data);
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> getMemberCard() async {
    try {
      final res = await _dio.get(ApiConstants.card);
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final res = await _dio.get(ApiConstants.stats);
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<List<dynamic>> getActiveMembers() async {
    try {
      final res = await _dio.get(ApiConstants.membersList);
      return (res.data['results'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<List<dynamic>> getPendingMembers() async {
    try {
      final res = await _dio.get(ApiConstants.pending);
      return (res.data['results'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> validateMember(int id, bool approved, {String? rejectionReason}) async {
    try {
      final data = <String, dynamic>{
        'action': approved ? 'approve' : 'reject',
      };
      if (!approved && rejectionReason != null && rejectionReason.isNotEmpty) {
        data['rejection_reason'] = rejectionReason;
      }
      await _dio.patch(ApiConstants.validate(id), data: data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<List<int>> exportExcel() async {
    try {
      final res = await _dio.get<List<int>>(
        ApiConstants.export,
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
