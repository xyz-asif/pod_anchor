# Prompt: Add Media Message Support to Flutter Chat Client

## Context

This is a Flutter chat app using Riverpod (with code generation), GoRouter, and a Go/Fiber backend with WebSocket support. The architecture follows: `screens` → `controllers (Riverpod notifiers)` → `repos` → `ApiClient`. Real-time events flow through `WebSocketService` → `WsEventHandler` → Controllers.

**The backend already supports media messages.** It accepts a message payload with `type`, `content` (URL), and optional `metadata`. Media files are uploaded directly to Cloudinary from the Flutter client using an unsigned upload preset. The backend never touches media files — it only stores the URL and broadcasts the message.

**Cloudinary is already configured** with an unsigned upload preset ready to use.

---

## Existing Codebase Reference

Read these carefully to understand existing patterns before making changes.

### File: `features/chat/models/message_response.dart`

Current model — **missing `type` and `metadata` fields**:

```dart
@JsonSerializable()
class MessageResponse {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String status;
  final Map<String, String> reactions;
  final ReplyTo? replyTo;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // ... copyWith, fromJson, toJson
}
```

### File: `features/chat/models/reply_to.dart`

Current model — **missing `type` and `metadata` fields**:

```dart
@JsonSerializable()
class ReplyTo {
  final String id;
  final String senderId;
  final String content;
  final String? status;
  final DateTime? createdAt;
}
```

### File: `features/chat/models/room_response.dart`

Current model — **missing `lastMessageType` field**:

```dart
@JsonSerializable()
class RoomResponse {
  final String id;
  final String type;
  final String? name;
  final List<ParticipantInfo> participants;
  final String? lastMessage;
  final String? lastMessageSenderName;
  final int unreadCount;
  final DateTime? lastUpdated;
  // ... copyWith, fromJson, toJson
}
```

### File: `features/chat/repos/chat_repo.dart`

Current `sendMessage` — **only sends `content` and optional `replyToId`**:

```dart
Future<MessageResponse> sendMessage({
  required String roomId,
  required String content,
  String? replyToId,
}) async {
  final data = <String, dynamic>{'content': content};
  if (replyToId != null) data['replyToId'] = replyToId;

  final response = await apiClient.post(
    ApiEndpoints.chatRoomMessages(roomId),
    data: data,
  );
  return MessageResponse.fromJson(response.data);
}
```

### File: `features/chat/controllers/message_controller.dart`

Current `sendMessage` — **only handles text, creates optimistic text message**:

```dart
Future<void> sendMessage(String content, {String? replyToId}) async {
  final current = state.valueOrNull ?? [];
  final currentUserId = ref.read(authControllerProvider).valueOrNull?.id ?? '';

  final optimistic = MessageResponse(
    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
    roomId: roomId,
    senderId: currentUserId,
    content: content,
    status: 'sent',
    createdAt: DateTime.now(),
  );
  state = AsyncValue.data([...current, optimistic]);

  try {
    final sent = await ref.read(chatRepoProvider).sendMessage(
      roomId: roomId, content: content, replyToId: replyToId,
    );
    // ... replace optimistic, deduplicate
  } catch (e) {
    // ... remove optimistic on failure
  }
}
```

### File: `features/chat/controllers/chat_list_controller.dart`

- `handleRoomUpdated` — receives `lastMessage` string from WS but **does not handle `lastMessageType`**
- `moveRoomToTop` — updates `lastMessage` but **no type awareness**
- `updateLastMessage` — sets `lastMessage` to raw content string

### File: `features/chat/controllers/ws_event_handler.dart`

- `_handleNewMessage` — parses `MessageResponse.fromJson(event.payload)` and calls `appendMessage`. Also updates chat list with `message.content` directly.
- `_handleRoomUpdated` — reads `lastMessage` from payload but **not `lastMessageType`**

### File: `features/chat/screens/chat_screen.dart`

