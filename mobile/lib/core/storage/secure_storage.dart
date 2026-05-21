import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage    = FlutterSecureStorage();
  static const _accessKey  = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _phoneKey   = 'user_phone';
  static const _roleKey    = 'user_role';

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey,  value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  static Future<String?> getAccessToken()  async =>
      _storage.read(key: _accessKey);

  static Future<String?> getRefreshToken() async =>
      _storage.read(key: _refreshKey);

  static Future<void> savePhone(String phone) async =>
      _storage.write(key: _phoneKey, value: phone);

  static Future<String?> getPhone() async =>
      _storage.read(key: _phoneKey);

  static Future<void> saveRole(String role) async =>
      _storage.write(key: _roleKey, value: role);

  static Future<String?> getRole() async =>
      _storage.read(key: _roleKey);

  static Future<void> clearAll() async => _storage.deleteAll();
}
