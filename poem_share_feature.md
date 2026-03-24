# Feature: Share Poem (Text) + Download Poem Image

## Overview

Two actions triggered from the share icon in PoemCard footer:
- **Tapping the share icon** → shows a bottom sheet with two options: "Share as Text" and "Download Image"
- **Share as Text** → native share sheet with poem content + attribution
- **Download Image** → generates a styled image of the poem preserving all rich text formatting, saves to gallery

## Key Design Decisions

- **Background**: Dark (`Color(0xFF1A1F2E)`) — matches the in-app card background so highlights, colored text, and light-colored words remain visible exactly as styled
- **Rich text preserved**: Poem body is rendered via `QuillEditor.basic` from the stored Quill Delta JSON — bold, italic, underline, strikethrough, text colors, and highlights are all captured in the image as-is
- **Minimum height**: 600px logical — so one-liners don't look tiny
- **Maximum height**: no hard cap — grows with content
- **Fixed width**: 1080px logical (standard share image width, renders sharp on all screens)
- **JosefinSans** font for title and attribution to match in-app style; Quill renders the body with whatever fonts are embedded in the delta
- App name branding in bottom-right corner
- Captured at 3× pixel ratio for retina-sharp output

---

## Files to Create/Modify

### 1. CREATE `lib/features/poems/services/poem_share_service.dart`

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_share_image.dart';

class PoemShareService {
  /// Share poem as plain text via native share sheet.
  static Future<void> shareAsText(PoemModel poem) async {
    final buffer = StringBuffer();

    if (poem.title.isNotEmpty && poem.title != 'Untitled Poem') {
      buffer.writeln('"${poem.title}"');
      buffer.writeln();
    }

    buffer.writeln(poem.plainText.trim());

    if (poem.isOriginal && poem.author.username.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('— @${poem.author.username} on ChatBee');
    }

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString()),
    );
  }

  /// Capture a RepaintBoundary and save the PNG to the gallery.
  static Future<bool> downloadImage(GlobalKey repaintKey) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return false;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;

      final pngBytes = byteData.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name:
            'chatbee_poem_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result is Map) return result['isSuccess'] == true;
      return result != null;
    } catch (e) {
      debugPrint('[PoemShare] Download failed: $e');
      return false;
    }
  }

  /// Insert a temporary OverlayEntry off-screen, capture it, then remove it.
  /// This is the correct approach — avoids Offstage (which skips layout/paint).
  static Future<bool> generateAndSaveImage(
    BuildContext context,
    PoemModel poem,
  ) async {
    final repaintKey = GlobalKey();
    final overlayState = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: -9999,
        child: Material(
          color: Colors.transparent,
          child: PoemShareImage(poem: poem, repaintKey: repaintKey),
        ),
      ),
    );

    overlayState.insert(entry);

    // Wait for layout + paint pass
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      return await downloadImage(repaintKey);
    } finally {
      entry.remove();
    }
  }
}
```

---

### 2. CREATE `lib/features/poems/widgets/poem_share_image.dart`

This widget is rendered **off-screen** via an `OverlayEntry` and captured to a PNG.
It uses `QuillEditor.basic` for the poem body so **all rich text formatting is preserved** —
bold, italic, underline, strikethrough, text colors, and highlights render exactly as the
user styled them.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:chatbee/features/poems/models/poem_model.dart';

/// Off-screen widget captured into a PNG for sharing/downloading.
/// Wrapped in a RepaintBoundary with the provided [repaintKey].
///
/// Background is dark to match the in-app card — this ensures highlights,
/// colored text, and light-styled words remain fully visible in the output image.
class PoemShareImage extends StatelessWidget {
  final PoemModel poem;
  final GlobalKey repaintKey;

  const PoemShareImage({
    super.key,
    required this.poem,
    required this.repaintKey,
  });

  TextAlign get _textAlign {
    switch (poem.textAlign) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build a read-only QuillController from the stored Delta JSON.
    // This preserves every inline format: bold, italic, underline,
    // strikethrough, text color, background highlight — exactly as authored.
    final quillController = QuillController(
      document: Document.fromJson(poem.content), // Delta JSON field
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 1080,
        constraints: const BoxConstraints(minHeight: 600),
        // Dark background — matches the in-app card color.
        // Do NOT use white: highlights and light-colored text become invisible.
        color: const Color(0xFF1A1F2E),
        padding: const EdgeInsets.fromLTRB(72, 80, 72, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Title (plain string — always unformatted) ──
            if (poem.title.isNotEmpty && poem.title != 'Untitled Poem') ...[
              Text(
                poem.title,
                textAlign: _textAlign,
                style: const TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  // Light color — visible on dark background
                  color: Color(0xFFF0F2F8),
                  height: 1.3,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ── Poem body — rendered from Quill Delta ──
            // QuillEditor renders all inline formatting from the delta:
            // colors, highlights, bold, italic, underline, strikethrough.
            // Do NOT wrap this in a TextStyle — Quill applies its own styles
            // from the delta attributes.
            QuillEditor.basic(
              controller: quillController,
              config: QuillEditorConfig(
                scrollable: false,
                autoFocus: false,
                expands: false,
                padding: EdgeInsets.zero,
                textAlign: _textAlign,
              ),
            ),

            // ── Attribution ──
            if (poem.isOriginal && poem.author.username.isNotEmpty) ...[
              const SizedBox(height: 40),
              Text(
                '— @${poem.author.username}',
                textAlign: _textAlign,
                style: const TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  // Muted light grey — readable on dark background
                  color: Color(0xFF9CA3AF),
                  decoration: TextDecoration.none,
                ),
              ),
            ],

            // ── Branding ──
            const SizedBox(height: 56),
            const Align(
              alignment: Alignment.bottomRight,
              child: Text(
                'ChatBee',
                style: TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  // Subtle light grey — visible on dark, not distracting
                  color: Color(0xFFBBC0CC),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### 3. CREATE `lib/features/poems/widgets/poem_share_sheet.dart`

Bottom sheet with two options. The sheet itself contains no render target —
image generation is fully delegated to `PoemShareService.generateAndSaveImage`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/services/poem_share_service.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class PoemShareSheet extends StatefulWidget {
  final PoemModel poem;

  const PoemShareSheet({super.key, required this.poem});

  @override
  State<PoemShareSheet> createState() => _PoemShareSheetState();
}

class _PoemShareSheetState extends State<PoemShareSheet> {
  bool _isGenerating = false;

  Future<void> _shareAsText() async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    await PoemShareService.shareAsText(widget.poem);
  }

  Future<void> _downloadImage() async {
    if (_isGenerating) return;
    HapticFeedback.lightImpact();
    setState(() => _isGenerating = true);

    try {
      final success =
          await PoemShareService.generateAndSaveImage(context, widget.poem);

      if (!mounted) return;
      setState(() => _isGenerating = false);
      Navigator.pop(context);

      AppSnackbar.show(
        context,
        message: success ? 'Image saved to gallery' : 'Failed to save image',
        type: success ? SnackbarType.success : SnackbarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      Navigator.pop(context);
      AppSnackbar.show(
        context,
        message: 'Failed to generate image',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            'Share Poem',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDarkColor,
            ),
          ),
          SizedBox(height: 20.h),

          _buildOption(
            icon: Icons.text_fields_rounded,
            label: 'Share as Text',
            subtitle: 'Send poem text to other apps',
            onTap: _shareAsText,
          ),
          SizedBox(height: 12.h),
          _buildOption(
            icon: Icons.image_outlined,
            label: 'Download Image',
            subtitle: 'Save styled poem image to gallery',
            onTap: _downloadImage,
            isLoading: _isGenerating,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: AppTheme.featureBackgroundColor,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: isLoading
                    ? Padding(
                        padding: EdgeInsets.all(10.r),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(icon, size: 20.r, color: AppTheme.primaryColor),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.r,
                color: AppTheme.textLightColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### 4. MODIFY `lib/features/poems/widgets/poem_card.dart`

```dart
// ── ADD import ──
import 'package:chatbee/features/poems/widgets/poem_share_sheet.dart';

