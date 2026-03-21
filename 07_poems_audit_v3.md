# Poems Feature Audit v3 — Deep Fix Pass

> **Scope**: Editor, detail screen, feed cards, grid cards, publish bottom sheet, recording UI
> **Files**: `poetry_editor_screen.dart`, `poem_detail_screen.dart`, `poem_card.dart`, `poem_grid_card.dart`, `publish_bottom_sheet.dart`, feed controllers
> **Supersedes**: `07_poems_audit_v2.md` for issues 1-4 and recording UI

---

## Summary

13 issues found across the poems feature. The 4 reported bugs plus 9 discovered during deep analysis. Most critical: detail screen doesn't update after editing (data flow gap), audio playback requires navigating to detail (missing inline player), recording UI crashes/doesn't match theme, and save button shows spinner when bottom sheet is open.

---

## Fix 1 — CRITICAL: Draft shows loading spinner on Publish button

**File**: `poetry_editor_screen.dart`, `_onSave()` method

**Problem**: `_isSaving` is set to `true` at line 302 before `showPublishBottomSheet` is awaited. While the bottom sheet is open (user is picking hashtags, recording audio, etc.), the app bar shows a spinner instead of the Save button. The bottom sheet has its own `_isSubmitting` state — the editor's `_isSaving` is redundant and confusing.

**Fix**: Remove the `_isSaving` flag from the save flow entirely. The bottom sheet handles its own loading state:

```dart
Future<void> _onSave() async {
    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim();

    if (plainText.isEmpty) {
      AppSnackbar.show(context, message: 'Write something first', type: SnackbarType.error);
      return;
    }

    // No _isSaving needed — bottom sheet handles its own loading
    final result = await showPublishBottomSheet(
      context: context,
      ref: ref,
      title: title.isEmpty ? 'Untitled Poem' : title,
      contentJson: contentJson,
      plainText: plainText,
      coverColor: _currentPoem?.coverColor ?? '',
      existingPoemId: widget.poemId,
      existingPoem: _currentPoem,
    );

    if (result != null && mounted) {
      setState(() {
        _currentPoem = result;
        _titleController.text = result.title;
      });
      context.pop(result);  // Pop WITH result so detail screen receives it
    }
}
```

Also update the app bar Save button to always show text (remove the `_isSaving` ternary):

```dart
// Replace lines 478-500 with just the TextButton:
Padding(
  padding: const EdgeInsets.only(right: 8),
  child: TextButton.icon(
    onPressed: _onSave,
    icon: const Icon(Icons.save_outlined),
    label: const Text('Save'),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
  ),
),
```

---

## Fix 2 — CRITICAL: Poem detail screen doesn't update after editing

**File**: `poem_detail_screen.dart`

**Problem**: The edit button does `context.push('/editor', extra: poem)`. When the editor pops, the detail screen still shows the old `widget.poem`. The editor now pops with the updated `PoemModel` (Fix 1), but the detail screen doesn't receive it.

**Root cause**: `widget.poem` is immutable. The detail screen never refreshes.

**Fix**: Add mutable state and handle the editor result.

Step 1 — Add `_poem` state:

```dart
class _PoemDetailScreenState extends ConsumerState<PoemDetailScreen> {
  late PoemModel _poem;  // ADD — mutable copy
  late QuillController _quillController;
  // ... rest of existing fields ...

  @override
  void initState() {
    super.initState();
    _poem = widget.poem;  // Initialize from widget
    _isLiked = _poem.isLikedByMe;
    _likeCount = _poem.likesCount;
    _isReposted = _poem.isRepostedByMe;
    _repostCount = _poem.repostsCount;
    _commentCount = _poem.commentsCount;

    _socialSub = ref.read(socialEventStreamProvider).stream.listen((event) {
      if (event.poemId == _poem.id && mounted) {  // Use _poem.id
        // ... existing listener unchanged ...
      }
    });

    try {
      final doc = Document.fromJson(jsonDecode(_poem.contentJson) as List);  // Use _poem
      _quillController = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0), readOnly: true);
    } catch (_) {
      _quillController = QuillController.basic();
    }
  }
```

Step 2 — Update the edit button to await the result:

