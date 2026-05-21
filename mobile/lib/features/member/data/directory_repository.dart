import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class DirectoryRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(DioException e) {
    try {
      return e.response?.data['message'] as String? ?? 'Une erreur est survenue.';
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  // Recherche paginée : GET /members/?search=…&situation=…&page=N
  Future<Map<String, dynamic>> searchMembers({
    String query = '',
    String? situation,
    int page = 1,
  }) async {
    try {
      final res = await _dio.get(
        ApiConstants.membersSearch(query, situation, page),
      );
      // Réponse DRF paginée : {count, next, previous, results: [...]}
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // Détail d'un membre : GET /members/{userId}/
  Future<Map<String, dynamic>> getMemberDetail(int userId) async {
    try {
      final res = await _dio.get(ApiConstants.memberDetail(userId));
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
