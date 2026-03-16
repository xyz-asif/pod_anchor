import 'package:chatbee/features/poems/models/poem_model.dart';

class CommentModel {
  final String id;
  final String poemId;
  final PoemAuthor author;
  final String content;
  final int likesCount;
  final bool isLikedByMe;
  final bool isDeleted;
  final DateTime? createdAt;

  const CommentModel({
    required this.id,
    required this.poemId,
    required this.author,
    required this.content,
    this.likesCount = 0,
    this.isLikedByMe = false,
    this.isDeleted = false,
    this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String? ?? '',
      poemId: json['poemId'] as String? ?? '',
      author: PoemAuthor.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
      content: json['content'] as String? ?? '',
      likesCount: json['likesCount'] as int? ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }

  CommentModel copyWith({bool? isLikedByMe, int? likesCount}) {
    return CommentModel(
      id: id, poemId: poemId, author: author, content: content,
      isDeleted: isDeleted, createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}

class CommentsPage {
  final List<CommentModel> comments;
  final bool hasMore;

  const CommentsPage({required this.comments, required this.hasMore});

  factory CommentsPage.fromJson(Map<String, dynamic> json) {
    final list = json['comments'] as List? ?? [];
    return CommentsPage(
      comments: list.map((e) => CommentModel.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
