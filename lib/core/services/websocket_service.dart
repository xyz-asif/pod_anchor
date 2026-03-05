import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';

part 'websocket_service.g.dart';

/// All WebSocket event types from the backend.
enum WsEventType {
  message,
  messageStatusChanged,
  reactionUpdated,
  messageEdited,
  messageDeleted,
  roomRead,
  typingStart,
  typingStop;

  static WsEventType? fromString(String? value) {
    switch (value) {
      case 'message':
        return WsEventType.message;
      case 'message_status_changed':
        return WsEventType.messageStatusChanged;
      case 'reaction_updated':
        return WsEventType.reactionUpdated;
      case 'message_edited':
        return WsEventType.messageEdited;
      case 'message_deleted':
        return WsEventType.messageDeleted;
      case 'room_read':
        return WsEventType.roomRead;
      case 'typing_start':
        return WsEventType.typingStart;
      case 'typing_stop':
        return WsEventType.typingStop;
      default:
        return null;
    }
  }

  String get value {
    switch (this) {
      case WsEventType.message:
        return 'message';
      case WsEventType.messageStatusChanged:
        return 'message_status_changed';
      case WsEventType.reactionUpdated:
        return 'reaction_updated';
      case WsEventType.messageEdited:
        return 'message_edited';
      case WsEventType.messageDeleted:
        return 'message_deleted';
      case WsEventType.roomRead:
        return 'room_read';
      case WsEventType.typingStart:
        return 'typing_start';
      case WsEventType.typingStop:
        return 'typing_stop';
    }
  }
}

/// Parsed WebSocket event.
class WsEvent {
  final WsEventType type;
  final String roomId;
  final Map<String, dynamic> payload;

  const WsEvent({
    required this.type,
    required this.roomId,
    required this.payload,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      type: WsEventType.fromString(json['type']) ?? WsEventType.message,
      roomId: json['roomId'] ?? '',
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'])
          : {},
    );
  }
}

/// WebSocket service that manages the real-time connection.
///
/// Features:
/// - Auto-reconnect on disconnect with exponential backoff
/// - Parse incoming events into typed [WsEvent] objects
/// - Expose a broadcast stream for controllers to listen to
/// - Send typing indicators
class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<WsEvent>.broadcast();
  Timer? _reconnectTimer;
  String? _token;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  /// Stream of parsed WebSocket events.
  Stream<WsEvent> get events => _eventController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _isConnected;

  /// Connect to the WebSocket server.
  void connect(String token) {
    _token = token;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_token == null) return;

    try {
      final wsUrl = Uri.parse(ApiEndpoints.webSocketUrl(_token!));
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (data) {
          _isConnected = true;
          _reconnectAttempts = 0;
          _handleMessage(data);
        },
        onError: (error) {
          log('WebSocket error: $error', name: 'WS');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          log('WebSocket disconnected', name: 'WS');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      log(
        'WebSocket connecting to ${ApiEndpoints.webSocketUrl(_token!)}',
        name: 'WS',
      );
    } catch (e) {
      log('WebSocket connection failed: $e', name: 'WS');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final event = WsEvent.fromJson(json);
      _eventController.add(event);
      log(
        'WS event received: ${event.type.value} for room ${event.roomId}',
        name: 'WS',
      );
    } catch (e) {
      log('WS message parse error: $e', name: 'WS');
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      log('Max reconnect attempts reached', name: 'WS');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(1, 30));
    _reconnectAttempts++;

    log(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
      name: 'WS',
    );
    _reconnectTimer = Timer(delay, _doConnect);
  }

  /// Send a raw JSON message over WebSocket.
  void send(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Send typing_start event for a room.
  void sendTypingStart(String roomId) {
    send({'type': 'typing_start', 'roomId': roomId});
  }

  /// Send typing_stop event for a room.
  void sendTypingStop(String roomId) {
    send({'type': 'typing_stop', 'roomId': roomId});
  }

  /// Disconnect and clean up.
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _token = null;
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _eventController.close();
  }
}

/// Riverpod provider for WebSocketService (singleton).
@Riverpod(keepAlive: true)
WebSocketService webSocketService(Ref ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
}
