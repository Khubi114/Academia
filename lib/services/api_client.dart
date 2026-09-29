// lib/services/api_client.dart
//
// The one place that talks to the Vercel backend. It
//   * makes sure a Supabase session exists,
//   * attaches the session's JWT as `Authorization: Bearer …` (the backend
//     derives the user from the token — the app never sends a user id),
//   * converts failures into a typed [ApiException].

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

class ApiException implements Exception {
  final int? status;
  final String message;
  final Object? detail;

  const ApiException(this.message, {this.status, this.detail});

  /// True when the backend says the third-party connection is missing/expired.
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  ApiClient._() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _accessToken();
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          } catch (e) {
            handler.reject(
              DioException(requestOptions: options, error: e),
            );
          }
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.vercelBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      // Canvas syncs walk every course, so allow the server time to finish.
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// Returns a valid access token, creating an anonymous session if needed.
  Future<String> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) await auth.signInAnonymously();
    final token = auth.currentSession?.accessToken;
    if (token == null) throw const ApiException('No Supabase session');
    return token;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send(() => _dio.post<dynamic>(path, data: body ?? const {}));

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : (e.error is ApiException
              ? (e.error as ApiException).message
              : e.message ?? 'Network error');
      throw ApiException(
        message,
        status: e.response?.statusCode,
        detail: data is Map ? data['detail'] : null,
      );
    }
  }
}
