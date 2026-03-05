/// Generic wrapper for ALL API responses.
///
/// The backend returns this shape:
/// {
///   "success": true,
///   "statusCode": 200,
///   "message": "Operation successful",
///   "data": { ... }
/// }
///
/// Usage:
///   final apiResponse = ApiResponse.fromJson(response.data);
///   if (apiResponse.success) {
///     final user = UserModel.fromJson(apiResponse.data);
///   }
class ApiResponse {
  final bool success;
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiResponse({
    required this.success,
    this.statusCode,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      statusCode: json['statusCode'],
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}
