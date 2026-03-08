import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/chat/controllers/message_controller.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

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
      case WsEventType.userOnline:
        _handleUserOnline(ref, event, true);
        break;
      case WsEventType.userOffline:
        _handleUserOnline(ref, event, false);
        break;
      case WsEventType.roomUpdated:
        _handleRoomUpdated(ref, event);
        break;
      case WsEventType.typingStart:
      case WsEventType.typingStop:
        _handleTyping(ref, event);
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

    // If I sent this message, ignore it (already handled optimistically + REST)
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    if (currentUserId != null && message.senderId == currentUserId) {
      return;
    }

    // Append to message list if that room is open
    try {
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .appendMessage(message);
    } catch (_) {
      // Room not currently open — that's fine
    }

    // Update chat list: move room to top, increment unread
    // Use media-aware preview instead of raw content/URL
    final preview = message.isMedia
        ? message.messageType.previewText(message.metadata?.fileName)
        : message.content;
    ref
        .read(chatListControllerProvider.notifier)
        .moveRoomToTop(event.roomId, lastMessage: preview);
  } catch (e) {
    log('Error handling new message: $e', name: 'WS');
  }
}

void _handleStatusChanged(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  final status = event.payload['status'] as String?;
  if (messageId == null || status == null) return;

  try {
    // Check if the provider exists before reading it
    final providerExists = ref.exists(messageControllerProvider(event.roomId));
    if (providerExists) {
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .updateMessageStatus(messageId, status);
      log('Status updated for message $messageId: $status', name: 'WS');
    } else {
      log('Message controller not found for room ${event.roomId}, status update queued', name: 'WS');
    }
  } catch (e) {
    log('Error handling status changed: $e', name: 'WS');
  }
}

void _handleRoomRead(Ref ref, WsEvent event) {
  final readBy = event.payload['readBy'] as String?;
  if (readBy == null) return;

  try {
    // Check if the provider exists before reading it
    final providerExists = ref.exists(messageControllerProvider(event.roomId));
    if (providerExists) {
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .markAllAsRead(readBy);
      log('Marked all messages as read by $readBy in room ${event.roomId}', name: 'WS');
    } else {
      log('Message controller not found for room ${event.roomId}, room read queued', name: 'WS');
    }
  } catch (e) {
    log('Error handling room read: $e', name: 'WS');
  }
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

void _handleUserOnline(Ref ref, WsEvent event, bool isOnline) {
  final userId = event.payload['userId'] as String?;
  if (userId == null) return;

  try {
    ref
        .read(chatListControllerProvider.notifier)
        .updatePresence(userId, isOnline: isOnline);
  } catch (_) {}
}

void _handleRoomUpdated(Ref ref, WsEvent event) {
  final lastMessage = event.payload['lastMessage'] as String?;
  final lastUpdatedStr = event.payload['lastUpdated'] as String?;
  final lastSenderId = event.payload['lastSenderId'] as String?;

  if (lastMessage == null || lastUpdatedStr == null || lastSenderId == null) {
    return;
  }

  try {
    final lastUpdated = DateTime.parse(lastUpdatedStr);
    ref
        .read(chatListControllerProvider.notifier)
        .handleRoomUpdated(
          roomId: event.roomId,
          lastMessage: lastMessage,
          lastUpdated: lastUpdated,
          lastSenderId: lastSenderId,
        );
  } catch (e) {
    log('Error handling room_updated: $e', name: 'WS');
  }
}

void _handleTyping(Ref ref, WsEvent event) {
  final userId = event.payload['userId'] as String?;
  if (userId == null) return;

  try {
    ref
        .read(typingControllerProvider(event.roomId).notifier)
        .handleRemoteTyping(userId, event.type == WsEventType.typingStart);
  } catch (_) {}
}

/// Typing state for a specific room.
/// Maps userId → true/false (typing or not).
@riverpod
class TypingController extends _$TypingController {
  @override
  Map<String, bool> build(String roomId) {
    return {};
  }

  /// Called by wsEventHandler when a remote typing event arrives.
  void handleRemoteTyping(String userId, bool isTyping) {
    final current = Map<String, bool>.from(state);
    if (isTyping) {
      current[userId] = true;
    } else {
      current.remove(userId);
    }
    state = current;
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
