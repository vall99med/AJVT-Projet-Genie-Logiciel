import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';

enum AuthStatus { initial, loading, otpSent, otpVerified, pinSet, pinReset, authenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? role;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.role,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? role,
  }) =>
      AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        role: role ?? this.role,
      );
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _checkStoredAuth();
  }

  // Vérifie au démarrage si un token valide est présent
  Future<void> _checkStoredAuth() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) return;
    final role = await SecureStorage.getRole();
    state = AuthState(status: AuthStatus.authenticated, role: role);
  }

  String _cleanError(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.requestOtp(phone);
      state = state.copyWith(status: AuthStatus.otpSent);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _cleanError(e));
    }
  }

  Future<void> verifyOtp(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.verifyOtp(phone, code);
      state = state.copyWith(status: AuthStatus.otpVerified);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _cleanError(e));
    }
  }

  Future<void> setPin(String phone, String pin) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.setPin(phone, pin);
      state = state.copyWith(status: AuthStatus.pinSet);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _cleanError(e));
    }
  }

  Future<void> login(String phone, String pin) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final role = await _repo.login(phone, pin);
      state = AuthState(status: AuthStatus.authenticated, role: role);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _cleanError(e));
    }
  }

  Future<void> sendResetOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.requestResetPin(phone);
      state = state.copyWith(status: AuthStatus.otpSent);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _cleanError(e));
    }
  }

  // Le code OTP est transmis directement à reset-pin/confirm/ côté serveur
  Future<void> resetPin(String phone, String code, String pin) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.confirmResetPin(phone, code, pin);
      state = state.copyWith(status: AuthStatus.pinReset);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _cleanError(e));
    }
  }

  Future<void> logout() async {
    await SecureStorage.clearAll();
    state = const AuthState();
  }

  void reset() {
    state = const AuthState();
  }
}
