import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Version': AppConstants.appVersion,
    },
  ));

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    LoggingInterceptor(),
    ErrorInterceptor(),
  ]);

  return dio;
});

/// Injects JWT token into every request and handles 401 auto-refresh.
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  AuthInterceptor(this._ref);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshed = await _refreshToken();
        if (refreshed) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.accessTokenKey);
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await Dio().fetch(err.requestOptions);
          return handler.resolve(response);
        }
      } catch (_) {}

      // Refresh failed — clear session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.accessTokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      await prefs.remove(AppConstants.userIdKey);
    }
    return handler.next(err);
  }

  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${AppConfig.baseUrl}${ApiEndpoints.refreshToken}',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        // Backend wraps in ApiResponse<T> — data lives in response.data.data
        final envelope = response.data as Map<String, dynamic>;
        final data = (envelope['data'] ?? envelope) as Map<String, dynamic>;
        await prefs.setString(
          AppConstants.accessTokenKey,
          data['accessToken'] as String,
        );
        await prefs.setString(
          AppConstants.refreshTokenKey,
          data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// Logs all requests and responses in debug mode.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('→ ${options.method} ${options.path}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('← ${response.statusCode} ${response.requestOptions.path}');
      return true;
    }());
    handler.next(response);
  }
}

/// Maps DioException to user-friendly messages.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = _getErrorMessage(err);
    handler.next(err.copyWith(message: message));
  }

  String _getErrorMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please try again.';
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status == 400) {
          final errors = err.response?.data?['errors'] as Map?;
          if (errors != null) return errors.values.first.toString();
          return err.response?.data?['message'] ?? 'Invalid request.';
        }
        if (status == 403) return 'You do not have permission for this action.';
        if (status == 404) return 'The requested resource was not found.';
        if (status == 409) return 'A conflict occurred. Please check your data.';
        if (status == 422) return err.response?.data?['message'] ?? 'Validation failed.';
        if (status != null && status >= 500) return 'Server error. Please try again later.';
        return 'An unexpected error occurred.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Environment-specific base URL configuration.
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
}
