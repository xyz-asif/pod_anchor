# Chat Feature Audit v2 — ChatBee Flutter App

> **Scope**: Chat screen, message controller, chat list controller, media bubbles, typing, reactions, WS event handler (chat-specific), chat repo
> **Files**: `chat_screen.dart`, `message_controller.dart`, `chat_list_controller.dart`, `ws_event_handler.dart`, `chat_repo.dart`, `media_bubble.dart`, `chat_state_controller.dart`
> **Note**: The chat system is well-built — optimistic updates, WS deduplication, swipe-to-reply, context menus, and media handling are all solid. This audit focuses on edge cases that cause real user-facing bugs.

---

## Summary

9 issues found. The most impactful: typing indicators that never clear when the other user closes the app, missing haptic feedback on send, AudioPlayer stream subscriptions that aren't explicitly cancelled, and media upload errors being silently swallowed.

---

## Fixes

---

### 1. HIGH — Typing indicator never clears if other user force-closes the app

**File**: `ws_event_handler.dart` → `TypingController`

**Problem**: When user A starts typing, a `typing_start` WS event is sent to user B. If user A then force-closes the app (swipe-kill, crash, airplane mode), the `typing_stop` event is never sent. User B sees "typing..." permanently until they leave and re-enter the chat screen.

**Fix**: Add a timeout in the `TypingController` that auto-clears typing state after 5 seconds. The sender's 2-second debounce means a new `typing_start` arrives every ~2 seconds while actively typing. If it stops (for any reason), the 5-second timer clears the indicator.

```dart
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
```

---

### 2. HIGH — Missing haptic feedback on message send

**File**: `chat_screen.dart`

**Problem**: Sending a message is the most frequent interaction in the app. Other buttons (long-press context menu, AppButton, login) have haptic feedback, but the send button does not.

**Fix**: Add haptic feedback on send (text, media, and GIF):

In `_onSendMessageRequested` (line 251):

```dart
void _onSendMessageRequested(String content) {
    if (content.isEmpty) return;
    HapticFeedback.lightImpact();  // ADD THIS

    final inputState = ref.read(chatInputControllerProvider(widget.roomId));
    // ... rest unchanged
}
```

In `_sendMediaMessage` (line 318):

```dart
void _sendMediaMessage(PickedMedia picked, MessageType type) {
    HapticFeedback.lightImpact();  // ADD THIS
    // ... rest unchanged
}
```

In `_sendGifMessage` (line 269):

```dart
void _sendGifMessage(GiphyGif gif) {
    HapticFeedback.lightImpact();  // ADD THIS
    // ... rest unchanged
}
```

For incoming messages: Do NOT add haptic on every received message — in active chats this would feel spammy. The visual indicators (auto-scroll, unread badge) are sufficient.

---

### 3. HIGH — AudioPlayer stream subscriptions not explicitly cancelled

**File**: `media_bubble.dart` — `_AudioBubbleState`

**Problem**: In `_initAudio()`, three stream subscriptions are created (`playerStateStream`, `durationStream`, `positionStream`) but never stored or explicitly cancelled. While `_initAudio()` guards against double creation with `if (_player != null || _isDisposed) return;`, the subscriptions themselves are not cancelled before `_player?.dispose()` in `dispose()`. If a stream callback is in-flight between `_isDisposed = true` and `_player?.dispose()`, it can race with widget disposal.

**Fix**: Store the subscriptions and cancel them explicitly in dispose:

```dart
class _AudioBubbleState extends State<_AudioBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDisposed = false;
  
  // ADD THESE:
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  // ... initState unchanged ...

  Future<void> _initAudio() async {
    if (_player != null || _isDisposed) return;
    
    try {
      _player = AudioPlayer();
      
      // CHANGED: Store subscriptions
      _playerStateSub = _player!.playerStateStream.listen((state) {
        // ... listener body unchanged ...
      });

      _durationSub = _player!.durationStream.listen((d) {
        // ... listener body unchanged ...
      });

      _positionSub = _player!.positionStream.listen((p) {
        // ... listener body unchanged ...
      });

      // ... rest of _initAudio unchanged ...
    }
    // ... catch blocks unchanged ...
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioController.unregister(widget.message.id);
    
    // ADDED: Cancel subscriptions before disposing player
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    
    _player?.stop();
    _player?.dispose();
    _player = null;
    super.dispose();
  }
}
```

