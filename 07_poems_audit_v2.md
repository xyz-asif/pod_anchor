# Poems Feature Audit v2 — ChatBee Flutter App

> **Scope**: Poetry editor (create/edit), floating toolbar, color picker, publish bottom sheet (including recording), poem detail screen (like propagation), my poems list, poem controller
> **Files**: `poetry_editor_screen.dart`, `floating_toolbar.dart`, `color_picker_dialog.dart`, `publish_bottom_sheet.dart`, `poem_detail_screen.dart`, `my_poems_screen.dart`, `poem_controller.dart`, `poem_repo.dart`
> **Bugs reported**: (1) Unlike on detail → go back → feed still shows liked. (2) Apply color to selected text → continue typing → color follows.

---

## Summary

16 issues found. The most impactful: unlike on detail not propagating back to feed (the reported bug), text color formatting leaking to subsequent typing, no unsaved changes guard on editor back button, missing pause/resume during recording, editor performance with large documents, and no network failure recovery in the publish flow.

---

## Fixes

---

### 1. CRITICAL — Unlike on detail screen doesn't propagate back to feed

**File**: `poem_detail_screen.dart`

**Bug**: Like poem in feed → open detail → unlike → go back → feed still shows liked.

**Root cause**: `_toggleLike` in detail screen updates local state but never broadcasts. The feed card has its own separate `_isLiked`.