```dart
if (ref.watch(authControllerProvider).valueOrNull?.id == _poem.author.id)
  IconButton(
    icon: const Icon(Icons.edit_outlined),
    onPressed: () async {
      final updatedPoem = await context.push<PoemModel>('/editor', extra: _poem);
      if (updatedPoem != null && mounted) {
        setState(() {
          _poem = updatedPoem;
          // Re-init Quill controller with updated content
          _quillController.dispose();
          try {
            final doc = Document.fromJson(jsonDecode(_poem.contentJson) as List);
            _quillController = QuillController(
              document: doc,
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: true,
            );
          } catch (_) {
            _quillController = QuillController.basic();
          }
        });
      }
    },
  ),
```

Step 3 — Replace ALL `widget.poem` references in the `build()` method with `_poem`. Also in `_toggleAudio`, `_toggleLike`, `_toggleRepost`.

---

## Fix 3 — HIGH: Audio playback in feed card requires navigating to detail

**File**: `poem_card.dart`

**Problem**: The audio bar navigates to the detail screen. Users expect to tap play and hear audio inline.

**Fix**: Add inline `AudioPlayer` to `_PoemCardState`:

```dart
// Add to state fields:
AudioPlayer? _audioPlayer;
bool _isPlayingAudio = false;
bool _isLoadingAudio = false;
StreamSubscription? _audioStateSub;

// Update dispose:
@override
void dispose() {
    _socialSub?.cancel();
    _audioStateSub?.cancel();
    _audioPlayer?.dispose();
    _quillController.dispose();
    super.dispose();
}

// Stop audio when card is deactivated (scrolled off screen):
@override
void deactivate() {
    if (_isPlayingAudio) {
      _audioPlayer?.stop();
      _isPlayingAudio = false;
    }
    super.deactivate();
}

// Toggle method:
Future<void> _toggleAudio() async {
    if (_isLoadingAudio) return;

    if (_isPlayingAudio) {
      await _audioPlayer?.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }

    _audioPlayer ??= AudioPlayer();
    setState(() => _isLoadingAudio = true);

    try {
      await _audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(widget.poem.audioUrl)));
      await _audioPlayer!.play();
      if (mounted) setState(() { _isPlayingAudio = true; _isLoadingAudio = false; });

      _audioStateSub?.cancel();
      _audioStateSub = _audioPlayer!.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _isPlayingAudio = false);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
}
```

Replace the audio bar UI (lines 448-503):

```dart
if (widget.poem.hasAudio) ...[
  SizedBox(height: 12.h),
  GestureDetector(
    onTap: _toggleAudio,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: _isPlayingAudio
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : AppTheme.featureBackgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _isPlayingAudio
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.r, height: 36.r,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: _isLoadingAudio
                ? Padding(
                    padding: EdgeInsets.all(8.r),
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : Icon(
                    _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 22.r, color: AppTheme.primaryColor,
                  ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPlayingAudio ? 'Playing...' : 'Listen to this poem',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500,
                      color: AppTheme.textDarkColor),
                ),
                if (widget.poem.audioDuration > 0)
                  Text(
                    '${widget.poem.audioDuration ~/ 60}:${(widget.poem.audioDuration % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                  ),
              ],
            ),
          ),
          Icon(Icons.headphones_rounded, size: 18.r, color: AppTheme.textLightColor),
        ],
      ),
    ),
  ),
],
```

Also stop audio before navigating to detail (main card tap):

```dart
// Line 226-228:
onTap: widget.onTap ?? () {
    _audioPlayer?.stop();
    if (_isPlayingAudio) setState(() => _isPlayingAudio = false);
    context.push('/poem/${widget.poem.id}', extra: widget.poem);
},
```

Add `import 'package:just_audio/just_audio.dart';` to poem_card.dart.

---

## Fix 4 — HIGH: Recording UI doesn't match app theme

**File**: `publish_bottom_sheet.dart`, recording case (line 828-950)

**Problem**: Uses raw `Colors.red.withOpacity(0.08)` which clashes with dark navy theme. Buttons are cramped.

**Fix**: Replace the recording state with a centered, clean design:

