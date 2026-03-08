/// Supported message types for chat messages.
enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  gif,
  link;

  /// Parse a string value to MessageType, defaulting to text.
  static MessageType fromString(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value?.toLowerCase(),
      orElse: () => MessageType.text,
    );
  }

  /// Get a media-aware preview string for a message type.
  String previewText([String? fileName]) {
    switch (this) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📎 ${fileName ?? 'File'}';
      case MessageType.gif:
        return 'GIF';
      case MessageType.link:
        return '🔗 Link';
      case MessageType.text:
        return fileName ?? 'Message';
    }
  }
}