- `_MessageBubble` — renders `message.content` as plain `Text` widget. **No media rendering.**
- Input bar — only has a `TextField` and send button. **No attachment button, no media picker.**
- `_showActionMenu` — shows reply/edit/delete. Edit option should be **hidden for media messages**.
- Reply preview — shows `message.replyTo!.content` as text. **Needs media-aware preview.**

### File: `features/chat/screens/chat_list_screen.dart`

- Subtitle shows `room.lastMessage ?? 'No messages yet'` as plain text. **Already works** because backend sends preview strings like "📷 Photo", but `lastMessageType` could be used for richer rendering later.

---

## Requirements

### 1. New Model: `MediaMetadata`

Create `features/chat/models/media_metadata.dart`:

```dart
@JsonSerializable()
class MediaMetadata {
  final String? mimeType;
  final String? fileName;
  final int? fileSize;
  final String? thumbnailURL;
  final int? duration;      // seconds, for audio/video
  final int? width;
  final int? height;
}
```

Include `fromJson`, `toJson`, `copyWith`. All fields nullable with sensible defaults.

### 2. New Enum: `MessageType`

Create `features/chat/models/message_type.dart`:

```dart
enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  gif,
  link;

  static MessageType fromString(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value?.toLowerCase(),
      orElse: () => MessageType.text,
    );
  }
}
```

### 3. Update `MessageResponse`

Add these fields:

```dart
final String type;           // defaults to 'text'
final MediaMetadata? metadata;
```

- Add `type` param to constructor with default `'text'`
- Add `metadata` param as nullable
- Update `copyWith` to include both
- Add helper: `MessageType get messageType => MessageType.fromString(type);`
- Add helper: `bool get isMedia => messageType != MessageType.text;`

### 4. Update `ReplyTo`

Add these fields:

```dart
final String? type;          // nullable for backward compat
final MediaMetadata? metadata;
```

- Add helper: `MessageType get messageType => MessageType.fromString(type);`
- Add helper: `bool get isMedia => messageType != MessageType.text;`

### 5. Update `RoomResponse`

Add:

```dart
final String? lastMessageType;
```

Update `copyWith` to include it.

### 6. New Service: `CloudinaryService`

Create `core/services/cloudinary_service.dart`:

This service handles direct upload to Cloudinary using the unsigned upload preset. **Do NOT use any Cloudinary SDK** — use plain HTTP multipart upload via `dio` or `http` package.

```dart
class CloudinaryService {
  static const String _cloudName = 'YOUR_CLOUD_NAME';  // TODO: move to env
  static const String _uploadPreset = 'YOUR_PRESET';   // TODO: move to env

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  /// Upload a file to Cloudinary.
  /// Returns the secure_url on success.
  /// [filePath] — local file path
  /// [resourceType] — 'image', 'video', or 'raw' (for files)
  /// [folder] — Cloudinary folder (default: 'chat_media')
  Future<CloudinaryUploadResult> upload({
    required String filePath,
    String folder = 'chat_media',
    void Function(int sent, int total)? onProgress,
  }) async {
    // Use Dio for multipart upload with progress tracking
    // POST to _uploadUrl with:
    //   - file: MultipartFile
    //   - upload_preset: _uploadPreset
    //   - folder: folder
    // Parse response for: secure_url, resource_type, format, bytes, width, height, duration
  }
}
```

Create a result model:

```dart
class CloudinaryUploadResult {
  final String secureUrl;
  final String? resourceType;   // image, video, raw
  final String? format;         // jpg, mp4, pdf, etc.
  final int? bytes;
  final int? width;
  final int? height;
  final double? duration;       // seconds
  final String? originalFilename;
}
```

Create a Riverpod provider for it.

### 7. New Service: `MediaPickerService`

Create `core/services/media_picker_service.dart`:

Wraps platform media pickers into a clean interface. Uses:
- `image_picker` package — for camera and gallery images/videos
- `file_picker` package — for documents (PDF, etc.)
- `record` package (or `flutter_sound`) — for voice recording