// ── FIND the share icon GestureDetector ──
              // Share icon (dummy)
              GestureDetector(
                onTap: () {
                  AppSnackbar.show(
                    context,
                    message: 'Sharing coming soon',
                    type: SnackbarType.info,
                  );
                },
                child: Icon(
                  Icons.share_outlined,
                  size: 18.r,
                  color: AppTheme.textLightColor,
                ),
              ),

// ── REPLACE WITH ──
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => PoemShareSheet(poem: widget.poem),
                  );
                },
                child: Icon(
                  Icons.share_outlined,
                  size: 18.r,
                  color: AppTheme.textLightColor,
                ),
              ),
```

---

### 5. ADD DEPENDENCIES to `pubspec.yaml`

```yaml
dependencies:
  share_plus: ^10.1.4
  image_gallery_saver_plus: ^3.0.5
```

Run `flutter pub get` after adding.

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Inside <manifest>, before <application> -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```
Note: Android 10+ (API 29+) uses scoped storage via MediaStore — no extra permission needed. The package handles this automatically.

**iOS** — `ios/Runner/Info.plist`:
```xml
<!-- Inside <dict> -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>ChatBee needs access to save poem images to your photo library</string>
```

---

## Summary

| File | Type | Purpose |
|------|------|---------|
| `poem_share_service.dart` | NEW | Text sharing + overlay-based image capture + gallery save |
| `poem_share_image.dart` | NEW | Off-screen widget: dark bg, QuillEditor body, JosefinSans title/attribution |
| `poem_share_sheet.dart` | NEW | Bottom sheet UI — Share as Text / Download Image |
| `poem_card.dart` | MODIFY | Wire share icon → show PoemShareSheet |
| `pubspec.yaml` | MODIFY | Add share_plus, image_gallery_saver_plus |
| `AndroidManifest.xml` | MODIFY | Storage permission for Android ≤ 9 |
| `Info.plist` | MODIFY | Photo library permission for iOS |

## Image sizing behaviour

| Content | Result |
|---------|--------|
| One-liner | `minHeight: 600` — padded, looks substantial |
| Normal poem (4–8 lines) | Natural height ~700–1000px |
| Long poem (20+ lines) | Grows as needed, no cap |
| Width | Always 1080px logical → 3240px actual (3× capture) |

## Why dark background (not white)

The poem editor allows per-word color, highlight color, underline, and strikethrough.
Light-colored words and yellow/pastel highlights are **invisible on white**.
The dark background (`0xFF1A1F2E`) is the same as the in-app card — the image looks
like a faithful screenshot of the card, which is exactly what users expect to share.
