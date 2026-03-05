import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/chat/controllers/message_controller.dart';
import 'package:chatbee/features/chat/models/message_response.dart';

part 'ws_event_handler.g.dart';

/// Listens to WebSocket events and dispatches them to the correct controllers.
///
/// This is a keepAlive provider that starts listening when first read.
/// Typically initialized right after auth (when WS connects).
@Riverpod(keepAlive: true)
Stream<WsEvent> wsEventHandler(Ref ref) {
  final wsService = ref.read(webSocketServiceProvider);
  final controller = StreamController<WsEvent>();

  final sub = wsService.events.listen((event) {
    controller.add(event);

    switch (event.type) {
      case WsEventType.message:
        _handleNewMessage(ref, event);
        break;
      case WsEventType.messageStatusChanged:
        _handleStatusChanged(ref, event);
        break;
      case WsEventType.roomRead:
        _handleRoomRead(ref, event);
        break;
      case WsEventType.messageEdited:
        _handleMessageEdited(ref, event);
        break;
      case WsEventType.messageDeleted:
        _handleMessageDeleted(ref, event);
        break;
      case WsEventType.reactionUpdated:
        _handleReactionUpdated(ref, event);
        break;
      case WsEventType.typingStart:
      case WsEventType.typingStop:
        // Handled by TypingController below
        break;
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
}

void _handleNewMessage(Ref ref, WsEvent event) {
  try {
    final message = MessageResponse.fromJson(event.payload);

    // Append to message list if that room is open
    try {
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .appendMessage(message);
    } catch (_) {
      // Room not currently open — that's fine
    }

    // Update chat list: move room to top, increment unread
    ref
        .read(chatListControllerProvider.notifier)
        .moveRoomToTop(event.roomId, lastMessage: message.content);
  } catch (e) {
    log('Error handling new message: $e', name: 'WS');
  }
}

void _handleStatusChanged(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  final status = event.payload['status'] as String?;
  if (messageId == null || status == null) return;

  try {
    ref
        .read(messageControllerProvider(event.roomId).notifier)
        .updateMessageStatus(messageId, status);
  } catch (_) {}
}

void _handleRoomRead(Ref ref, WsEvent event) {
  final readBy = event.payload['readBy'] as String?;
  if (readBy == null) return;

  try {
    ref
        .read(messageControllerProvider(event.roomId).notifier)
        .markAllAsRead(readBy);
  } catch (_) {}
}

void _handleMessageEdited(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  final content = event.payload['content'] as String?;
  if (messageId == null || content == null) return;

  try {
    ref
        .read(messageControllerProvider(event.roomId).notifier)
        .editMessage(messageId, content);
  } catch (_) {}
}

void _handleMessageDeleted(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  if (messageId == null) return;

  try {
    ref
        .read(messageControllerProvider(event.roomId).notifier)
        .deleteMessage(messageId);
  } catch (_) {}
}

void _handleReactionUpdated(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  final userId = event.payload['userId'] as String?;
  final emoji = event.payload['emoji'] as String?;
  if (messageId == null || userId == null || emoji == null) return;

  try {
    ref
        .read(messageControllerProvider(event.roomId).notifier)
        .updateReaction(messageId, userId, emoji);
  } catch (_) {}
}

/// Typing state for a specific room.
/// Maps userId → true/false (typing or not).
@riverpod
class TypingController extends _$TypingController {
  StreamSubscription<WsEvent>? _sub;

  @override
  Map<String, bool> build(String roomId) {
    final wsService = ref.read(webSocketServiceProvider);

    _sub = wsService.events
        .where(
          (e) =>
              e.roomId == roomId &&
              (e.type == WsEventType.typingStart ||
                  e.type == WsEventType.typingStop),
        )
        .listen((event) {
          final userId = event.payload['userId'] as String?;
          if (userId == null) return;

          final current = Map<String, bool>.from(state);
          if (event.type == WsEventType.typingStart) {
            current[userId] = true;
          } else {
            current.remove(userId);
          }
          state = current;
        });

    ref.onDispose(() => _sub?.cancel());

    return {};
  }

  /// Send typing_start via WebSocket.
  void startTyping() {
    ref.read(webSocketServiceProvider).sendTypingStart(roomId);
  }

  /// Send typing_stop via WebSocket.
  void stopTyping() {
    ref.read(webSocketServiceProvider).sendTypingStop(roomId);
  }
}
