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
  typingStop,
  userOnline,
  userOffline,
  roomUpdated,
  profileUpdated,
  presenceSync;

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
      case 'user_online':
        return WsEventType.userOnline;
      case 'user_offline':
        return WsEventType.userOffline;
      case 'room_updated':
        return WsEventType.roomUpdated;
      case 'profile_updated':
        return WsEventType.profileUpdated;
      case 'presence_sync':
        return WsEventType.presenceSync;
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
      case WsEventType.userOnline:
        return 'user_online';
      case WsEventType.userOffline:
        return 'user_offline';
      case WsEventType.roomUpdated:
        return 'room_updated';
      case WsEventType.profileUpdated:
        return 'profile_updated';
      case WsEventType.presenceSync:
        return 'presence_sync';
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
/// - Ping/pong keepalive every 30s to prevent idle disconnects
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
  Timer? _presenceSyncTimer;
  Completer<bool>? _connectCompleter;
  bool _intentionalDisconnect = false;

  /// Stream of parsed WebSocket events.
  Stream<WsEvent> get events => _eventController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server.
  void connect(String token) {
    _token = token;
    _reconnectAttempts = 0;

    // Don't connect if already connected
    if (_isConnected) {
      print('[WS] Already connected, skipping connect call');
      return;
    }

    _doConnect();
  }

  /// Connect only if not already connected (useful for app resume).
  Future<bool> connectIfNeeded({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _intentionalDisconnect = false;

    if (_isConnected && _channel != null) return true;
    if (_token == null) return false;

    // If already connecting, wait on existing completer
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      try {
        return await _connectCompleter!.future.timeout(
          timeout,
          onTimeout: () => false,
        );
      } catch (e) {
        return false;
      }
    }

    _reconnectAttempts = 0; // Reset counter for fresh reconnection attempt
    _connectCompleter = Completer<bool>();
    _doConnect();

    try {
      return await _connectCompleter!.future.timeout(
        timeout,
        onTimeout: () => false,
      );
    } catch (e) {
      return false;
    }
  }

  void _doConnect() {
    if (_token == null) return;

    // Close old channel to prevent resource leaks
    _closeChannel();

    try {
      final wsUrl = Uri.parse(ApiEndpoints.webSocketUrl(_token!));
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _startPresenceSyncTimer();
            log('WebSocket connected', name: 'WS');
            if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
              _connectCompleter!.complete(true);
            }
          }
          _reconnectAttempts = 0;
          _handleMessage(data);
        },
        onError: (error) {
          log('WebSocket error: $error', name: 'WS');
          _handleDisconnect();
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason;
          log(
            'WebSocket disconnected (code: $closeCode, reason: $closeReason)',
            name: 'WS',
          );
          _handleDisconnect();
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

      // Ignore pong and connected handshake responses from server
      if (json['type'] == 'pong' || json['type'] == 'connected') return;

      final eventType = WsEventType.fromString(json['type']);
      if (eventType == WsEventType.presenceSync) {
        final payload = json['payload'];
        final event = WsEvent(
          type: WsEventType.presenceSync,
          roomId: '',
          payload: payload is Map ? Map<String, dynamic>.from(payload) : {},
        );
        _eventController.add(event);
        log('WS event received: presence_sync', name: 'WS');
        return;
      }

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

  /// Start periodic presence sync every 60s
  void _startPresenceSyncTimer() {
    _presenceSyncTimer?.cancel();
    _presenceSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isConnected) {
        requestPresenceSync();
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _presenceSyncTimer?.cancel();
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(false);
    }
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;

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
      try {
        _channel!.sink.add(jsonEncode(message));
        print('[WS] Message sent: ${message['type']}');
      } catch (e) {
        log('WS send error: $e', name: 'WS');
      }
    } else {
      print(
        '[WS] Cannot send message ${message['type']}: not connected (channel: ${_channel != null}, connected: $_isConnected)',
      );
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

  /// Send presence status update (online/offline).
  void sendPresenceStatus(bool isOnline) {
    print(
      '[WS] Sending presence status: ${isOnline ? 'online' : 'offline'}, connected: $_isConnected',
    );
    send({
      'type': 'presence_status',
      'payload': {'isOnline': isOnline},
    });
  }

  /// Request a full presence sync from the server
  void requestPresenceSync() {
    send({'type': 'sync_presence', 'payload': {}});
  }

  /// Close the WebSocket channel without resetting token.
  void _closeChannel() {
    _presenceSyncTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }

  /// Disconnect but keep token for reconnection.
  void disconnect() {
    _intentionalDisconnect = true;
    _closeChannel();
    // Don't clear _token so we can reconnect on app resume
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