```dart
class MediaPickerService {
  /// Pick image from gallery or camera.
  /// Returns file path or null if cancelled.
  Future<PickedMedia?> pickImage({required ImageSource source});

  /// Pick video from gallery or camera.
  Future<PickedMedia?> pickVideo({required ImageSource source});

  /// Pick a file (PDF, doc, etc.)
  Future<PickedMedia?> pickFile();

  /// Start voice recording. Returns a controller to stop/cancel.
  Future<VoiceRecordingSession> startVoiceRecording();

  /// Search and pick a GIF from Giphy.
  /// Uses the Giphy API to search/trending, returns the selected GIF URL.
  /// Returns a PickedMedia with the Giphy URL as filePath (no Cloudinary upload needed).
  Future<PickedMedia?> pickGif();
}

class PickedMedia {
  final String filePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final int? width;         // for images/videos
  final int? height;
  final double? duration;   // for videos
}

class VoiceRecordingSession {
  /// Stop recording and return the file path.
  Future<PickedMedia?> stop();
  /// Cancel recording and discard file.
  Future<void> cancel();
  /// Stream of recording duration for UI timer.
  Stream<Duration> get durationStream;
}
```

Create a Riverpod provider for it.

### 8. Update `ChatRepo.sendMessage`

Update the signature and body to pass media fields:

```dart
Future<MessageResponse> sendMessage({
  required String roomId,
  required String content,
  String type = 'text',
  MediaMetadata? metadata,
  String? replyToId,
}) async {
  final data = <String, dynamic>{
    'content': content,
    'type': type,
  };
  if (metadata != null) data['metadata'] = metadata.toJson();
  if (replyToId != null) data['replyToId'] = replyToId;

  final response = await apiClient.post(
    ApiEndpoints.chatRoomMessages(roomId),
    data: data,
  );
  return MessageResponse.fromJson(response.data);
}
```

### 9. Update `MessageController`

Add a `sendMediaMessage` method:

```dart
/// Send a media message.
/// 1. Show optimistic placeholder with loading state
/// 2. Upload to Cloudinary
/// 3. Send URL to backend
/// 4. Replace optimistic with server response
Future<void> sendMediaMessage({
  required String filePath,
  required String fileName,
  required MessageType messageType,
  MediaMetadata? previewMetadata,  // for optimistic UI (dimensions, etc.)
  String? replyToId,
}) async {
  final currentUserId = ref.read(authControllerProvider).valueOrNull?.id ?? '';
  final current = state.valueOrNull ?? [];

  // Step 1: Optimistic placeholder (show local file path as content for preview)
  final optimistic = MessageResponse(
    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
    roomId: roomId,
    senderId: currentUserId,
    type: messageType.name,
    content: filePath,  // local path for optimistic preview
    metadata: previewMetadata,
    status: 'uploading',  // custom status for upload progress UI
    createdAt: DateTime.now(),
  );
  state = AsyncValue.data([...current, optimistic]);

  try {
    // Step 2: Upload to Cloudinary
    final uploadResult = await ref.read(cloudinaryServiceProvider).upload(
      filePath: filePath,
      onProgress: (sent, total) {
        // Optional: update upload progress on the optimistic message
      },
    );

    // Step 3: Build metadata from upload result + preview info
    final metadata = MediaMetadata(
      mimeType: previewMetadata?.mimeType,
      fileName: fileName,
      fileSize: uploadResult.bytes,
      width: uploadResult.width ?? previewMetadata?.width,
      height: uploadResult.height ?? previewMetadata?.height,
      duration: uploadResult.duration?.toInt(),
      thumbnailURL: messageType == MessageType.video
          ? _buildVideoThumbnailUrl(uploadResult.secureUrl)
          : null,
    );

    // Step 4: Send to backend
    final sent = await ref.read(chatRepoProvider).sendMessage(
      roomId: roomId,
      content: uploadResult.secureUrl,
      type: messageType.name,
      metadata: metadata,
      replyToId: replyToId,
    );

    // Step 5: Replace optimistic
    final updated = state.valueOrNull ?? [];
    final swapped = updated.map((m) => m.id == optimistic.id ? sent : m).toList();
    final seen = <String>{};
    state = AsyncValue.data(swapped.where((m) => seen.add(m.id)).toList());

    // Update chat list
    final preview = _getMessagePreview(messageType, fileName);
    ref.read(chatListControllerProvider.notifier)
        .updateLastMessage(roomId, lastMessage: preview);
  } catch (e) {
    // Remove optimistic on failure
    final updated = state.valueOrNull ?? [];
    state = AsyncValue.data(
      updated.where((m) => m.id != optimistic.id).toList(),
    );
    rethrow;
  }
}

String _getMessagePreview(MessageType type, String fileName) {
  switch (type) {
    case MessageType.image: return '📷 Photo';
    case MessageType.video: return '🎥 Video';
    case MessageType.audio: return '🎵 Audio';
    case MessageType.file:  return '📎 $fileName';
    case MessageType.gif:   return 'GIF';
    case MessageType.link:  return '🔗 Link';
    default: return 'Message';
  }
}
```

