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
import 'package:chatbee/features/notifications/models/notification_model.dart';
import 'package:chatbee/features/notifications/controllers/notification_controller.dart';
import 'package:chatbee/core/services/notification_service.dart';

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
      case WsEventType.notification:
        _handleNotification(ref, event);
        break;
      case WsEventType.roomDeleted:
        _handleRoomDeleted(ref, event);
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
  // Guard: ignore messages with no roomId — they cannot be routed correctly
  if (event.roomId.isEmpty) {
    log('[WS_DEBUG] _handleNewMessage: ignoring message with empty roomId', name: 'WS');
    return;
  }

  log('[WS_DEBUG] --------------------------------------------------', name: 'WS');
  log('[WS_DEBUG] _handleNewMessage START for room: ${event.roomId}', name: 'WS');

  try {
    final message = MessageResponse.fromJson(event.payload);
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    
    log('[WS_DEBUG] Message sender: ${message.senderId} | Current user: $currentUserId', name: 'WS');

    final isFromSelf = currentUserId != null && message.senderId == currentUserId;

    // Check if we already have this message locally (deduplication)
    if (ref.exists(messageControllerProvider(event.roomId))) {
      final currentMessages = ref.read(messageControllerProvider(event.roomId)).valueOrNull ?? [];
      final alreadyExists = currentMessages.any((m) => m.id == message.id);
      
      if (alreadyExists) {
        log('[WS_DEBUG] ↳ Message already exists locally, ignoring WS echo', name: 'WS');
        log('[WS_DEBUG] --------------------------------------------------', name: 'WS');
        return; // Already handled by optimistic update or previous echo
      }
      
      log('[WS_DEBUG] appendMessage: appending new message from WS', name: 'WS');
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .appendMessage(message);
    } else {
      log('[WS_DEBUG] appendMessage: provider not alive, skipping append', name: 'WS');
    }

    // Use media-aware preview instead of raw content/URL
    final preview = message.isMedia
        ? message.messageType.previewText(message.metadata?.fileName)
        : message.content;

    // Check if user is currently viewing this room
    final currentRoomId = ref.read(currentOpenRoomProvider);
    log('[WS_DEBUG] Event Room ID:   ${event.roomId}', name: 'WS');
    log('[WS_DEBUG] currentOpenRoom: $currentRoomId', name: 'WS');

    if (event.roomId == currentRoomId) {
      // Don't increment unread, just update the preview
      log('[WS_DEBUG] ↳ Match! User is actively viewing this room. Updating preview ONLY (no unread increment).', name: 'WS');
      if (ref.exists(chatListControllerProvider)) {
        ref
            .read(chatListControllerProvider.notifier)
            .updateLastMessage(event.roomId, lastMessage: preview);
      }
      // Auto-mark as read since the user is viewing this room.
      if (!isFromSelf && ref.exists(messageControllerProvider(event.roomId))) {
        ref.read(messageControllerProvider(event.roomId).notifier).markAsRead();
      }
    } else {
      // Update chat list: move room to top. Only increment unread if NOT from self (cross-device).
      log('[WS_DEBUG] ↳ No match. Moving to top. isFromSelf? $isFromSelf', name: 'WS');
      if (ref.exists(chatListControllerProvider)) {
        ref
            .read(chatListControllerProvider.notifier)
            .moveRoomToTop(
              event.roomId,
              lastMessage: preview,
              incrementUnread: !isFromSelf,
            );
      }

      // Show a local notification so the user knows a message arrived while
      // they're elsewhere in the app (backend may not send FCM for chat).
      if (!isFromSelf) {
        String senderName = 'New message';
        final rooms = ref.read(chatListControllerProvider).valueOrNull;
        if (rooms != null) {
          for (final room in rooms) {
            if (room.id == event.roomId) {
              for (final p in room.participants) {
                if (p.id == message.senderId) {
                  senderName = p.displayName ?? senderName;
                  break;
                }
              }
              break;
            }
          }
        }
        ref.read(notificationServiceProvider).showLocalMessageNotification(
          roomId: event.roomId,
          senderName: senderName,
          preview: preview,
        );
      }
    }
  } catch (e, st) {
    log('[WS_DEBUG] Error handling new message: $e\n$st', name: 'WS');
  }
  log('[WS_DEBUG] _handleNewMessage END', name: 'WS');
  log('[WS_DEBUG] --------------------------------------------------', name: 'WS');
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
    if (ref.exists(messageControllerProvider(event.roomId))) {
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .editMessage(messageId, content);
    }
    
    // Check if this was the last message and update chat list
    if (ref.exists(chatListControllerProvider)) {
      // The simplest approach is to update preview if it was text (we don't have message type here easily)
      ref.read(chatListControllerProvider.notifier).updateLastMessageIfMatch(
        event.roomId, 
        messageId: messageId, 
        newPreview: content,
      );
    }
  } catch (_) {}
}

void _handleMessageDeleted(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  if (messageId == null) return;

  try {
    if (ref.exists(messageControllerProvider(event.roomId))) {
      ref
          .read(messageControllerProvider(event.roomId).notifier)
          .deleteMessage(messageId);
    }
    
    // Update chat list if it was the last message
    if (ref.exists(chatListControllerProvider)) {
      ref.read(chatListControllerProvider.notifier).updateLastMessageIfMatch(
        event.roomId, 
        messageId: messageId, 
        newPreview: "This message was deleted",
      );
    }
  } catch (_) {}
}

void _handleReactionUpdated(Ref ref, WsEvent event) {
  final messageId = event.payload['messageId'] as String?;
  final userId = event.payload['userId'] as String?;
  final emoji = event.payload['emoji'] as String?;
  if (messageId == null || userId == null || emoji == null) return;

  try {
    if (!ref.exists(messageControllerProvider(event.roomId))) return;
    ref
        .read(messageControllerProvider(event.roomId).notifier)
        .updateReaction(messageId, userId, emoji);
  } catch (_) {}
}

