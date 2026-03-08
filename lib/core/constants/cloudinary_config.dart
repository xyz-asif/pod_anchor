/// Cloudinary configuration for media uploads.
///
/// Replace these with your actual Cloudinary credentials.
class CloudinaryConfig {
  CloudinaryConfig._();

  /// Your Cloudinary cloud name.
  static const String cloudName = 'dviwcqkps';

  /// Your Cloudinary API key.
  static const String apiKey = '271115612443517';

  /// Your Cloudinary API secret.
  static const String apiSecret = '8aMTaTQiWoUkeA_CiJ_mK3EXDzY';

  /// Unsigned upload preset name (created in Cloudinary Dashboard).
  static const String uploadPreset = 'chatbee_unsigned';

  /// Base upload URL (auto resource type handles images, videos, and raw files).
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

  /// Max file size limits (in bytes).
  static const int maxImageSize = 25 * 1024 * 1024; // 25 MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100 MB
  static const int maxFileSize = 25 * 1024 * 1024; // 25 MB
}