**Fix**: Requires `socialEventStreamProvider` from Feed & Social audit v2 (fix #2). Add broadcasting to the detail screen:

```dart
Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    final originalCount = _likeCount;

    HapticFeedback.lightImpact();
    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await ref.read(socialRepoProvider).togglePoemLike(widget.poem.id);
      if (mounted) setState(() {
        _isLiked = result.liked;
        _likeCount = result.likesCount;
      });
      // Broadcast change — feed cards and controllers will pick this up
      ref.read(socialEventStreamProvider).emit(SocialEvent(
          poemId: widget.poem.id,
          isLiked: result.liked,
          likesCount: result.likesCount,
      ));
    } catch (_) {
      if (mounted) setState(() {
        _isLiked = wasLiked;
        _likeCount = originalCount;
      });
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
}
```

Apply same to `_toggleRepost`. Also add stream listener in `initState` so detail receives events from other screens (see Feed audit v2 fix #2 for the pattern).

**Note on feed controller updates**: Rather than manually calling each controller from here, have the feed controllers self-subscribe to the `socialEventStream` in their `build()` method. This inverts the dependency — the detail screen just emits, it doesn't need to know which controllers exist:

```dart
// In HomeFeedController.build(), ExploreFeedController.build(), AudioFeedController.build():
@override
FutureOr<List<PoemModel>> build() async {
    // Subscribe to social events to keep feed data in sync
    ref.listen(socialEventStreamProvider, (_, bus) {
      // The stream is a bus — but for Riverpod, we just react to state changes
    });
    // Alternatively, use ref.onDispose to manage stream subscription
    final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
      _handleSocialEvent(event);
    });
    ref.onDispose(() => sub.cancel());

    // ... existing fetch code ...
}

void _handleSocialEvent(SocialEvent event) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.map((p) {
      if (p.id == event.poemId) {
        return p.copyWith(
          isLikedByMe: event.isLiked ?? p.isLikedByMe,
          likesCount: event.likesCount ?? p.likesCount,
          isRepostedByMe: event.isReposted ?? p.isRepostedByMe,
          repostsCount: event.repostsCount ?? p.repostsCount,
          commentsCount: event.commentsCount ?? p.commentsCount,
        );
      }
      return p;
    }).toList());
}
```

This way: detail screen emits event → all feed controllers auto-update → recycled cards get correct data. No tight coupling.

---

### 2. CRITICAL — Text color continues to new text after formatting selection

**File**: `floating_toolbar.dart` → `_showTextColorPicker`

**Bug**: Select "hello" → apply red → cursor at end → type " world" → " world" is also red.

**Root cause**: Quill sets color as an active format. After selection collapses, new text inherits it.

**Fix**: After applying color, collapse selection to end and explicitly clear the active color:

```dart
void _showTextColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _getTextColor(),
        onColorSelected: (color) {
          final selection = controller.selection;
          if (color == Colors.transparent) {
            controller.formatSelection(Attribute.clone(Attribute.color, null));
          } else {
            final hex = '#${color.value.toRadixString(16).substring(2)}';
            controller.formatSelection(ColorAttribute(hex));
          }

          // Clear active color so subsequent typing uses default
          if (!selection.isCollapsed) {
            controller.updateSelection(
              TextSelection.collapsed(offset: selection.end),
              ChangeSource.local,
            );
            controller.formatSelection(Attribute.clone(Attribute.color, null));
          }
        },
      ),
    );
}
```

Apply the same to `_showHighlightColorPicker` (replace `Attribute.color` with `Attribute.background`).

Bold/italic/underline are left "sticky" — that's standard text editor behavior.

---

### 3. HIGH — No unsaved changes guard on back button

**File**: `poetry_editor_screen.dart`

**Problem**: Back button calls `context.pop()` directly. User loses entire poem.

**Fix**: Add `PopScope` with change detection. Compare delta JSON (not plain text — plain text ignores formatting changes):

```dart
bool get _hasUnsavedChanges {
    final currentDelta = jsonEncode(_quillController.document.toDelta().toJson());
    final currentTitle = _titleController.text.trim();

    if (_currentPoem == null) {
      // New poem — any content is unsaved
      return _quillController.document.toPlainText().trim().isNotEmpty ||
             currentTitle.isNotEmpty;
    }

    // Existing poem — compare JSON delta and title
    return currentDelta != _currentPoem!.contentJson ||
           currentTitle != _currentPoem!.title.trim();
}

Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Unsaved changes',
            style: TextStyle(color: AppTheme.textDarkColor, fontWeight: FontWeight.w600)),
        content: Text('You have unsaved changes. What would you like to do?',
            style: TextStyle(color: AppTheme.textMediumColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: Text('Keep editing', style: TextStyle(color: AppTheme.primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Discard', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    return result == 'discard';
}

// Wrap Scaffold:
@override
Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) context.pop();
      },
      child: Scaffold(/* ... existing ... */),
    );
}

// Also update back button:
leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios),
    onPressed: () async {
      final shouldPop = await _onWillPop();
      if (shouldPop && mounted) context.pop();
    },
),
```

---

### 4. HIGH — Missing pause/resume during audio recording

**File**: `publish_bottom_sheet.dart`

**Problem**: The recording UI has Cancel and Stop buttons, but no Pause/Resume. For poetry, users may want to pause, gather thoughts, then continue recording. Without pause, they must record in one take or start over.

**Fix**: Add pause/resume support. The `record` package supports `pause()` and `resume()`:

```dart
// Add state tracking:
bool _isRecordingPaused = false;

Future<void> _pauseRecording() async {
    await _recorder.pause();
    _recordingTimer?.cancel();
    setState(() => _isRecordingPaused = true);
}

Future<void> _resumeRecording() async {
    await _recorder.resume();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
    setState(() => _isRecordingPaused = false);
}
```

Update the recording UI (`AudioState.recording` case) to include a Pause/Resume button:

```dart
case AudioState.recording:
  content = Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: Colors.red.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        // Pulsing dot (only when not paused)
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, __) => Opacity(
            opacity: _isRecordingPaused ? 0.4 : _pulseAnimation.value,
            child: Container(
              width: 10.r, height: 10.r,
              decoration: BoxDecoration(
                color: _isRecordingPaused ? Colors.orange : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          _isRecordingPaused ? 'PAUSED' : 'REC',
          style: TextStyle(
            fontSize: 11.sp, fontWeight: FontWeight.w700,
            color: _isRecordingPaused ? Colors.orange : Colors.red,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          _formatDuration(_recordingSeconds),
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor),
        ),
        const Spacer(),
        // Pause / Resume
        IconButton(
          onPressed: _isRecordingPaused ? _resumeRecording : _pauseRecording,
          icon: Icon(
            _isRecordingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: AppTheme.primaryColor,
            size: 24.r,
          ),
          tooltip: _isRecordingPaused ? 'Resume' : 'Pause',
        ),
        // Cancel
        TextButton(
          onPressed: _cancelRecording,
          child: Text('Cancel', style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor)),
        ),
        SizedBox(width: 4.w),
        // Stop (finish recording)
        ElevatedButton(
          onPressed: _stopRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
          child: Text('Done', style: TextStyle(fontSize: 13.sp, color: Colors.white)),
        ),
      ],
    ),
  );
  break;
```

Also reset `_isRecordingPaused` in `_cancelRecording` and `_stopRecording`.

---

### 5. HIGH — Editor performance with large documents

**File**: `poetry_editor_screen.dart`

**Problem**: `_updateCounts()` is called on every single document change (every keystroke). It calls `toPlainText()`, splits by whitespace, splits by newlines — all synchronous. For a large poem (500+ lines), this causes jank.

**Fix**: Debounce the word count update:

```dart
Timer? _countDebounce;

// In initState, replace direct listener:
_documentChangesSub = _quillController.document.changes.listen((_) {
    _countDebounce?.cancel();
    _countDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _updateCounts();
    });
});

// In dispose:
_countDebounce?.cancel();
```

This ensures word count updates at most every 300ms during rapid typing, not on every character.

---

### 6. HIGH — Audio player stream subscription leak in editor

**File**: `poetry_editor_screen.dart` (lines 149, 76)

**Problem**: `_toggleExistingAudioPlayback` creates a new `playerStateStream.listen()` every play tap without cancelling the previous one. `_quillController.document.changes.listen()` is never stored or cancelled.

**Fix**: Store and cancel subscriptions:

```dart
StreamSubscription? _audioPlayerSub;
StreamSubscription? _documentChangesSub;

// In _toggleExistingAudioPlayback:
_audioPlayerSub?.cancel();
_audioPlayerSub = _audioPlayer.playerStateStream.listen((s) { ... });

// In dispose:
_documentChangesSub?.cancel();
_audioPlayerSub?.cancel();
_countDebounce?.cancel();
```

Same fix for `publish_bottom_sheet.dart` → `_togglePreviewPlayback` (line 311).

---

### 7. HIGH — No network failure recovery in publish flow

**File**: `publish_bottom_sheet.dart` → `_submit`

**Problem**: If the network fails during publish (after the user has filled in all metadata, recorded audio, etc.), the error shows a snackbar but the bottom sheet stays open. If the user dismisses the sheet accidentally, they lose all the metadata and audio recording.

**Fix**: (A) Don't close the sheet on error (already correct). (B) Add a retry mechanism. (C) Warn before dismiss when there's a pending submission:

```dart
// Wrap the bottom sheet's DraggableScrollableSheet:
PopScope(
  canPop: !_isSubmitting,
  onPopInvokedWithResult: (didPop, _) async {
    if (didPop) return;
    if (_isSubmitting) {
      AppSnackbar.show(context, message: 'Please wait...', type: SnackbarType.error);
    }
  },
  child: DraggableScrollableSheet(/* ... existing ... */),
)
```

For audio upload failure, the existing code already falls back to `AudioState.recorded` so the user can retry. This is correct.

---

### 8. MEDIUM — No loading indicator on Save button

**File**: `poetry_editor_screen.dart`

**Problem**: Save button has no loading state. User can tap multiple times.

**Fix**:

```dart
bool _isSaving = false;

Future<void> _onSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    // ... existing validation and sheet code ...
    final result = await showPublishBottomSheet(...);
    if (mounted) setState(() => _isSaving = false);
    if (result != null && mounted) {
      setState(() {
        _currentPoem = result;
        _titleController.text = result.title;
      });
      context.pop();
    }
}

// In app bar, replace Save button:
_isSaving
    ? Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
      )
    : TextButton.icon(
        onPressed: _onSave,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save'),
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
      ),
```

---

### 9. MEDIUM — New poem creation doesn't appear in feeds

**File**: `publish_bottom_sheet.dart` → `_submit`

**Problem**: After creating a poem, `prependPoem` adds it to `myPoemsControllerProvider`. But the home feed and explore feed don't show it until manual refresh.

**Fix**: Prepend to feed controllers directly (not `refresh()`, which resets scroll position):

```dart
// After the create branch in _submit:
if (widget.existingPoemId != null) {
    poem = await ref.read(poemRepoProvider).updatePoem(widget.existingPoemId!, request);
    ref.read(myPoemsControllerProvider.notifier).updatePoem(poem);
} else {
    poem = await ref.read(poemRepoProvider).createPoem(request);
    ref.read(myPoemsControllerProvider.notifier).prependPoem(poem);
    // Prepend to feeds (no full refresh — preserves scroll)
    try { ref.read(homeFeedControllerProvider.notifier).prependPoem(poem); } catch (_) {}
    try { ref.read(exploreFeedControllerProvider.notifier).prependPoem(poem); } catch (_) {}
}
```

Add `prependPoem` to `HomeFeedController` and `ExploreFeedController`:

```dart
void prependPoem(PoemModel poem) {
    final current = state.valueOrNull ?? [];
    if (current.any((p) => p.id == poem.id)) return; // Dedup
    state = AsyncValue.data([poem, ...current]);
}
```

---

### 10. MEDIUM — Delete dialog doesn't match app theme

**Files**: `poetry_editor_screen.dart`, `my_poems_screen.dart`

**Fix**: Add `backgroundColor: AppTheme.surfaceColor`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))`, theme-appropriate text colors, and `HapticFeedback.heavyImpact()` on the delete confirmation tap. Apply to both files.

---

### 11. MEDIUM — Editor undo/redo buttons always look active

**File**: `poetry_editor_screen.dart`

**Fix**: Dim when unavailable. Note: verify your `flutter_quill` version supports `hasUndo`/`hasRedo`. If not available, track manually by listening to document changes:

```dart
// Simple approach: track if document has been modified
bool _hasEdits = false;

