import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/errors/failures.dart';
import 'package:chatbee/shared/models/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/utils/hive_storage.dart';

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

    // Auto-refresh interceptor: on 401, uses stored refresh token to get a new
    // JWT access token from the backend (no Firebase network call needed).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              final refreshToken = HiveStorage.getRefreshToken();
              if (refreshToken != null) {
                final response = await _dio.post(
                  ApiEndpoints.authRefresh,
                  data: {'refreshToken': refreshToken},
                );
                final data = response.data['data'] as Map<String, dynamic>;
                final newAccess = data['accessToken'] as String;
                final newRefresh = data['refreshToken'] as String;
                await setToken(newAccess);
                await HiveStorage.setRefreshToken(newRefresh);

                // Retry the original request with the new access token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccess';
                final retryResponse = await _dio.fetch(opts);
                return handler.resolve(retryResponse);
              }
            } catch (refreshError) {
              // Refresh token expired or revoked — let 401 propagate so UI logs out
              log('[API] Token refresh failed: $refreshError', name: 'API_CLIENT');
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

  /// Initialize: Load saved token from Hive and set in headers
  Future<void> initialize() async {
    final token = HiveStorage.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      log('Token loaded from Hive and set in headers', name: 'API_CLIENT');
    } else {
      log('No saved token found in Hive', name: 'API_CLIENT');
    }
  }

  /// Set auth token after login and persist to Hive
  Future<void> setToken(String token) async {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    await HiveStorage.setToken(token);
    log('Token saved to Hive', name: 'API_CLIENT');
  }

  /// Remove auth token on logout
  Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    await HiveStorage.clearToken();
    log('Token cleared from Hive and headers', name: 'API_CLIENT');
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