Add `import 'dart:async';` at the top of `media_bubble.dart` if not already present.

---

### 4. MEDIUM — Deleted message bubble uses light theme color

**File**: `chat_screen.dart` (line 1221-1223)

**Problem**: Deleted messages use `Colors.grey.shade100` for the bubble background — a light gray that looks jarring on the dark navy theme:

```dart
color: isDeleted
    ? Colors.grey.shade100  // ← Light theme color on dark background
    : isMe ? AppTheme.primaryDark : AppTheme.featureBackgroundColor,
```

**Fix**:

```dart
color: isDeleted
    ? AppTheme.borderColor  // Dark theme-friendly muted color
    : isMe ? AppTheme.primaryDark : AppTheme.featureBackgroundColor,
```

---

### 5. MEDIUM — Media upload errors silently swallowed

**File**: `chat_screen.dart` → `_sendMediaMessage` (line 318-341)

**Problem**: `_sendMediaMessage` calls `sendMediaMessage` on the message controller but doesn't `await` it. The `try-catch` only catches synchronous errors, so async failures (Cloudinary upload timeout, file too large rejection) are never caught. The optimistic message silently vanishes with no error feedback.

**Fix**: Make it `async` and `await` the call:

```dart
Future<void> _sendMediaMessage(PickedMedia picked, MessageType type) async {
    HapticFeedback.lightImpact();
    try {
      final inputState = ref.read(chatInputControllerProvider(widget.roomId));
      await ref.read(messageControllerProvider(widget.roomId).notifier)  // ADD await
          .sendMediaMessage(
            filePath: picked.filePath,
            fileName: picked.fileName,
            messageType: type,
            mimeType: picked.mimeType,
            fileSize: picked.fileSize,
            replyToId: inputState.replyToId,
          );
      _clearPreview();
    } catch (e) {
      HapticFeedback.heavyImpact();  // Failure buzz
      if (mounted) {
        final typeLabel = type == MessageType.image ? 'photo'
            : type == MessageType.video ? 'video'
            : type == MessageType.audio ? 'voice message'
            : 'file';
        AppSnackbar.show(
          context,
          message: 'Failed to send $typeLabel: ${e.toString().replaceAll('Exception: ', '')}',
          type: SnackbarType.error,
        );
      }
    }
}
```

Apply the same `async/await` pattern to `_sendGifMessage`:

```dart
Future<void> _sendGifMessage(GiphyGif gif) async {
    HapticFeedback.lightImpact();
    try {
      final metadata = MediaMetadata(fileName: gif.title, mimeType: 'image/gif');
      final inputState = ref.read(chatInputControllerProvider(widget.roomId));

      await ref.read(messageControllerProvider(widget.roomId).notifier)  // ADD await
          .sendMessage(
            gif.url,
            replyToId: inputState.replyToId,
            type: MessageType.gif,
            metadata: metadata,
          );
      _clearPreview();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        AppSnackbar.show(context, message: 'Failed to send GIF: $e', type: SnackbarType.error);
      }
    }
}
```

---

### 6. MEDIUM — Swipe-to-reply disabled on audio messages

**File**: `chat_screen.dart` (line 1096-1169)

**Problem**: Audio messages use a separate rendering path that doesn't include the `Dismissible` widget. All other message types support swipe-to-reply, but audio messages only support long-press → context menu → Reply. Inconsistent UX.

**Fix**: Wrap the audio message `GestureDetector` in the same `Dismissible` pattern:

```dart
if (isAudio) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: hasReactions ? 12.h : 0),
        child: Dismissible(  // ADD Dismissible wrapper
          key: ValueKey('swipe_${message.id}'),
          direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
          confirmDismiss: (direction) async {
            if (onReply != null) onReply!();
            return false;
          },
          background: Container(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.reply_rounded, color: AppTheme.primaryColor, size: 24.sp),
            ),
          ),
          child: GestureDetector(  // Existing GestureDetector
            onLongPress: onLongPress,
            child: Stack(
              // ... existing audio bubble content unchanged ...
            ),
          ),
        ),
      ),
    );
}
```

---