```dart
case AudioState.recording:
  content = Container(
    width: double.infinity,
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: AppTheme.featureBackgroundColor,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: AppTheme.borderColor),
    ),
    child: Column(
      children: [
        // Timer display with pulsing dot
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Container(
                width: 12.r, height: 12.r,
                decoration: BoxDecoration(
                  color: (_isRecordingPaused ? Colors.orange : Colors.red)
                      .withValues(alpha: _isRecordingPaused ? 0.5 : _pulseAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              _formatDuration(_recordingSeconds),
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w300,
                color: AppTheme.textDarkColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          _isRecordingPaused ? 'Paused' : 'Recording...',
          style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
        ),
        SizedBox(height: 16.h),
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cancel
            TextButton(
              onPressed: _cancelRecording,
              child: Text('Cancel',
                  style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor)),
            ),
            // Pause/Resume
            Container(
              width: 48.r, height: 48.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor, width: 1.5),
              ),
              child: IconButton(
                onPressed: _isRecordingPaused ? _resumeRecording : _pauseRecording,
                icon: Icon(
                  _isRecordingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppTheme.primaryColor, size: 24.r,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            // Stop/Done
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 48.r, height: 48.r,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stop_rounded, color: Colors.white, size: 24.r),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  break;
```

---

## Fix 5 — HIGH: Feed controllers missing `updatePoemInFeed`

**File**: `publish_bottom_sheet.dart` line 403-407, feed controllers

**Problem**: On update, only `myPoemsControllerProvider` gets the updated poem. Feed controllers (home, explore, audio) still show stale data.

**Fix**: Add to the update branch in `_submit`:

```dart
if (widget.existingPoemId != null) {
    poem = await ref.read(poemRepoProvider).updatePoem(widget.existingPoemId!, request);
    ref.read(myPoemsControllerProvider.notifier).updatePoem(poem);
    // ADD — sync to all feeds:
    try { ref.read(homeFeedControllerProvider.notifier).updatePoemInFeed(poem); } catch (_) {}
    try { ref.read(exploreFeedControllerProvider.notifier).updatePoemInFeed(poem); } catch (_) {}
    try { ref.read(audioFeedControllerProvider.notifier).updatePoemInFeed(poem); } catch (_) {}
}
```

Add `updatePoemInFeed` to each feed controller:

```dart
void updatePoemInFeed(PoemModel updatedPoem) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.map((p) => p.id == updatedPoem.id ? updatedPoem : p).toList(),
    );
}
```

---

## Fix 6 — MEDIUM: `_toggleAudio` in poem_detail_screen leaks subscriptions

**File**: `poem_detail_screen.dart`, lines 86-104

**Problem**: Every call to `_toggleAudio` creates a new `.listen()` on `playerStateStream` without cancelling the previous one. After play/stop/play, orphaned listeners accumulate.

**Fix**:

```dart
// Add to state:
StreamSubscription? _audioStateSub;

// In dispose, add:
_audioStateSub?.cancel();

// In _toggleAudio, replace lines 97-101:
_audioStateSub?.cancel();
_audioStateSub = _audioPlayer.playerStateStream.listen((s) {
    if (s.processingState == ProcessingState.completed) {
      if (mounted) setState(() => _isPlayingAudio = false);
    }
});
```

---

## Fix 7 — MEDIUM: Preview playback double-tap in bottom sheet

**File**: `publish_bottom_sheet.dart`

**Problem**: The `_isLoadingAudio` guard exists but the UI doesn't show a loading indicator. User taps play, sees no feedback, taps again (stops it).

**Fix**: In both the `recorded` and `uploaded` states, show a spinner during loading:

```dart
// Replace the play IconButton in both states:
IconButton(
  onPressed: _togglePreviewPlayback,
  icon: _isLoadingAudio
      ? SizedBox(
          width: 24.r, height: 24.r,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
        )
      : Icon(
          _isPlayingPreview
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_filled_rounded,
          size: 36.r, color: AppTheme.primaryColor,
        ),
  padding: EdgeInsets.zero,
),
```

---

## Fix 8 — MEDIUM: Audio bar in poem_grid_card navigates redundantly

**File**: `poem_grid_card.dart`, lines 330-386

**Problem**: Audio bar has its own GestureDetector that navigates to detail. But the entire grid card should already navigate on tap. The audio bar's play icon misleads users into thinking they can play inline.

**Fix**: Remove the GestureDetector, show as indicator only:

```dart
if (widget.poem.hasAudio) ...[
  Padding(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.featureBackgroundColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.headphones_rounded, size: 14.r, color: AppTheme.primaryColor),
          SizedBox(width: 6.w),
          Text('Audio', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
          const Spacer(),
          if (widget.poem.audioDuration > 0)
            Text(
              '${widget.poem.audioDuration ~/ 60}:${(widget.poem.audioDuration % 60).toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10.sp, color: AppTheme.textLightColor),
            ),
        ],
      ),
    ),
  ),
],
```

---

## Fix 9 — MEDIUM: `didUpdateWidget` doesn't sync all poem fields

