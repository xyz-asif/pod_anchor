import 'package:chatbee/features/poems/models/poem_model.dart';

/// Shared normalizer for PoemsPage API responses.
///
/// Handles multiple possible backend field names for `isLikedByMe`:
/// `liked`, `likedByMe`, `liked_by_me`.
PoemsPage normalizePoemsPage(Map<String, dynamic> raw) {
  final rawList = (raw['poems'] as List<dynamic>?) ?? [];
  final normalized = rawList.map((e) {
    if (e is Map<String, dynamic>) {
      final copy = Map<String, dynamic>.from(e);
      if (!copy.containsKey('isLikedByMe')) {
        if (copy.containsKey('liked')) {
          copy['isLikedByMe'] = copy['liked'];
        } else if (copy.containsKey('likedByMe')) {
          copy['isLikedByMe'] = copy['likedByMe'];
        } else if (copy.containsKey('liked_by_me')) {
          copy['isLikedByMe'] = copy['liked_by_me'];
        }
      }
      return copy;
    }
    return e;
  }).toList();

  final normalizedData = Map<String, dynamic>.from(raw);
  normalizedData['poems'] = normalized;
  return PoemsPage.fromJson(normalizedData);
}
