# Flutter Media Messages — Code Review & Fixes

## Bugs & Issues

### Bug 1: `sendMessage` chat list preview still shows raw URL for non-text messages

**File:** `message_controller.dart` → `sendMessage()`  
**Line:** After the `sendMessage` repo call succeeds, around the `updateLastMessage` call.

**Problem:** When `sendMessage` is used to send a GIF (or any non-text type), the chat list preview shows the raw Giphy URL instead of "GIF". The code does:

```dart
ref.read(chatListControllerProvider.notifier)
    .updateLastMessage(roomId, lastMessage: content);
```

But `content` is the Giphy URL for GIF messages.

**Fix:**

```dart
final preview = type == MessageType.text
    ? content
    : type.previewText(metadata?.fileName);
ref.read(chatListControllerProvider.notifier)
    .updateLastMessage(roomId, lastMessage: preview);
```

---

### Bug 2: `_AudioBubble` eagerly loads audio on init — kills performance

**File:** `media_bubble.dart` → `_AudioBubbleState.initState()`

**Problem:** Every audio message in the chat list calls `_player.setUrl(pathOrUrl)` or `_player.setFilePath(pathOrUrl)` immediately when the widget is built. In a chat with 20 audio messages, that's 20 simultaneous network requests + 20 AudioPlayer instances.

**Fix:** Lazy-load audio. Don't call `setUrl`/`setFilePath` in `initState`. Instead, load it on first play tap:

```dart
bool _isLoaded = false;

Future<void> _loadAndPlay() async {
  if (!_isLoaded) {
    final isLocal = widget.message.status == 'uploading' &&
        !widget.message.content.startsWith('http');
    if (isLocal) {
      await _player.setFilePath(widget.message.content);
    } else {
      await _player.setUrl(widget.message.content);
    }
    _isLoaded = true;
  }
  _player.play();
}
```

Then in the play button `onPressed`, call `_loadAndPlay()` instead of `_player.play()`.

Keep the stream listeners in `initState` — they're fine since they only fire once audio is loaded.

---

### Bug 3: `_AudioBubble` AudioPlayer is never disposed when scrolled off screen

**File:** `media_bubble.dart` → `_AudioBubbleState`

**Problem:** `_AudioBubble` is a `StatefulWidget` inside a `ListView.builder`. When scrolled off screen, the widget is disposed, but `_player.dispose()` only stops playback — it doesn't release the native audio session reliably on all platforms. With many audio messages, this causes resource leaks.

**Fix (in addition to Bug 2 lazy loading):** Also stop playback before dispose:

```dart
@override
void dispose() {
  _player.stop();
  _player.dispose();
  super.dispose();
}
```

And consider using a singleton/pooled audio player approach — only one audio message should play at a time across the entire chat. This is a UX improvement too: tapping play on message B should stop message A.

---

### Bug 4: `_FileBubble` creates a new `Dio()` instance every download

**File:** `media_bubble.dart` → `_FileBubbleState._handleTap()`

**Problem:** `final dio = Dio();` creates a fresh Dio instance per download. This bypasses your app's existing `ApiClient` and any interceptors (auth, logging, etc.), and wastes resources.

**Fix:** Either inject Dio from a provider, or since this is a public Cloudinary URL (no auth needed), at minimum reuse a static instance:

```dart
static final _dio = Dio();
```

---

### Bug 5: `_FileBubble` file name collision in temp directory

**File:** `media_bubble.dart` → `_FileBubbleState._handleTap()`

**Problem:** Downloads save to `${dir.path}/$fileName`. If two different files have the same name (e.g., two "report.pdf" files from different senders), the second download skips because `file.exists()` returns true from the first download's cached file.

**Fix:** Include the message ID in the save path:

```dart
final savePath = '${dir.path}/${widget.message.id}_$fileName';
```

---

### Bug 6: `_ImageBubble` Hero tag collision

**File:** `media_bubble.dart` → `_ImageBubble`

**Problem:** `Hero(tag: message.content)` uses the URL as the tag. If the same image URL appears twice in the chat (e.g., forwarded, or same image sent again), Flutter throws a "duplicate Hero tag" error.

**Fix:** Use message ID instead:

```dart
Hero(tag: 'image_${message.id}',
```

And match it in `FullScreenImageViewer`.

---

### Bug 7: Image bubble always renders as square 220x220

**File:** `media_bubble.dart` → `_ImageBubble`

**Problem:** Both `width: 220.w` and `height: 220.w` are hardcoded, making every image a square regardless of aspect ratio. Portrait photos get cropped badly with `BoxFit.cover`.

**Fix:** Use metadata dimensions to calculate aspect ratio, with constraints:

```dart
double _calculateHeight() {
  final meta = message.metadata;
  if (meta?.width != null && meta?.height != null && meta!.width! > 0) {
    final ratio = meta.height! / meta.width!;
    return (220.w * ratio).clamp(100.h, 300.h);
  }
  return 220.w; // fallback square
}
```

Then use `height: _calculateHeight()` instead of `height: 220.w`.

---

### Bug 8: Voice recording sends even with 0 duration

**File:** `chat_screen.dart` → `_stopRecording()`

**Problem:** The check is `if (path != null && duration > 0)`, but the `AudioRecorderService.stopRecording()` calculates duration using `DateTime.now().difference(_startTime!)`. If the user taps stop within the same second they started, `duration` could be 0 and the message won't send. More importantly, accidental quick taps aren't filtered — a 1-second recording is probably not intentional.

**Fix:** Set a minimum duration threshold (e.g., 1 second):

