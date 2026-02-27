/// Generic wrapper for API responses.
///
/// Most APIs return this shape:
/// {
///   "status": true,
///   "message": "Success",
///   "data": { ... }
/// }
///
/// Usage:
///   final apiResponse = ApiResponse.fromJson(response.data);
///   if (apiResponse.status) {
///     final user = UserModel.fromJson(apiResponse.data);
///   }

class ApiResponse {
  final bool status;
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiResponse({
    required this.status,
    this.statusCode,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      status: json['status'] ?? false,
      statusCode: json['status_code'],
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}
