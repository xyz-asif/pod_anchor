import 'package:dio/dio.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/errors/failures.dart';
import 'package:chatbee/shared/models/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'api_client.g.dart';

/// Centralized API client using Dio.
/// Handles ALL error catching and response parsing.
/// Repos get clean ApiResponse — no try-catch needed there.
///
/// Usage:
///   final response = await apiClient.get('/users');
///   final user = UserModel.fromJson(response.data);
class ApiClient {
  late final Dio _dio;
  SharedPreferences? _prefs;
  static const String _tokenKey = 'auth_token';

  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();

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

    // Logging - remove in production if needed
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    print('🔧 ApiClient instance created');
  }

  // Factory constructor to return singleton
  factory ApiClient() {
    return _instance;
  }

  /// Get the current auth token from headers
  String? get currentToken {
    final authHeader = _dio.options.headers['Authorization'] as String?;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }
    return null;
  }

  /// Initialize: Load saved token from shared preferences and set in headers
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final token = _prefs!.getString(_tokenKey);
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      print('✅ Token loaded from shared preferences and set in headers');
    } else {
      print('ℹ️ No saved token found in shared preferences');
    }
  }

  /// Set auth token after login and save to secure storage
  Future<void> setToken(String token) async {
    _prefs ??= await SharedPreferences.getInstance();
    _dio.options.headers['Authorization'] = 'Bearer $token';
    await _prefs!.setString(_tokenKey, token);
    print('💾 Token saved to storage: ${token.substring(0, 20)}...');
  }

  /// Remove auth token on logout
  Future<void> clearToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    _dio.options.headers.remove('Authorization');
    await _prefs!.remove(_tokenKey);
    print('🗑️ Token cleared from storage and headers');
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
@riverpod
ApiClient apiClient(ApiClientRef ref) {
  return ApiClient();
}