```dart
if (path != null && duration >= 1) {
```

This is already correct in the code — just flagging that 1 second might still be too short. Consider 2 seconds as the minimum for a meaningful voice message.

---

## Performance & Smoothness

### Perf 1: GIF picker loads all trending GIFs at once

**File:** `gif_picker_sheet.dart`

**Problem:** `getTrending()` loads all GIFs in one batch. For Giphy's default limit of 25, this is fine. But if the limit is increased, or if search returns many results, the grid loads everything at once.

**Suggestion:** The current implementation is fine for now. But if you want infinite scroll later, add pagination with Giphy's `offset` parameter.

---

### Perf 2: `_buildTextBar` calls `setState` on every keystroke for mic/send toggle

**File:** `chat_screen.dart` → `_buildTextBar()` and `onChanged`

**Problem:** The `onChanged` callback calls `setState` when `val.trim().length <= 1` to toggle between mic and send icons. This rebuilds the entire `ChatScreen` widget on every keystroke near the empty/non-empty boundary.

**Suggestion:** Extract the input bar into a separate `StatefulWidget` so `setState` only rebuilds the input bar, not the entire message list. Alternatively, use a `ValueListenableBuilder` on the `TextEditingController`:

```dart
ValueListenableBuilder<TextEditingValue>(
  valueListenable: _messageController,
  builder: (context, value, _) {
    final hasText = value.text.trim().isNotEmpty;
    // build mic/send button based on hasText
  },
)
```

---

### Perf 3: Video thumbnail Cloudinary URL transformation is fragile

**File:** `media_bubble.dart` → `_VideoBubble._buildThumbnail()`

**Problem:** The regex replacement `replaceAll('/video/upload/', '/video/upload/so_auto,...')` assumes a specific Cloudinary URL structure. If the URL has transformations already applied, or the folder path differs, this breaks silently and falls back to a black rectangle.

**Suggestion:** Generate the thumbnail URL on the backend during `SendMessage` and store it in `metadata.thumbnailURL`. The Go service already has access to the Cloudinary URL structure. This also avoids an extra Cloudinary transformation request from the client.

---

### Perf 4: `CachedNetworkImage` in GIF grid doesn't set `memCacheWidth`

**File:** `gif_picker_sheet.dart` → `_buildGrid()`

**Problem:** Each GIF in the grid is loaded at full resolution. For a 2-column grid with small tiles, this wastes memory significantly — a 480px GIF displayed in a ~180px tile still decodes the full 480px into memory.

**Suggestion:** Add `memCacheWidth` to constrain decoded size:

```dart
CachedNetworkImage(
  imageUrl: gif.url,
  memCacheWidth: 400, // roughly 2x the display width for retina
  ...
)
```

---

### Perf 5: No file size validation before Cloudinary upload

**File:** `message_controller.dart` → `sendMediaMessage()`

**Problem:** There's no client-side check on file size before uploading. A user could try to send a 500MB video, which would fail on Cloudinary (or take forever), but only after the optimistic message is already shown and the user is waiting.

**Suggestion:** Add size limits in `sendMediaMessage` before the upload step:

```dart
const maxImageSize = 25 * 1024 * 1024;   // 25MB
const maxVideoSize = 100 * 1024 * 1024;  // 100MB
const maxFileSize = 50 * 1024 * 1024;    // 50MB

if (fileSize != null) {
  final limit = switch (messageType) {
    MessageType.image => maxImageSize,
    MessageType.video => maxVideoSize,
    _ => maxFileSize,
  };
  if (fileSize > limit) {
    throw Exception('File too large. Max size: ${limit ~/ (1024 * 1024)}MB');
  }
}
```

---

### Perf 6: Recording timer causes full screen rebuilds

**File:** `chat_screen.dart` → `_startRecording()`

**Problem:** The `_recordTimer` calls `setState(() { _recordDuration++; })` every second. This rebuilds the entire `ChatScreen` including the message list. During recording, this means the entire chat UI rebuilds every second.

**Suggestion:** Same as Perf 2 — extract the recording bar into its own `StatefulWidget` with its own `setState`. The parent only needs to know `_isRecording` (to swap between text bar and recording bar), not the tick count.

---

## Summary

| # | Type | Severity | File | Issue |
|---|------|----------|------|-------|
| 1 | Bug | Medium | message_controller.dart | Chat list shows raw URL for GIF messages |
| 2 | Bug | High | media_bubble.dart | AudioBubble eagerly loads all audio on init |
| 3 | Bug | Medium | media_bubble.dart | AudioPlayer resource leak on scroll |
| 4 | Bug | Low | media_bubble.dart | New Dio() per file download |
| 5 | Bug | Low | media_bubble.dart | File name collision in temp directory |
| 6 | Bug | Medium | media_bubble.dart | Hero tag collision with duplicate images |
| 7 | Bug | Medium | media_bubble.dart | Images always render as square |
| 8 | Bug | Low | chat_screen.dart | 0-1 second voice recordings |
| P1 | Perf | Low | gif_picker_sheet.dart | No pagination (fine for now) |
| P2 | Perf | Medium | chat_screen.dart | Full screen rebuild on input toggle |
| P3 | Perf | Low | media_bubble.dart | Fragile video thumbnail URL transform |
| P4 | Perf | Medium | gif_picker_sheet.dart | GIF grid loads full-res images |
| P5 | Perf | Medium | message_controller.dart | No file size validation before upload |
| P6 | Perf | High | chat_screen.dart | Recording timer rebuilds entire screen every second |
