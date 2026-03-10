import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/chat/controllers/message_controller.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/chat/models/room_response.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

part 'ws_event_handler.g.dart';

/// Provider to track the currently visibly open room (used to suppress unread ticks)
final currentOpenRoomProvider = StateProvider<String?>((ref) => null);

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
      case WsEventType.profileUpdated:
        _handleProfileUpdated(ref, event);
        break;
      case WsEventType.typingStart:
      case WsEventType.typingStop:
        _handleTyping(ref, event);
        break;
      case WsEventType.presenceSync:
        _handlePresenceSync(ref, event);
        break;
      case WsEventType.connectionAccepted:
        _handleConnectionAccepted(ref, event);
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
  print('[WS] _handleNewMessage called for room ${event.roomId}');
  try {
    final message = MessageResponse.fromJson(event.payload);
    print('[WS] Message from: ${message.senderId}, my ID: ${ref.read(authControllerProvider).valueOrNull?.id}');

    // If I sent this message, ignore it (already handled optimistically + REST)
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    if (currentUserId != null && message.senderId == currentUserId) {
      print('[WS] Message is from self, ignoring');
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

    // Use media-aware preview instead of raw content/URL
    final preview = message.isMedia
        ? message.messageType.previewText(message.metadata?.fileName)
        : message.content;

    // Check if user is currently viewing this room
    final currentRoomId = ref.read(currentOpenRoomProvider);
    print('[WS] _handleNewMessage: room=${event.roomId}, currentOpenRoom=$currentRoomId');
    if (event.roomId == currentRoomId) {
      // Don't increment unread, just update the preview
      print('[WS] User viewing room, updating preview only');
      ref
          .read(chatListControllerProvider.notifier)
          .updateLastMessage(event.roomId, lastMessage: preview);
    } else {
      // Update chat list: move room to top, increment unread
      print('[WS] User NOT viewing room, incrementing unread');
      ref
          .read(chatListControllerProvider.notifier)
          .moveRoomToTop(event.roomId, lastMessage: preview);
    }
  } catch (e, st) {
    log('Error handling new message: $e, stack: $st', name: 'WS');
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
      log(
        'Message controller not found for room ${event.roomId}, status update queued',
        name: 'WS',
      );
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
      log(
        'Marked all messages as read by $readBy in room ${event.roomId}',
        name: 'WS',
      );
    } else {
      log(
        'Message controller not found for room ${event.roomId}, room read queued',
        name: 'WS',
      );
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

void _handlePresenceSync(Ref ref, WsEvent event) {
  try {
    final chatListNotifier = ref.read(chatListControllerProvider.notifier);
    for (final entry in event.payload.entries) {
      final userId = entry.key;
      final isOnline = entry.value == true;
      chatListNotifier.updatePresence(userId, isOnline: isOnline);
    }
  } catch (e) {
    log('Error handling presence_sync: $e', name: 'WS');
  }
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

/// Handle profile_updated event - update user info across all rooms
void _handleProfileUpdated(Ref ref, WsEvent event) {
  final userId = event.payload['userId'] as String?;
  final displayName = event.payload['displayName'] as String?;
  final photoURL = event.payload['photoURL'] as String?;
  final bio = event.payload['bio'] as String?;

  if (userId == null) return;

  try {
    // Update user info in chat list
    ref
        .read(chatListControllerProvider.notifier)
        .updateUserProfile(
          userId: userId,
          displayName: displayName,
          photoURL: photoURL,
          bio: bio,
        );
    log(
      'Updated profile for user $userId: name=$displayName, photo=$photoURL',
      name: 'WS',
    );
  } catch (e) {
    log('Error handling profile update: $e', name: 'WS');
  }
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

/// Handle connection_accepted event - add new room when friend request is accepted
void _handleConnectionAccepted(Ref ref, WsEvent event) {
  try {
    final payload = event.payload;
    final roomData = payload['room'] as Map<String, dynamic>?;
    
    if (roomData == null) {
      log('connection_accepted: No room data in payload', name: 'WS');
      return;
    }

    // Parse the room data
    final room = RoomResponse.fromJson(roomData);
    
    // Add the room to the chat list
    ref.read(chatListControllerProvider.notifier).upsertRoom(room);
    
    // Get the other user's ID for notification
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    final senderId = payload['senderId'] as String?;
    final receiverId = payload['receiverId'] as String?;
    
    if (currentUserId != null && senderId != null && receiverId != null) {
      // Determine which user is the other person
      final otherUserId = currentUserId == senderId ? receiverId : senderId;
      
      // Show notification (you might want to implement a notification service)
      log('Connection accepted: New room ${room.id} added, other user: $otherUserId', name: 'WS');
      
      // TODO: Show notification to user
      // Could use a notification service or update a global state for notifications
    }
    
    log('Connection accepted: Room ${room.id} added to chat list', name: 'WS');
  } catch (e, st) {
    log('Error handling connection_accepted: $e, stack: $st', name: 'WS');
  }
}
