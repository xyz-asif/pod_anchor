import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';

part 'websocket_service.g.dart';

/// All WebSocket event types from backend.
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
  presenceSync,
  connectionAccepted,
  notification;

  static WsEventType? fromString(String? value) {
    switch (value) {
      case 'message':             return WsEventType.message;
      case 'message_status_changed': return WsEventType.messageStatusChanged;
      case 'reaction_updated':    return WsEventType.reactionUpdated;
      case 'message_edited':      return WsEventType.messageEdited;
      case 'message_deleted':     return WsEventType.messageDeleted;
      case 'room_read':           return WsEventType.roomRead;
      case 'typing_start':        return WsEventType.typingStart;
      case 'typing_stop':         return WsEventType.typingStop;
      case 'user_online':         return WsEventType.userOnline;
      case 'user_offline':        return WsEventType.userOffline;
      case 'room_updated':        return WsEventType.roomUpdated;
      case 'profile_updated':     return WsEventType.profileUpdated;
      case 'presence_sync':       return WsEventType.presenceSync;
      case 'connection_accepted': return WsEventType.connectionAccepted;
      case 'notification':        return WsEventType.notification;
      default:                    return null;
    }
  }

  String get value {
    switch (this) {
      case WsEventType.message:              return 'message';
      case WsEventType.messageStatusChanged: return 'message_status_changed';
      case WsEventType.reactionUpdated:      return 'reaction_updated';
      case WsEventType.messageEdited:        return 'message_edited';
      case WsEventType.messageDeleted:       return 'message_deleted';
      case WsEventType.roomRead:             return 'room_read';
      case WsEventType.typingStart:          return 'typing_start';
      case WsEventType.typingStop:           return 'typing_stop';
      case WsEventType.userOnline:           return 'user_online';
      case WsEventType.userOffline:          return 'user_offline';
      case WsEventType.roomUpdated:          return 'room_updated';
      case WsEventType.profileUpdated:       return 'profile_updated';
      case WsEventType.presenceSync:         return 'presence_sync';
      case WsEventType.connectionAccepted:   return 'connection_accepted';
      case WsEventType.notification:         return 'notification';
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

/// WebSocket service — manages real-time connection.
///
/// Stability guarantees:
/// - Zombie detection: pong must arrive within [_pongTimeoutSeconds] of each
///   ping, otherwise connection is force-closed and reconnected.
/// - Correct state: connected flag is set in channel.ready, not on first data.
/// - Concurrency guard: _isConnecting prevents opening two sockets at once.
/// - Network change: connectivity_plus triggers instant reconnect on network
///   restored (WiFi↔cellular, airplane-mode off, etc.).
/// - Exponential backoff + jitter on failed reconnects.
/// - Token refresh: updateToken() lets resume flow inject a fresh
///   Firebase token without fully disconnecting.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final _eventController = StreamController<WsEvent>.broadcast();

  Timer? _reconnectTimer;
  Timer? _presenceSyncTimer;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  StreamSubscription? _connectivitySubscription;

  static const int _pongTimeoutSeconds    = 10;
  static const int _pingIntervalSeconds   = 10; // < backend 15s read timeout
  static const int _maxReconnectAttempts  = 10;

  String? _token;
  bool _isConnected  = false;
  bool _isConnecting = false;
  int  _reconnectAttempts = 0;

  Completer<bool>? _connectCompleter;
  bool _intentionalDisconnect = false;

  final _random = math.Random();

  /// Stream of parsed WebSocket events.
  Stream<WsEvent> get events => _eventController.stream;

  bool get isConnected => _isConnected;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Initial connect after sign-in. Starts connectivity listener.
  void connect(String token) {
    _token = token;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;

    _startConnectivityListener(); // only wired once here

    if (_isConnected || _isConnecting) {
      log('[WS] Already connected/connecting — skipped', name: 'WS');
      return;
    }
    _doConnect();
  }

  /// Update stored token without reconnecting (called on resume).
  /// If the socket is already connected new token is used for the
  /// next reconnect attempt only — no mid-session disruption.
  void updateToken(String token) {
    _token = token;
    log('[WS] Token updated', name: 'WS');
  }

  /// Reconnect if needed (foreground resume). Safe to call multiple times.
  Future<bool> connectIfNeeded({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _intentionalDisconnect = false;

    if (_isConnected && _channel != null) return true;
    if (_token == null) return false;

    // Reuse an in-flight attempt
    if (_isConnecting &&
        _connectCompleter != null &&
        !_connectCompleter!.isCompleted) {
      try {
        return await _connectCompleter!.future.timeout(timeout,
            onTimeout: () => false);
      } catch (_) {
        return false;
      }
    }

    _reconnectAttempts = 0;
    _connectCompleter = Completer<bool>();
    _doConnect();

    try {
      return await _connectCompleter!.future
          .timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  /// Send a raw JSON message.
  void send(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        log('[WS] Send error: $e', name: 'WS');
      }
    } else {
      log('[WS] Cannot send ${message['type']}: not connected', name: 'WS');
    }
  }

  void sendTypingStart(String roomId) =>
      send({'type': 'typing_start', 'roomId': roomId});

  void sendTypingStop(String roomId) =>
      send({'type': 'typing_stop', 'roomId': roomId});

  void sendPresenceStatus(bool isOnline) => send({
        'type': 'presence_status',
        'payload': {'isOnline': isOnline},
      });

  void requestPresenceSync() =>
      send({'type': 'sync_presence', 'payload': {}});

  /// Intentional disconnect — keeps token for next connectIfNeeded.
  void disconnect() {
    _intentionalDisconnect = true;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _closeChannel(keepToken: true);
  }

  /// HTTP disconnect + close. Called when app goes to background.
  Future<void> disconnectAndNotifyServer() async {
    if (_token == null) { disconnect(); return; }
    _intentionalDisconnect = true;

    try {
      await http
          .post(
            Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.chatDisconnect),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      log('[WS] Disconnect API error: $e', name: 'WS');
    } finally {
      _closeChannel(keepToken: true);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _channelSubscription?.cancel();
    disconnect();
    _eventController.close();
  }

  // ─── Internal: connect ──────────────────────────────────────────────────────

  void _doConnect() {
    if (_token == null || _intentionalDisconnect) return;

    if (_isConnecting) {
      log('[WS] _doConnect skipped — already connecting', name: 'WS');
      return;
    }

    _closeChannel(keepToken: true);
    _isConnecting = true;

    try {
      final wsUrl = Uri.parse(ApiEndpoints.webSocketUrl(_token!));
      _channel = WebSocketChannel.connect(wsUrl);
      log('[WS] Connecting…', name: 'WS');

      // Set _isConnected only after WS handshake completes — NOT on first data.
      _channel!.ready.then((_) {
        if (_intentionalDisconnect) return;
        _isConnecting  = false;
        _isConnected   = true;
        _reconnectAttempts = 0;
        _startPresenceSyncTimer();
        _startPingTimer();
        log('[WS] Connected ✓', name: 'WS');
        if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
          _connectCompleter!.complete(true);
        }
      }).catchError((Object e) {
        log('[WS] Handshake error: $e', name: 'WS');
        _isConnecting = false;
        _handleDisconnect();
      });

      _channelSubscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: (Object error) {
          log('[WS] Stream error: $error', name: 'WS');
          _isConnecting = false;
          _handleDisconnect();
        },
        onDone: () {
          final code   = _channel?.closeCode;
          final reason = _getCloseReasonDescription(code, _channel?.closeReason);
          log('[WS] Disconnected — $code ($reason)', name: 'WS');
          _isConnecting = false;
          _handleDisconnect();
        },
      );
    } catch (e) {
      log('[WS] Connect threw: $e', name: 'WS');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  // ─── Internal: messages ─────────────────────────────────────────────────────

  void _handleRawMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      // Pong (or any data) proves connection is alive — cancel pong timer.
      if (type == 'pong' || type == 'connected') {
        _cancelPongTimeout();
        log('[WS] Pong ✓', name: 'WS');
        return;
      }
      // Any other incoming data also resets the zombie timer.
      _cancelPongTimeout();

      if (type == 'presence_sync') {
        final payload = json['payload'];
        _eventController.add(WsEvent(
          type: WsEventType.presenceSync,
          roomId: '',
          payload: payload is Map ? Map<String, dynamic>.from(payload) : {},
        ));
        return;
      }

      final event = WsEvent.fromJson(json);
      _eventController.add(event);
      log('[WS] ← ${event.type.value} (room: ${event.roomId})', name: 'WS');
    } catch (e) {
      log('[WS] Parse error: $e', name: 'WS');
    }
  }

  // ─── Internal: keepalive ────────────────────────────────────────────────────

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: _pingIntervalSeconds),
      (_) => _sendPing(),
    );
    log('[WS] Ping timer started (${_pingIntervalSeconds}s interval)', name: 'WS');
  }

  void _sendPing() {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
      log('[WS] Ping →', name: 'WS');
    } catch (e) {
      log('[WS] Ping error: $e', name: 'WS');
      return;
    }

    // Arm pong timeout only if one isn't already running.
    _pongTimeoutTimer ??= Timer(
      const Duration(seconds: _pongTimeoutSeconds),
      () {
        log(
          '[WS] ⚠️ No pong in ${_pongTimeoutSeconds}s — zombie detected, reconnecting…',
          name: 'WS',
        );
        _pongTimeoutTimer = null;
        _isConnected = false;
        _closeChannel(keepToken: true);
        _scheduleReconnect();
      },
    );
  }

  void _cancelPongTimeout() {
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
  }

  void _startPresenceSyncTimer() {
    _presenceSyncTimer?.cancel();
    _presenceSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_isConnected) requestPresenceSync();
    });
  }

  // ─── Internal: network change ───────────────────────────────────────────────

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork =
          results.any((r) => r != ConnectivityResult.none);

      log('[WS] Network change — hasNetwork: $hasNetwork, connected: $_isConnected',
          name: 'WS');

      if (hasNetwork && !_isConnected && !_isConnecting && !_intentionalDisconnect) {
        log('[WS] Network restored — reconnecting immediately…', name: 'WS');
        _reconnectAttempts = 0; // fresh network = fresh attempt counter
        _reconnectTimer?.cancel();
        _doConnect();
      }
    });
  }

  // ─── Internal: disconnect / reconnect ───────────────────────────────────────

  void _handleDisconnect() {
    final wasConnected = _isConnected;
    _isConnected  = false;
    _isConnecting = false;
    _presenceSyncTimer?.cancel();
    _pingTimer?.cancel();
    _cancelPongTimeout();

    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(false);
    }

    if (_intentionalDisconnect) return;

    if (wasConnected) {
      // Was fully connected and dropped — retry immediately once, then backoff.
      _doConnect();
    } else {
      _scheduleReconnect();
    }
  }

  /// Exponential backoff: 3 * 2^attempt seconds ± 20% jitter, clamped 3–30 s.
  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      log('[WS] Max reconnect attempts reached', name: 'WS');
      return;
    }

    _reconnectTimer?.cancel();
    final base   = 3 * math.pow(2, _reconnectAttempts).toInt();
    final capped = base.clamp(3, 30);
    final jitter = (_random.nextDouble() * 0.4 - 0.2) * capped;
    final delay  = Duration(seconds: (capped + jitter).round().clamp(3, 30));
    _reconnectAttempts++;

    log(
      '[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
      name: 'WS',
    );
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void _closeChannel({bool keepToken = false}) {
    _reconnectTimer?.cancel();
    _presenceSyncTimer?.cancel();
    _pingTimer?.cancel();
    _cancelPongTimeout();

    _channelSubscription?.cancel();
    _channelSubscription = null;

    try { _channel?.sink.close(); } catch (_) {}
    _channel      = null;
    _isConnected  = false;
    _isConnecting = false;

    if (!keepToken) _token = null;
  }

  String _getCloseReasonDescription(int? code, String? reason) {
    if (reason != null && reason.isNotEmpty) return reason;
    switch (code) {
      case 1000: return 'normal closure';
      case 1001: return 'going away';
      case 1002: return 'protocol error';
      case 1006: return 'abnormal closure (connection lost)';
      case 1008: return 'policy violation';
      case 1011: return 'internal server error';
      case 1015: return 'TLS failure';
      default:   return 'unknown (code: $code)';
    }
  }
}

/// Riverpod provider for WebSocketService (keepAlive singleton).
@Riverpod(keepAlive: true)
WebSocketService webSocketService(Ref ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
}