**File**: `poem_card.dart`, lines 88-126

**Problem**: Only social counts and contentJson trigger updates. Title, hashtags, audio, mood changes are ignored.

**Fix**: Add audio cleanup when poem ID changes:

```dart
// Add at the end of didUpdateWidget, inside the id/contentJson check:
if (oldWidget.poem.id != widget.poem.id) {
    _audioPlayer?.stop();
    _isPlayingAudio = false;
    _isLoadingAudio = false;
}
```

The title, hashtags, and audio URL are read directly from `widget.poem` in the build method, so they update automatically when the widget rebuilds. The only fields that need manual sync are the ones stored in local state (social counts + Quill controller + audio player state).

---

## Fix 10 — MEDIUM: poem_card stops audio when card navigates to detail

Already covered in Fix 3 — stop `_audioPlayer` before `context.push` in the main card tap handler.

---

## Fix 11 — LOW: poem_grid_card missing top-level GestureDetector

**File**: `poem_grid_card.dart`, line 199

**Problem**: The grid card's `build()` returns a `Container` without a tap handler. Verify a `GestureDetector` or `InkWell` wraps it. If not, tapping the card does nothing — only the stat buttons and audio bar are tappable.

**Fix**: Wrap the outer Container:

```dart
@override
Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/poem/${widget.poem.id}', extra: widget.poem),
      child: Container(
        // ... existing card content ...
      ),
    );
}
```

---

## Fix 12 — LOW: `_hasEdits` undo/redo gating is wrong

**File**: `poetry_editor_screen.dart`, lines 458-475

**Problem**: Undo/Redo buttons are disabled when `_hasEdits` is false. But `_hasEdits` is set to true on ANY document change and never reset. So after the first keystroke, undo/redo are always enabled even when there's nothing to undo/redo.

**Fix**: Use Quill's built-in undo/redo availability instead of `_hasEdits`:

```dart
// Undo
IconButton(
  icon: Icon(Icons.undo,
      color: _quillController.hasUndo
          ? null
          : Theme.of(context).iconTheme.color?.withValues(alpha: 0.3)),
  tooltip: 'Undo',
  onPressed: _quillController.hasUndo ? () {
    HapticFeedback.lightImpact();
    _quillController.undo();
  } : null,
),

// Redo
IconButton(
  icon: Icon(Icons.redo,
      color: _quillController.hasRedo
          ? null
          : Theme.of(context).iconTheme.color?.withValues(alpha: 0.3)),
  tooltip: 'Redo',
  onPressed: _quillController.hasRedo ? () {
    HapticFeedback.lightImpact();
    _quillController.redo();
  } : null,
),
```

Note: Check if `QuillController` has `hasUndo`/`hasRedo` getters in your version. If not, keep `_hasEdits` but it's less precise.

---

## Fix 13 — LOW: GoRouter may need route config change for pop-with-result

For `context.pop(result)` to work with GoRouter, the editor route must return the result to the caller. Verify your GoRouter config allows this. With `context.push<PoemModel>('/editor', extra: poem)`, the return type is inferred. When the editor does `context.pop(result)`, GoRouter passes it back to the awaiting `push`. This works with standard GoRouter — no config change needed. But verify the editor route doesn't use `redirect` which could swallow the result.

---

## Verification Checklist

- [ ] Open editor for new poem → Save button shows "Save" text (no spinner)
- [ ] Open existing poem (draft) → Save button shows "Save" text (no spinner)
- [ ] Bottom sheet opens → Publish button shows "Publish" (its own loading)
- [ ] Edit poem from detail → update → pop back → detail screen shows updated title/content/audio
- [ ] Edit poem → update → go to home feed → feed shows updated poem without pull-to-refresh
- [ ] Feed card with audio → tap play → audio plays inline (spinner during load)
- [ ] Feed card playing audio → scroll away → audio stops
- [ ] Feed card playing audio → tap card body → audio stops, navigates to detail
- [ ] Grid card audio bar shows headphone icon + "Audio" (no play button)
- [ ] Recording UI: centered timer, pulsing dot, Pause/Stop circular buttons
- [ ] Recording UI: matches dark navy theme (no jarring red background)
- [ ] Preview playback: single tap plays (loading spinner shown during buffering)
- [ ] Detail screen: play/stop audio multiple times → no console errors (subscription leak)
- [ ] Undo button disabled when nothing to undo (not just always enabled after first edit)