// In document changes listener:
if (mounted) setState(() => _hasEdits = true);

// After undo:
// There's no reliable way to know undo availability without version check.
// At minimum, dim redo after fresh undo, and dim undo when _hasEdits is false.
```

---

### 12. MEDIUM — Floating toolbar hardcoded at `top: 200`

**File**: `poetry_editor_screen.dart`

**Problem**: On different screen sizes, the toolbar may overlap text or be far from the selection.

**Fix**: Position below app bar area. Note: proper cursor-relative positioning requires access to Quill's cursor coordinates, which isn't trivially exposed. The pragmatic fix:

```dart
Positioned(
  top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
  left: 16, right: 16,
  child: Center(child: /* ... existing FloatingToolbar ... */),
),
```

---

### 13. MEDIUM — Font size menu position hardcoded

**File**: `floating_toolbar.dart`

**Fix**: Use `Builder` to get the button's context for positioning. However, since `FloatingToolbar` is a `StatelessWidget` and the font size button is inline, the simplest fix is to use the screen center which works across device sizes. A proper anchored menu would require refactoring to `StatefulWidget` with `GlobalKey` on the button.

---

### 14. LOW — `coverColor` reset to empty on edit

**File**: `poetry_editor_screen.dart` (line 242)

**Fix**: Preserve existing color:

```dart
coverColor: _currentPoem?.coverColor ?? '',
```

---

### 15. LOW — Duplicate `@override` annotation

**File**: `publish_bottom_sheet.dart` (lines 405-406)

**Fix**: Remove duplicate `@override`.

---

### 16. LOW — Timer fix in `_onSelectionChanged`

**File**: `poetry_editor_screen.dart`

**Fix**: Move `_toolbarHideTimer?.cancel()` to the top of the method (before the if/else) to ensure it's always cancelled:

```dart
void _onSelectionChanged() {
    final selection = _quillController.selection;
    _toolbarHideTimer?.cancel();  // Always cancel first
    if (selection.isValid && !selection.isCollapsed && !_isPreviewMode) {
      setState(() => _showToolbar = true);
      _toolbarHideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showToolbar = false);
      });
    } else {
      setState(() => _showToolbar = false);
    }
}
```

---

## Recording UI Review (Publish Bottom Sheet)

Reviewed all 5 audio states in `_buildAudioSection()`:

- **idle**: Record + Upload buttons. ✅ Correct.
- **recording**: Pulsing red dot, timer, Cancel + Stop. ✅ But **missing Pause/Resume** (fix #4).
- **recorded**: Play preview, duration, Remove button. ✅ Correct.
- **uploading**: Spinner with "Uploading audio..." text. ✅ Correct.
- **uploaded**: Green checkmark, play preview, Remove button. ✅ Correct.

Editor screen existing audio: Play toggle, "Voice recording attached" label, duration, Remove button. ✅ Correct.

---

## What I reviewed and confirmed is correct (no changes needed)

- **Quill initialization from existing poem**: Try/catch fallback. Correct.
- **Title field typography**: Playfair Display, centered, italic hint. Good for poetry.
- **Preview mode toggle**: Correctly toggles readOnly. Correct.
- **Publish bottom sheet metadata**: Hashtag chips (max 10), mood selection, original toggle, visibility. All correct.
- **Audio upload to Cloudinary**: Record → stop → upload path. Correct.
- **Audio removal on existing poem**: PATCH with empty audioUrl. Correct.
- **MyPoemsController**: Cursor pagination, prepend/update/remove. Clean.
- **My poems list**: Pull-to-refresh, infinite scroll, edit on tap, delete via popup menu. Correct.
- **Hashtag pre-fill on edit**: Correctly splits static vs custom tags. Correct.

---

## Verification Checklist

- [ ] Like in feed → open detail → unlike → go back → feed shows unliked
- [ ] Select text → apply red color → type after → new text is DEFAULT color
- [ ] Select text → apply highlight → type after → no highlight on new text
- [ ] Type in editor → press back → "unsaved changes" dialog appears
- [ ] Tap Record → see Pause button → tap Pause → timer stops, dot turns orange → tap Resume → continues
- [ ] Tap Cancel during recording → returns to idle state
- [ ] Tap Done → see recorded state with Play and Remove
- [ ] Large poem (500+ lines) → typing doesn't lag (debounced word count)
- [ ] Publish fails (airplane mode) → sheet stays open, can retry
- [ ] Create poem → home feed shows it at top without manual refresh
- [ ] Delete dialog has dark theme styling
- [ ] Undo button dimmed on fresh editor
- [ ] No `@override` duplication in publish_bottom_sheet.dart
- [ ] Edit existing poem → coverColor preserved