Update existing `sendMessage` to include `type: 'text'` in the repo call.

### 10. Update `WsEventHandler`

**`_handleNewMessage`:** Update the chat list preview to use the message type, not raw content:

```dart
void _handleNewMessage(Ref ref, WsEvent event) {
  final message = MessageResponse.fromJson(event.payload);
  // ... existing sender check ...

  // Update chat list with type-aware preview
  final preview = message.isMedia
      ? _getPreviewForType(message.messageType)
      : message.content;
  ref.read(chatListControllerProvider.notifier)
      .moveRoomToTop(event.roomId, lastMessage: preview);
}
```

**`_handleRoomUpdated`:** Read `lastMessageType` from payload (already a preview string from backend, so no change needed here — the backend sends "📷 Photo" as `lastMessage`).

### 11. Update `ChatScreen` — Input Bar

Add an attachment button to the left of the text field. When tapped, show a bottom sheet with options:

```
┌─────────────────────────────┐
│  📷 Camera                  │
│  🖼️ Gallery                 │
│  🎥 Video                   │
│  🎤 Voice Message           │
│  📎 File                    │
│  GIF                        │
└─────────────────────────────┘
```

Each option:
1. Opens the appropriate picker via `MediaPickerService`
2. If a file is selected, calls `messageController.sendMediaMessage(...)`
3. Shows upload progress on the optimistic message bubble

**GIF flow is different** — GIFs are NOT uploaded to Cloudinary. The GIF option opens a GIF picker screen/sheet that:
1. Shows trending GIFs from Giphy API on load
2. Has a search bar to search Giphy
3. Uses the Giphy API: `https://api.giphy.com/v1/gifs/trending?api_key=YOUR_KEY&limit=25` and `https://api.giphy.com/v1/gifs/search?api_key=YOUR_KEY&q=QUERY&limit=25`
4. Displays results in a grid (use `CachedNetworkImage` for previews)
5. On tap, sends the GIF URL directly to the backend (no Cloudinary upload) — the `content` field is the Giphy URL (e.g., `https://media.giphy.com/media/abc123/giphy.gif`)
6. The Giphy API key should come from environment config, not hardcoded

Create a dedicated widget for this: `features/chat/screens/widgets/gif_picker_sheet.dart`

Voice recording should show an inline recording UI replacing the text input bar (with a timer, cancel button, and stop/send button).

### 12. Update `ChatScreen` — `_MessageBubble`

The message bubble must render differently based on `message.messageType`:

**Text** (existing behavior): Show `message.content` as `Text`.

**Image**: 
- Show the image using `CachedNetworkImage` with the URL from `message.content`
- Constrain to max width 220.w, maintain aspect ratio from metadata
- Show rounded corners matching the bubble
- Tap to open full-screen viewer
- While uploading (content is local path), show `Image.file` with an upload overlay

**Video**:
- Show a thumbnail (from `metadata.thumbnailURL` or generate from Cloudinary URL transformation)
- Overlay a play button icon
- Show duration badge from `metadata.duration`
- Tap to open video player (use `video_player` or `chewie`)

**Audio / Voice**:
- Show a waveform-style bar or simple play/pause button with duration
- Use `just_audio` or `audioplayers` for playback
- Show duration from `metadata.duration`

