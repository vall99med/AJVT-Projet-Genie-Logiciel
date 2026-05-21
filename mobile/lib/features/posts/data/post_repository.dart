import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class PostRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(DioException e) {
    try {
      return e.response?.data['message'] as String? ?? 'Une erreur est survenue.';
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  Future<List<dynamic>> getPosts() async {
    try {
      final res = await _dio.get(ApiConstants.posts);
      return (res.data['results'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> getPost(int id) async {
    try {
      final res = await _dio.get(ApiConstants.postDetail(id));
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String title,
    required String body,
    XFile? image,
  }) async {
    try {
      dynamic data;
      if (image != null) {
        data = FormData.fromMap({
          'title': title,
          'body':  body,
          'image': await MultipartFile.fromFile(image.path, filename: 'post.jpg'),
        });
      } else {
        data = {'title': title, 'body': body};
      }
      final res = await _dio.post(ApiConstants.postsCreate, data: data);
      return res.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> publishPost(int id) async {
    try {
      await _dio.patch(ApiConstants.postPublish(id), data: <String, dynamic>{});
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
