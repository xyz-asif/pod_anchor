import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/errors/failures.dart';
import 'package:chatbee/shared/models/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

part 'api_client.g.dart';

/// Centralized API client using Dio.
/// Handles ALL error catching and response parsing.
/// Repos get clean ApiResponse — no try-catch needed there.
///
/// Usage:
///   final response = await apiClient.get('/users');
///   final user = UserModel.fromJson(response.data);
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  static const String _tokenKey = 'auth_token';

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auto-refresh interceptor: catches 401, refreshes Firebase token, retries
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final newToken = await user.getIdToken(true);
                if (newToken != null) {
                  // Update stored token
                  await setToken(newToken);

                  // Retry the failed request with the fresh token
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  final response = await _dio.fetch(opts);
                  return handler.resolve(response);
                }
              }
            } catch (refreshError) {
              // Token refresh failed — user's Firebase session is gone
              // Let the original 401 propagate so the UI can handle it
              log('[API] Token auto-refresh failed: $refreshError', name: 'API_CLIENT');
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Logging - remove in production if needed
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    log('ApiClient instance created', name: 'API_CLIENT');
  }

  /// Get the current auth token from headers
  String? get currentToken {
    final authHeader = _dio.options.headers['Authorization'] as String?;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    return null;
  }

  /// Initialize: Load saved token from SharedPreferences and set in headers
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      log('Token loaded from SharedPreferences and set in headers', name: 'API_CLIENT');
    } else {
      log('No saved token found in SharedPreferences', name: 'API_CLIENT');
    }
  }

  /// Set auth token after login and persist to SharedPreferences
  Future<void> setToken(String token) async {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    log('Token saved to SharedPreferences', name: 'API_CLIENT');
  }

  /// Remove auth token on logout
  Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    log('Token cleared from SharedPreferences and headers', name: 'API_CLIENT');
  }

  /// Check if token is currently set in headers
  bool get hasToken {
    return _dio.options.headers.containsKey('Authorization') &&
        _dio.options.headers['Authorization'] != null;
  }

  /// GET request
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _request(() => _dio.get(path, queryParameters: queryParameters));
  }

  /// POST request
  Future<ApiResponse> post(String path, {dynamic data}) async {
    return _request(() => _dio.post(path, data: data));
  }

  /// PATCH request
  Future<ApiResponse> patch(String path, {dynamic data}) async {
    return _request(() => _dio.patch(path, data: data));
  }

  /// PUT request
  Future<ApiResponse> put(String path, {dynamic data}) async {
    return _request(() => _dio.put(path, data: data));
  }

  /// DELETE request
  Future<ApiResponse> delete(String path, {dynamic data}) async {
    return _request(() => _dio.delete(path, data: data));
  }

  /// Central error handler. Every method above goes through this.
  /// Catches Dio errors, parses response, throws Failure on error.
  Future<ApiResponse> _request(Future<Response> Function() request) async {
    try {
      final response = await request();
      final apiResponse = ApiResponse.fromJson(response.data);

      if (!apiResponse.success) {
        throw ServerFailure(apiResponse.message);
      }

      return apiResponse;
    } on DioException catch (e) {
      throw ServerFailure(
        e.response?.data?['message'] ?? 'Server error occurred',
      );
    } on Failure {
      rethrow;
    } catch (e) {
      throw ServerFailure('Unexpected error: $e');
    }
  }
}

/// Riverpod provider for ApiClient.
@Riverpod(keepAlive: true)
ApiClient apiClient(ApiClientRef ref) {
  return ApiClient();
}