**File**:
- Show an icon based on file extension (PDF icon, doc icon, etc.)
- Show `metadata.fileName` and formatted `metadata.fileSize`
- Tap to download/open via `url_launcher` or `open_filex`

**GIF**:
- Show using `CachedNetworkImage` (GIFs auto-animate)
- Similar layout to image but no full-screen viewer needed
- No upload progress needed (GIFs are sent directly, not uploaded to Cloudinary)
- Slightly different bubble style — no background color, just the GIF with rounded corners

### 13. Update `ChatScreen` — `_showActionMenu`

- **Hide "Edit" option** for media messages (`message.isMedia`)
- Reply to media messages should work — the reply preview shows a media-aware preview (icon + type label instead of raw URL)

### 14. Update `ChatScreen` — Reply Preview

When replying to a media message, show a type-aware preview instead of the URL:

```dart
// In reply preview bar and in-bubble reply preview:
if (replyTo.isMedia) {
  // Show icon + label: "📷 Photo", "🎥 Video", etc.
} else {
  // Show text content (existing behavior)
}
```

### 15. Update `ChatListController`

No major changes needed — the backend already sends preview strings like "📷 Photo" as `lastMessage`. But update `handleRoomUpdated` to also store `lastMessageType` if you want richer rendering later.

---

## Packages to Add

Add these to `pubspec.yaml`:

```yaml
dependencies:
  image_picker: ^1.1.2        # Camera & gallery
  file_picker: ^8.0.0          # Document picker
  record: ^5.1.0               # Voice recording
  cached_network_image: ^3.3.1 # Image caching (may already exist)
  just_audio: ^0.9.37          # Audio playback
  video_player: ^2.8.6         # Video playback
  chewie: ^1.8.1               # Video player UI wrapper
  open_filex: ^4.4.0           # Open downloaded files
  path_provider: ^2.1.3        # Temp directory for recordings
  mime: ^1.0.5                 # MIME type detection
  dio: ^5.4.3+1                # HTTP client (may already exist, used for Cloudinary upload + Giphy API)
```

Do NOT add `cloudinary_sdk` or any Cloudinary Flutter package. Use plain Dio multipart upload.
Do NOT add a Giphy SDK package. Use plain HTTP calls to the Giphy API via Dio.

---

## Backend API Contract

The backend `POST /api/v1/chat/rooms/:roomId/messages` expects:

```json
{
  "type": "image",
  "content": "https://res.cloudinary.com/.../photo.jpg",
  "metadata": {
    "mimeType": "image/jpeg",
    "fileName": "photo.jpg",
    "fileSize": 245000,
    "width": 1080,
    "height": 720,
    "thumbnailURL": "https://res.cloudinary.com/.../thumb.jpg"
  },
  "replyToId": "optional_message_id"
}
```

For text messages, either omit `type` (defaults to "text") or send `"type": "text"`.

The backend responds with the full `MessageResponse` including `type` and `metadata`.

WebSocket broadcasts include `type` and `metadata` in the message payload.

The `room_updated` WebSocket event includes `lastMessageType` in the payload.

---

## What NOT to Change

- **websocket_service.dart** — No changes needed. WS events already flow through.
- **api_endpoints.dart** — No new endpoints needed.
- **app_router.dart** — No new routes needed (full-screen image viewer can be a dialog/overlay, not a route).
- **participant_info.dart** — No changes.
- **presence_model.dart** — No changes.

---

## File Summary

