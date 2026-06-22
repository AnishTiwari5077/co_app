import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/api/api_client.dart';
import '../../../../shared/models/entities.dart';

// ─── Auth State ───────────────────────────────────────────────────────────────
class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserEntity? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  AuthState loading() => AuthState(user: user, isLoading: true);
  AuthState withError(String e) => AuthState(user: user, error: e);
  AuthState authenticated(UserEntity u) => AuthState(user: u);
  AuthState unauthenticated() => const AuthState();
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  AuthNotifier(this._dio) : super(const AuthState()) {
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    state = state.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.accessTokenKey);
      final userId = prefs.getString(AppConstants.userIdKey);
      if (token != null && userId != null) {
        state = state.authenticated(UserEntity(
          id: userId,
          username: prefs.getString('user_username') ?? '',
          fullName: prefs.getString('user_full_name') ?? '',
          email: prefs.getString('user_email') ?? '',
          branchId: prefs.getString(AppConstants.branchIdKey) ?? '',
          branchCode: prefs.getString('user_branch_code') ?? 'HO',
          branchName: prefs.getString('user_branch_name') ?? 'Head Office',
          roles: prefs.getStringList('user_roles') ?? [],
          permissions: prefs.getStringList('user_permissions') ?? [],
          isHeadOffice: prefs.getBool('user_is_head_office') ?? true,
        ));
        return;
      }
    } catch (_) {}
    state = const AuthState();
  }

  Future<bool> login(String username, String password) async {
    state = state.loading();
    try {
      final resp = await _dio.post(
        ApiEndpoints.login,
        data: {
          'username': username,
          'password': password,
          'deviceId': 'desktop',
        },
      );

      // Backend returns ApiResponse<T> — data lives in resp.data['data']
      final envelope = resp.data as Map<String, dynamic>;
      final data = envelope['data'] as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final user = UserEntity.fromJson(userJson);

      // Persist session to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.accessTokenKey, accessToken);
      await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
      await prefs.setString(AppConstants.userIdKey, user.id);
      await prefs.setString(AppConstants.branchIdKey, user.branchId);
      await prefs.setString('user_full_name', user.fullName);
      await prefs.setString('user_username', user.username);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_branch_code', user.branchCode);
      await prefs.setString('user_branch_name', user.branchName);
      await prefs.setStringList('user_roles', user.roles);
      await prefs.setStringList('user_permissions', user.permissions);
      await prefs.setBool('user_is_head_office', user.isHeadOffice);

      state = state.authenticated(user);
      return true;
    } on DioException catch (e) {
      final envelope = e.response?.data as Map<String, dynamic>?;
      final msg = envelope?['error']?['message'] as String?
          ?? e.message
          ?? 'Login failed. Please try again.';
      state = state.withError(msg);
      return false;
    } catch (e) {
      state = state.withError('Unexpected error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = state.unauthenticated();
  }

  void setUser(UserEntity user) => state = state.authenticated(user);
  void clearError() => state = AuthState(user: state.user);
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(dioProvider));
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authStateProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  return user?.hasPermission(permission) ?? false;
});
