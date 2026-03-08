import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/cloudinary_config.dart';

part 'cloudinary_service.g.dart';

/// Result from a successful Cloudinary upload.
class CloudinaryUploadResult {
  final String secureUrl;
  final String? resourceType; // image, video, raw
  final String? format; // jpg, mp4, pdf, etc.
  final int? bytes;
  final int? width;
  final int? height;
  final double? duration; // seconds (for video/audio)
  final String? originalFilename;

  const CloudinaryUploadResult({
    required this.secureUrl,
    this.resourceType,
    this.format,
    this.bytes,
    this.width,
    this.height,
    this.duration,
    this.originalFilename,
  });
}

/// Handles direct uploads to Cloudinary using unsigned upload preset.
///
/// Uses plain Dio multipart upload — no Cloudinary SDK dependency.
/// The Flutter client never sees the API secret; the unsigned preset
/// controls what's allowed.
class CloudinaryService {
  final Dio _dio;

  CloudinaryService({Dio? dio}) : _dio = dio ?? Dio();

  /// Upload a file to Cloudinary.
  ///
  /// Returns a [CloudinaryUploadResult] containing the secure URL
  /// and metadata from Cloudinary's response.
  ///
  /// - [filePath] — local file path to upload
  /// - [folder] — Cloudinary folder (default: 'chat_media')
  /// - [onProgress] — optional callback for upload progress tracking
  Future<CloudinaryUploadResult> upload({
    required String filePath,
    String folder = 'chat_media',
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'upload_preset': CloudinaryConfig.uploadPreset,
        'folder': folder,
      });

      final response = await _dio.post(
        CloudinaryConfig.uploadUrl,
        data: formData,
        onSendProgress: onProgress,
      );

      final data = response.data as Map<String, dynamic>;

      return CloudinaryUploadResult(
        secureUrl: data['secure_url'] as String,
        resourceType: data['resource_type'] as String?,
        format: data['format'] as String?,
        bytes: data['bytes'] as int?,
        width: data['width'] as int?,
        height: data['height'] as int?,
        duration: (data['duration'] as num?)?.toDouble(),
        originalFilename: data['original_filename'] as String?,
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message;
      log('Cloudinary upload failed: $errorMsg', name: 'Cloudinary');
      throw Exception('Upload failed: $errorMsg');
    }
  }

  /// Generate a Cloudinary thumbnail URL for document preview (PDF, DOCX, etc.)
  /// Returns null if the URL is not a Cloudinary URL or not a supported format.
  static String? generateDocumentThumbnail(String uploadUrl, {int width = 400, int height = 400}) {
    if (!uploadUrl.contains('cloudinary.com/')) return null;

    // Supported formats for Cloudinary document thumbnail generation
    final supportedExtensions = ['pdf', 'docx', 'pptx', 'xlsx', 'ai', 'eps', 'psd', 'tiff', 'tif'];
    final extension = uploadUrl.split('.').last.toLowerCase().split('?').first;
    if (!supportedExtensions.contains(extension)) return null;

    // Replace raw/upload with image/upload (Cloudinary serves thumbnails from image endpoint)
    var url = uploadUrl.replaceFirst('/raw/upload/', '/image/upload/');

    // Insert transformation after /upload/
    final transformation = 'pg_1,w_$width,h_$height,c_fit,f_jpg';
    url = url.replaceFirst('/upload/', '/upload/$transformation/');

    return url;
  }
}

/// Riverpod provider for CloudinaryService (singleton).
@Riverpod(keepAlive: true)
CloudinaryService cloudinaryService(Ref ref) {
  return CloudinaryService();
}
