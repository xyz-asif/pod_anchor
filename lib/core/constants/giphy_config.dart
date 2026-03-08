/// Giphy API configuration for GIF picker.
///
/// Replace the API key with your actual Giphy API key.
/// Get one at: https://developers.giphy.com
class GiphyConfig {
  GiphyConfig._();

  /// Your Giphy API key.
  static const String apiKey = 'zKqXzo4gBnfqaMoLBbBsOc4zNwtKGiqI';

  /// Giphy API base URL.
  static const String baseUrl = 'https://api.giphy.com/v1/gifs';

  /// Trending GIFs endpoint.
  static String get trendingUrl => '$baseUrl/trending?api_key=$apiKey&limit=25';

  /// Search GIFs endpoint.
  static String searchUrl(String query) =>
      '$baseUrl/search?api_key=$apiKey&q=$query&limit=25';
}
