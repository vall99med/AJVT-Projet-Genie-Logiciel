import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(DioException e) {
    try {
      return e.response?.data['message'] as String? ?? 'Une erreur est survenue.';
    } catch (_) {
      return 'Une erreur est survenue.';
    }
  }

  // POST /auth/request-otp/
  Future<void> requestOtp(String phone) async {
    try {
      await _dio.post(ApiConstants.requestOtp, data: {'phone': phone});
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // POST /auth/verify-otp/ (flux inscription uniquement)
  Future<void> verifyOtp(String phone, String code) async {
    try {
      await _dio.post(ApiConstants.verifyOtp, data: {'phone': phone, 'code': code});
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // POST /auth/set-pin/ → sauvegarde les tokens JWT
  Future<void> setPin(String phone, String pin) async {
    try {
      final res = await _dio.post(
        ApiConstants.setPin,
        data: {'phone': phone, 'pin': pin, 'pin_confirm': pin},
      );
      final tokens = res.data['data']['tokens'] as Map<String, dynamic>;
      await SecureStorage.saveTokens(
        tokens['access'] as String,
        tokens['refresh'] as String,
      );
      await SecureStorage.savePhone(phone);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // POST /auth/login/ → sauvegarde tokens + retourne le rôle
  Future<String> login(String phone, String pin) async {
    try {
      final res = await _dio.post(
        ApiConstants.login,
        data: {'phone': phone, 'pin': pin},
      );
      final tokens = res.data['data']['tokens'] as Map<String, dynamic>;
      await SecureStorage.saveTokens(
        tokens['access'] as String,
        tokens['refresh'] as String,
      );
      await SecureStorage.savePhone(phone);
      final role = await _fetchRole();
      await SecureStorage.saveRole(role);
      return role;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // Récupère le rôle via /members/me/ après login
  Future<String> _fetchRole() async {
    try {
      final res = await _dio.get(ApiConstants.me);
      final data = res.data['data'] as Map<String, dynamic>?;
      return data?['role'] as String? ?? 'member';
    } catch (_) {
      // Utilisateur en attente ou non-membre
      return 'visitor';
    }
  }

  // POST /auth/reset-pin/request/
  Future<void> requestResetPin(String phone) async {
    try {
      await _dio.post(ApiConstants.resetPin, data: {'phone': phone});
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // POST /auth/reset-pin/confirm/ (code + nouveau PIN validés ensemble côté serveur)
  Future<void> confirmResetPin(String phone, String code, String pin) async {
    try {
      await _dio.post(
        ApiConstants.resetPinConfirm,
        data: {'phone': phone, 'code': code, 'pin': pin, 'pin_confirm': pin},
      );
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }
}