| Action | File |
|--------|------|
| **Create** | `features/chat/models/media_metadata.dart` |
| **Create** | `features/chat/models/message_type.dart` |
| **Create** | `core/services/cloudinary_service.dart` |
| **Create** | `core/services/media_picker_service.dart` |
| **Create** | `features/chat/screens/widgets/media_bubble.dart` (image/video/audio/file renderers) |
| **Create** | `features/chat/screens/widgets/attachment_picker.dart` (bottom sheet) |
| **Create** | `features/chat/screens/widgets/gif_picker_sheet.dart` (Giphy search + trending grid) |
| **Create** | `features/chat/screens/widgets/voice_recorder_bar.dart` (inline recording UI) |
| **Create** | `features/chat/screens/widgets/full_screen_image_viewer.dart` |
| **Update** | `features/chat/models/message_response.dart` — add `type`, `metadata` |
| **Update** | `features/chat/models/reply_to.dart` — add `type`, `metadata` |
| **Update** | `features/chat/models/room_response.dart` — add `lastMessageType` |
| **Update** | `features/chat/repos/chat_repo.dart` — update `sendMessage` signature |
| **Update** | `features/chat/controllers/message_controller.dart` — add `sendMediaMessage` |
| **Update** | `features/chat/controllers/ws_event_handler.dart` — media-aware previews |
| **Update** | `features/chat/controllers/chat_list_controller.dart` — optional `lastMessageType` |
| **Update** | `features/chat/screens/chat_screen.dart` — attachment button, media bubbles, reply preview |
| **Regenerate** | Run `dart run build_runner build` after model changes |

---

## CRITICAL: Staged Implementation

**Do NOT implement everything at once.** This is a large feature. Implement it in the stages below. Complete each stage fully (compiles, runs, testable) before moving to the next. Wait for my confirmation before proceeding to the next stage.

### Stage 1: Models & Data Layer

**Goal:** All models updated, repo updated, build_runner passes. No UI changes yet.

Files to create/update:
- Create `features/chat/models/media_metadata.dart` — `MediaMetadata` with `@JsonSerializable()`
- Create `features/chat/models/message_type.dart` — `MessageType` enum
- Update `features/chat/models/message_response.dart` — add `type`, `metadata` fields + helpers
- Update `features/chat/models/reply_to.dart` — add `type`, `metadata` fields + helpers
- Update `features/chat/models/room_response.dart` — add `lastMessageType` field
- Update `features/chat/repos/chat_repo.dart` — update `sendMessage` signature to accept `type`, `metadata`
- Run `dart run build_runner build --delete-conflicting-outputs`

**Verification:** App compiles and runs. Existing text messaging still works. New fields are silently ignored by the UI.

---

### Stage 2: Cloudinary Upload Service

**Goal:** Can upload a file to Cloudinary and get back a URL. No UI yet.

Files to create:
- Create `core/services/cloudinary_service.dart` — `CloudinaryService` + `CloudinaryUploadResult` + Riverpod provider
  - Multipart upload via Dio to `https://api.cloudinary.com/v1_1/{cloud_name}/auto/upload`
  - Progress callback support
  - Parse response for `secure_url`, `width`, `height`, `bytes`, `duration`, `format`, `original_filename`

**Verification:** Can be tested by calling the service from a temporary button. Upload succeeds, URL is returned.

---

### Stage 3: Media Picker Service

**Goal:** Can pick images, videos, files from the device. No sending yet.

Files to create:
- Create `core/services/media_picker_service.dart` — `MediaPickerService` + `PickedMedia` + Riverpod provider
  - `pickImage(source)` — via `image_picker`
  - `pickVideo(source)` — via `image_picker`
  - `pickFile()` — via `file_picker`

**Do NOT implement voice recording or GIF picker in this stage.** Those come later.

**Verification:** Each picker opens, returns file info, cancellation works.

---

### Stage 4: Send Image & File Messages (End-to-End)

**Goal:** User can pick an image or file, it uploads to Cloudinary, message appears in chat.

Files to update:
- Update `features/chat/controllers/message_controller.dart` — add `sendMediaMessage` method
- Update `features/chat/screens/chat_screen.dart`:
  - Add attachment button (📎) to the left of the text input
  - Create `features/chat/screens/widgets/attachment_picker.dart` — bottom sheet with Camera, Gallery, Video, File options (no Voice or GIF yet)
  - Wire picker → `sendMediaMessage`
- Update `features/chat/controllers/ws_event_handler.dart` — handle media message types in `_handleNewMessage` (use preview text instead of raw URL for chat list)

**Verification:** Pick image → upload → message appears with URL. Other user receives it via WebSocket. Chat list shows "📷 Photo" not the URL.