void _handlePresenceSync(Ref ref, WsEvent event) {
  try {
    if (!ref.exists(chatListControllerProvider)) return;

    // Build the map first, then apply in one state write to avoid N rebuilds.
    final presenceMap = event.payload.map(
      (key, value) => MapEntry(key, value == true),
    );
    ref.read(chatListControllerProvider.notifier).updatePresenceBatch(presenceMap);
  } catch (e) {
    log('Error handling presence_sync: $e', name: 'WS');
  }
}

void _handleUserOnline(Ref ref, WsEvent event, bool isOnline) {
  final userId = event.payload['userId'] as String?;
  if (userId == null) return;

  try {
    if (ref.exists(chatListControllerProvider)) {
      ref
          .read(chatListControllerProvider.notifier)
          .updatePresence(userId, isOnline: isOnline);
    }
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
    if (ref.exists(chatListControllerProvider)) {
      ref
          .read(chatListControllerProvider.notifier)
          .handleRoomUpdated(
            roomId: event.roomId,
            lastMessage: lastMessage,
            lastUpdated: lastUpdated,
            lastSenderId: lastSenderId,
          );
    }
  } catch (e) {
    log('Error handling room_updated: $e', name: 'WS');
  }
}

void _handleTyping(Ref ref, WsEvent event) {
  final userId = event.payload['userId'] as String?;
  if (userId == null) return;

  try {
    if (ref.exists(typingControllerProvider(event.roomId))) {
      ref
          .read(typingControllerProvider(event.roomId).notifier)
          .handleRemoteTyping(userId, event.type == WsEventType.typingStart);
    }
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
    if (ref.exists(chatListControllerProvider)) {
      ref
          .read(chatListControllerProvider.notifier)
          .updateUserProfile(
            userId: userId,
            displayName: displayName,
            photoURL: photoURL,
            bio: bio,
          );
    }
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
///
/// Safety: Auto-clears typing state after 5 seconds if no new
/// typing_start arrives — handles force-close / crash scenarios.
@riverpod
class TypingController extends _$TypingController {
  final Map<String, Timer> _typingTimers = {};

  @override
  Map<String, bool> build(String roomId) {
    ref.onDispose(() {
      for (final timer in _typingTimers.values) {
        timer.cancel();
      }
      _typingTimers.clear();
    });
    return {};
  }

  /// Called by wsEventHandler when a remote typing event arrives.
  void handleRemoteTyping(String userId, bool isTyping) {
    final current = Map<String, bool>.from(state);

    // Cancel existing timer for this user
    _typingTimers[userId]?.cancel();

    if (isTyping) {
      current[userId] = true;

      // Safety: prevent unbounded timer map growth (defensive, unlikely in practice)
      if (_typingTimers.length > 20) {
        for (final timer in _typingTimers.values) {
          timer.cancel();
        }
        _typingTimers.clear();
        current.clear();
      }

      // Auto-clear after 5 seconds if no new typing_start arrives
      _typingTimers[userId] = Timer(const Duration(seconds: 5), () {
        final updated = Map<String, bool>.from(state);
        updated.remove(userId);
        state = updated;
        _typingTimers.remove(userId);
      });
    } else {
      current.remove(userId);
      _typingTimers.remove(userId);
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

void _handleRoomDeleted(Ref ref, WsEvent event) {
  final roomId = event.payload['roomId'] as String? ?? event.roomId;
  if (roomId.isEmpty) return;

  try {
    if (ref.exists(chatListControllerProvider)) {
      ref.read(chatListControllerProvider.notifier).removeRoomLocally(roomId);
    }
    log('Room $roomId deleted by remote participant', name: 'WS');
  } catch (e) {
    log('Error handling room_deleted: $e', name: 'WS');
  }
}

void _handleNotification(Ref ref, WsEvent event) {
  try {
    final notif = NotificationModel.fromJson(event.payload);
    ref.read(notificationControllerProvider.notifier).addFromWebSocket(notif);
  } catch (e) {
    log('Error handling notification event: $e', name: 'WS');
  }
}

/// Handle connection_accepted event - add new room when friend request is accepted
void _handleConnectionAccepted(Ref ref, WsEvent event) async {
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
    if (ref.exists(chatListControllerProvider)) {
      ref.read(chatListControllerProvider.notifier).upsertRoom(room);
    }
    log('Connection accepted: requesting presence sync', name: 'WS');
    await Future.delayed(const Duration(milliseconds: 300));
    // Guard: provider container may have been disposed during the delay
    try {
      ref.read(webSocketServiceProvider).requestPresenceSync();
      log('Connection accepted: presence sync requested', name: 'WS');
    } catch (_) {
      log('Connection accepted: presence sync skipped (ref disposed)', name: 'WS');
    }

    // Get the other user's ID for notification
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    final senderId = payload['senderId'] as String?;
    final receiverId = payload['receiverId'] as String?;

    if (currentUserId != null && senderId != null && receiverId != null) {
      // Determine which user is the other person
      final otherUserId = currentUserId == senderId ? receiverId : senderId;

      // Show notification (you might want to implement a notification service)
      log(
        'Connection accepted: New room ${room.id} added, other user: $otherUserId',
        name: 'WS',
      );

      // TODO: Show notification to user
      // Could use a notification service or update a global state for notifications
    }

    log('Connection accepted: Room ${room.id} added to chat list', name: 'WS');
  } catch (e, st) {
    log('Error handling connection_accepted: $e, stack: $st', name: 'WS');
  }
}
