# Fix: Publish Bottom Sheet + Editor Audio UI
### Files to change: `publish_bottom_sheet.dart`, `poetry_editor_screen.dart`

---

## Issues found and exact fixes required

---

### Issue 1 — Bottom sheet structure is wrong (drag handle scrolls away)

**Current code in `build()`:**
```dart
return DraggableScrollableSheet(
  initialChildSize: 0.85,
  maxChildSize: 0.85,   // ← same as initial = sheet cannot be dragged
  minChildSize: 0.85,   // ← same as initial = sheet cannot be dragged
  builder: (_, scrollController) {
    return Container(
      child: ListView(       // ← entire content including handle is in scrollable list
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          Container(         // ← drag handle scrolls away with content
            margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
            width: 40.w,     // ← width ignored — ListView stretches children full width
            height: 4.h,
            ...
          ),
          ...title, divider, all content...
        ],
      ),
    );
  },
);
```

**Problems:**
1. `maxChildSize: 0.85` and `minChildSize: 0.85` are the same as `initialChildSize: 0.85` — the sheet cannot be dragged at all.
2. The drag handle is inside the `ListView` so it scrolls away when the user scrolls down. In iOS-style sheets the handle is always fixed at the top.
3. The `Container` for the drag handle has `width: 40.w` but `ListView` stretches all children to full width, so the pill shape spans the full screen width instead of being a small centered pill.

**Fix — replace the entire `build()` method with this structure:**

```dart
@override
Widget build(BuildContext context) {
  return DraggableScrollableSheet(
    initialChildSize: 0.85,
    maxChildSize: 0.95,   // allow drag up to near full screen
    minChildSize: 0.5,    // allow drag down to half screen
    expand: false,
    builder: (_, scrollController) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(   // Column, NOT ListView — keeps header fixed
          children: [
            // ── Fixed header (never scrolls) ──
            
            // Drag handle pill — centered, correct width
            Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
              child: Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),

            // Title row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Row(
                children: [
                  Text(
                    widget.existingPoemId != null ? 'Update poem' : 'Publish poem',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDarkColor,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: AppTheme.borderColor),

            // ── Scrollable content ──
            Expanded(
              child: ListView(
                controller: scrollController,   // pass the DraggableScrollableSheet controller here
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                children: [
                  // ── Hashtags ──
                  _SectionLabel('Hashtags'),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: kStaticHashtags.map((tag) {
                      final selected = _selectedHashtags.contains(tag);
                      return FilterChip(
                        label: Text('#$tag'),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              if (_allHashtags.length < 10) _selectedHashtags.add(tag);
                            } else {
                              _selectedHashtags.remove(tag);
                            }
                          });
                        },
                        selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                        checkmarkColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          fontSize: 13.sp,
                          color: selected ? AppTheme.primaryColor : AppTheme.textMediumColor,
                        ),
                        backgroundColor: AppTheme.featureBackgroundColor,
                        side: BorderSide(
                          color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
                        ),
                      );
                    }).toList(),
                  ),

                  if (_customTags.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _customTags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          deleteIcon: Icon(Icons.close, size: 16.r),
                          onDeleted: () => setState(() => _customTags.remove(tag)),
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          labelStyle: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor),
                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                        );
                      }).toList(),
                    ),
                  ],

                  SizedBox(height: 10.h),

                  // Custom hashtag input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customTagController,
                          onSubmitted: (_) => _addCustomTag(),
                          style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
                          decoration: InputDecoration(
                            hintText: 'Add your own tag...',
                            hintStyle: TextStyle(fontSize: 14.sp, color: AppTheme.textLightColor),
                            prefixText: '# ',
                            prefixStyle: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            filled: true,
                            fillColor: AppTheme.featureBackgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppTheme.borderColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppTheme.borderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: _addCustomTag,
                        child: Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8.r)),
                          child: Icon(Icons.add, color: Colors.white, size: 20.r),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // ── Audio Section ──
                  _SectionLabel('Voice / Audio (optional)'),
                  SizedBox(height: 10.h),
                  _buildAudioSection(),

                  SizedBox(height: 24.h),

                  // ── Copyright ──
                  Row(
                    children: [
                      Checkbox(
                        value: _isOriginal,
                        onChanged: (v) => setState(() => _isOriginal = v ?? false),
                        activeColor: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isOriginal = !_isOriginal),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '© ',
                                  style: TextStyle(fontSize: 15.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: 'This is my original work',
                                  style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // ── Action Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : () => _submit('private'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: AppTheme.borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: Text('Save Draft', style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor)),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _submit('public'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: _isSubmitting
                              ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  widget.existingPoemId != null ? 'Update' : 'Publish',
                                  style: TextStyle(fontSize: 15.sp, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom safe area padding so buttons don't sit on home bar
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24.h),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

---

### Issue 2 — Recording state: no pulsing animation, no animated indicator

**Current recording state UI** has a static red dot `BoxShape.circle`. There is no visual feedback that recording is actively happening beyond the timer counting up.

**Fix — add `AnimationController` for a pulsing red dot:**

Add these to the state class fields:
```dart
late AnimationController _pulseController;
late Animation<double> _pulseAnimation;
```

Add this to `initState()`:
```dart
_pulseController = AnimationController(
  vsync: this,   // requires SingleTickerProviderStateMixin — see note below
  duration: const Duration(milliseconds: 800),
)..repeat(reverse: true);

_pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
);
```

Add `SingleTickerProviderStateMixin` to the state class declaration:
```dart
// BEFORE:
class _PublishBottomSheetState extends ConsumerState<PublishBottomSheet> {

// AFTER:
class _PublishBottomSheetState extends ConsumerState<PublishBottomSheet>
    with SingleTickerProviderStateMixin {
```

Add `_pulseController.dispose();` to `dispose()`.

Replace the static red dot in the `AudioState.recording` case inside `_buildAudioSection()` with an animated version:

```dart
// REPLACE THIS:
Container(
  width: 10.r,
  height: 10.r,
  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
),

// WITH THIS:
AnimatedBuilder(
  animation: _pulseAnimation,
  builder: (_, __) => Opacity(
    opacity: _pulseAnimation.value,
    child: Container(
      width: 10.r,
      height: 10.r,
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
    ),
  ),
),
```

Also add `'● REC'` text next to the timer to make it even clearer:
```dart
// After the pulsing dot and SizedBox(width: 10.w), add:
Text(
  'REC  ',
  style: TextStyle(
    fontSize: 11.sp,
    fontWeight: FontWeight.w700,
    color: Colors.red,
    letterSpacing: 1.5,
  ),
),
Text(
  _formatDuration(_recordingSeconds),
  style: TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: AppTheme.textDarkColor,
  ),
),
```

---

### Issue 3 — `_startRecording()` has no error handling — fails silently

**Current code:**
```dart
Future<void> _startRecording() async {
  final hasPermission = await _recorder.hasPermission();
  if (!hasPermission) { ... return; }

  final dir = await getTemporaryDirectory();
  final path = '...';

  await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
  // ← if recorder.start() throws, setState below never runs, UI stays stuck in idle
  setState(() { _audioState = AudioState.recording; ... });
  ...
}
```

**Fix — wrap in try-catch:**
```dart
Future<void> _startRecording() async {
  final hasPermission = await _recorder.hasPermission();
  if (!hasPermission) {
    if (mounted) AppSnackbar.show(context, message: 'Microphone permission denied', type: SnackbarType.error);
    return;
  }

  try {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/poem_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _audioState = AudioState.recording;
      _recordingPath = path;
      _recordingSeconds = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
  } catch (e) {
    if (mounted) {
      AppSnackbar.show(
        context,
        message: 'Could not start recording. Check microphone permissions.',
        type: SnackbarType.error,
      );
    }
  }
}
```

---

### Issue 4 — Edit screen: "Remove" audio button is unstyled and invisible

**File: `poetry_editor_screen.dart`**

**Current code in `_buildExistingAudioPlayer()`:**
```dart
TextButton(
  onPressed: () async { ... },
  child: const Text('Remove'),  // ← no color, invisible in most themes
),
```

**Fix — make it clearly a destructive action:**
```dart
TextButton(
  onPressed: () async { ... },
  style: TextButton.styleFrom(foregroundColor: Colors.red),
  child: const Text(
    'Remove audio',
    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
  ),
),
```

Also add a mic icon before the "Voice recording attached" text to make it more scannable:
```dart
// BEFORE:
Text('Voice recording attached', style: TextStyle(...)),

// AFTER:
Row(
  children: [
    Icon(Icons.mic_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 6),
    Text('Voice recording attached', style: TextStyle(...)),
  ],
),
```

---

### Issue 5 — Section labels need visual separation

**Current `_SectionLabel`** is just grey text with no separator. Sections blend into each other.

**Fix — add an uppercase label style with a bottom border line:**
```dart
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.textLightColor,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Divider(height: 1, color: AppTheme.borderColor),
        ),
      ],
    );
  }
}
```

---

### Summary of all changes

**`publish_bottom_sheet.dart`:**
1. Add `SingleTickerProviderStateMixin` to state class
2. Add `_pulseController` and `_pulseAnimation` fields
3. Initialize pulse animation in `initState()`, dispose in `dispose()`
4. Replace entire `build()` method with the fixed structure — `Column` with fixed header + `Expanded ListView` for scrollable content, `DraggableScrollableSheet` with `minChildSize: 0.5, maxChildSize: 0.95`
5. Drag handle inside a `Center` widget with `Padding`, NOT inside the scrollable list
6. Replace static red dot in recording state with `AnimatedBuilder` pulsing dot
7. Add `'REC'` text label next to timer in recording state
8. Wrap `_startRecording()` in try-catch
9. Replace `_SectionLabel` widget with uppercase + divider line version
10. Add `SizedBox(height: MediaQuery.of(context).padding.bottom + 24.h)` at the end of the ListView children list (before closing bracket)

**`poetry_editor_screen.dart`:**
1. Style the Remove button red with `TextButton.styleFrom(foregroundColor: Colors.red)` and change label to `'Remove audio'`
2. Add mic icon before "Voice recording attached" text

**Do not change any other logic, any method signatures, any state variables, or any other files.**
