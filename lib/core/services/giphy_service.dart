import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/giphy_config.dart';

part 'giphy_service.g.dart';

/// Represents a parsed GIF from Giphy API.
class GiphyGif {
  final String id;
  final String url; // Downsized URL for display and sending
  final String title;

  const GiphyGif({required this.id, required this.url, required this.title});

  factory GiphyGif.fromJson(Map<String, dynamic> json) {
    // For chat messages, downsized or fixed_height is best for speed and size
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final downsized = images['downsized'] as Map<String, dynamic>? ?? {};
    final url = downsized['url'] as String? ?? '';

    return GiphyGif(
      id: json['id'] as String? ?? '',
      url: url,
      title: json['title'] as String? ?? 'GIF',
    );
  }
}

/// Service for fetching GIFs from Giphy REST API.
class GiphyService {
  final Dio _dio;

  GiphyService({Dio? dio}) : _dio = dio ?? Dio();

  /// Get trending GIFs.
  Future<List<GiphyGif>> getTrending() async {
    try {
      final response = await _dio.get(GiphyConfig.trendingUrl);
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => GiphyGif.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Giphy trending failed: $e', name: 'Giphy');
      throw Exception('Failed to load trending GIFs');
    }
  }

  /// Search for GIFs by query.
  Future<List<GiphyGif>> search(String query) async {
    if (query.trim().isEmpty) return getTrending();

    try {
      final response = await _dio.get(GiphyConfig.searchUrl(query.trim()));
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((e) => GiphyGif.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Giphy search failed: $e', name: 'Giphy');
      throw Exception('Failed to search GIFs');
    }
  }
}

@riverpod
GiphyService giphyService(Ref ref) {
  return GiphyService();
}

@riverpod
Future<List<GiphyGif>> trendingGifs(Ref ref) {
  return ref.read(giphyServiceProvider).getTrending();
}