### 7. MEDIUM — `NetworkImage` used instead of `CachedNetworkImage` for chat avatar

**File**: `chat_screen.dart` (line 527-528)

**Problem**: The app bar avatar uses `NetworkImage(photoURL)` which re-downloads every time the screen opens. The rest of the app consistently uses `CachedNetworkImageProvider`.

**Fix**:

```dart
backgroundImage: photoURL != null
    ? CachedNetworkImageProvider(photoURL)  // CHANGED from NetworkImage
    : null,
```

`CachedNetworkImage` is already imported in this file.

---

### 8. LOW — Timestamps may display UTC instead of local time

**File**: `chat_screen.dart` (line 1329-1330) and throughout `media_bubble.dart`

**Problem**: Message timestamps display `message.createdAt!.hour` directly. If the backend returns UTC timestamps (with `Z` suffix), `DateTime.parse` creates a UTC DateTime, and the displayed time is wrong for non-UTC timezones.

**Fix**: Convert to local time with a UTC-safety check:

Create a helper (in a utils file or at the top of chat_screen.dart):

```dart
String formatMessageTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.isUtc ? dt.toLocal() : dt;
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
```

Replace all inline timestamp formatting in `chat_screen.dart` and `media_bubble.dart` with `formatMessageTime(message.createdAt)`.

The `isUtc` check prevents double-conversion if the backend ever changes to send local timestamps.

---

### 9. LOW — Download Dio instance has no timeouts

**File**: `media_bubble.dart` (line 16)

**Problem**: A package-level `final _dio = Dio();` is used for file downloads from Cloudinary. It has no timeout configuration, so a stalled download hangs indefinitely.

**Note**: This is intentionally a separate Dio instance from ApiClient — Cloudinary downloads don't need auth headers, and ApiClient's interceptors (401 retry, request body logging) would be harmful for binary file downloads. Keeping it separate is correct.

**Fix**: Just add timeouts:

```dart
final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(minutes: 5),  // Large files need time
));
```

---

## What I reviewed and confirmed is correct (no changes needed)

- **Scroll direction for loading older messages**: In a reversed ListView, `maxScrollExtent` is at the top (oldest). The `pixels >= maxScrollExtent - 50` check correctly triggers `loadOlder()` when scrolling up. Verified — no fix needed.
- **Optimistic message sending**: Temp ID → replace on REST response → deduplicate against WS echo. Correct.
- **WS self-message suppression**: `_handleNewMessage` checks `senderId == currentUserId`. Correct.
- **Swipe-to-reply (non-audio)**: `Dismissible` with `confirmDismiss` returning false. Clean pattern.
- **Context menu**: Full-screen overlay with scale animation, emoji reactions. Well-implemented.
- **Auto-scroll on new message**: Only scrolls if near bottom (pixels <= 150). Shows badge if scrolled up. Correct.
- **Mark-as-read on open**: `currentOpenRoomProvider` + `markAsRead()` + `clearUnreadCount()`. Correct.
- **Room-not-found fallback**: Triggers `backgroundRefresh` if room missing. Correct.
- **Audio controller singleton**: Pauses other audio when new one plays. Correct.
- **Recording bar**: Timer display, cancel/send, file size validation. Clean.
- **Message editing flow**: Sets content in text field, tracks editing state, sends via REST. Correct.
- **Media upload optimistic flow**: Local preview → Cloudinary upload → replace with URL. Correct.

---

## Verification Checklist

After applying all fixes:

- [ ] Other user force-closes app while typing → "typing..." clears within 5 seconds
- [ ] Send a text message → feel light haptic tap
- [ ] Send a photo/video/file/GIF → feel light haptic tap
- [ ] Upload fails (airplane mode mid-upload) → error snackbar: "Failed to send photo: ..."
- [ ] Upload fails → feel heavy haptic buzz
- [ ] Deleted messages show dark-themed bubble (not light gray)
- [ ] Swipe left/right on audio message → reply mode activates
- [ ] Chat avatar in app bar loads from cache (no flash on re-enter)
- [ ] Timestamps show correct local time (not UTC) — test with phone set to non-UTC timezone
- [ ] Large file download doesn't hang indefinitely (timeout after 5 min)
- [ ] Navigate to chat → scroll up → older messages load correctly