---

### Stage 5: Media Bubble Rendering

**Goal:** Media messages display properly in the chat instead of showing raw URLs.

Files to create:
- Create `features/chat/screens/widgets/media_bubble.dart`:
  - `ImageBubble` — `CachedNetworkImage`, tap for full-screen, upload overlay for optimistic messages
  - `VideoBubble` — thumbnail + play icon + duration badge
  - `FileBubble` — file icon + name + size, tap to open
  - `AudioBubble` — placeholder for now (will be functional in Stage 7)
  - `GifBubble` — placeholder for now (will be functional in Stage 6)
- Create `features/chat/screens/widgets/full_screen_image_viewer.dart` — dismissible full-screen image
- Update `features/chat/screens/chat_screen.dart`:
  - `_MessageBubble` — check `message.messageType` and render the appropriate bubble widget
  - Hide "Edit" in `_showActionMenu` for media messages
  - Update reply preview to show type-aware label for media replies (e.g., "📷 Photo" instead of URL)
  - Update in-bubble reply preview similarly

**Verification:** Image messages show as images. Files show as file cards. Video shows thumbnail. Replies to media show proper preview.

---

### Stage 6: GIF Picker & Sending

**Goal:** User can search and send GIFs from Giphy.

Files to create:
- Create `features/chat/screens/widgets/gif_picker_sheet.dart`:
  - Bottom sheet with search bar + grid of GIFs
  - Loads trending GIFs on open via Giphy API
  - Search queries the Giphy search API
  - Grid uses `CachedNetworkImage` for GIF previews
  - Tap sends the GIF URL directly to backend (NO Cloudinary upload — GIFs go straight from Giphy URL to backend)
- Update `features/chat/screens/widgets/attachment_picker.dart` — add "GIF" option
- Update `features/chat/screens/widgets/media_bubble.dart` — make `GifBubble` functional (auto-playing GIF via `CachedNetworkImage`, no background, rounded corners)

**Verification:** GIF picker opens, search works, selecting a GIF sends it instantly. GIF displays animated in the chat.

---

### Stage 7: Voice Messages

**Goal:** User can record and send voice messages.

Files to create/update:
- Update `core/services/media_picker_service.dart` — add `startVoiceRecording()`, `VoiceRecordingSession` class
- Create `features/chat/screens/widgets/voice_recorder_bar.dart` — inline recording UI that replaces the text input bar:
  - Shows recording timer
  - Cancel button (swipe left or tap X)
  - Stop/send button
  - Uses `record` package
- Update `features/chat/screens/widgets/media_bubble.dart` — make `AudioBubble` functional:
  - Play/pause button + seek bar + duration display
  - Uses `just_audio` for playback
- Update `features/chat/screens/chat_screen.dart` — add microphone button (appears when text field is empty, replacing send button), toggle to recording UI
- Update `features/chat/screens/widgets/attachment_picker.dart` — add "🎤 Voice Message" option as alternative entry point

**Verification:** Hold/tap mic → recording starts with timer → stop → uploads → audio message appears. Tap play on received audio → plays back.

---

### Stage 8: Video Player & File Opener

**Goal:** Video and file messages are fully interactive.

Files to create/update:
- Create `features/chat/screens/widgets/video_player_screen.dart` — full-screen video player using `chewie` + `video_player`
- Update `features/chat/screens/widgets/media_bubble.dart`:
  - `VideoBubble` — tap opens video player screen
  - `FileBubble` — tap downloads and opens file via `open_filex` or `url_launcher`

**Verification:** Tap video → plays in full-screen. Tap file → opens in external app.

---

## Security Notes

- Cloudinary upload preset must be **unsigned** (no API secret on client)
- Never expose Cloudinary API secret in Flutter code
- The `_cloudName` and `_uploadPreset` should come from environment config, not hardcoded
- Validate file sizes on the client before uploading (e.g., max 25MB for images, 100MB for videos)
- The backend validates URLs are from whitelisted domains (`res.cloudinary.com`, `*.giphy.com`)
