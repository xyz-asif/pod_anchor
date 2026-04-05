import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_share_image.dart';

class PoemShareService {
  /// Render [PoemShareImage] off-screen and return the raw PNG bytes.
  /// Returns null if capture fails.
  ///
  /// FIX #15: Uses frame callbacks instead of a fragile fixed delay.
  /// Waits for two full frames to ensure the widget tree is fully laid out
  /// and painted, even on slower devices with complex Quill formatting.
  static Future<_CaptureResult?> _captureBytes(
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

    // Wait for two complete frames — first frame triggers layout,
    // second frame ensures paint is complete (including Quill rendering).
    await _waitForFrame();
    await _waitForFrame();

    // Extra safety: if the boundary still isn't ready, wait one more frame.
    var boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      await _waitForFrame();
      boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
    }

    try {
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return _CaptureResult(byteData.buffer.asUint8List());
    } finally {
      entry.remove();
    }
  }

  /// Returns a Future that completes after the next frame is rendered.
  static Future<void> _waitForFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  /// Capture the poem card and open the native share sheet.
  static Future<void> shareImageToApps(
    BuildContext context,
    PoemModel poem,
  ) async {
    final result = await _captureBytes(context, poem);
    if (result == null) return;

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/chatbee_poem_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(filePath).writeAsBytes(result.pngBytes);

    // FIX #21: Platform-aware share text
    final isIOS = Platform.isIOS;
    final storeLink = isIOS
        ? 'https://apps.apple.com/app/chatbee/id_placeholder' // TODO: Replace with actual App Store ID
        : 'https://play.google.com/store/apps/details?id=com.asif.chat&hl=en';

    final shareText =
        'Posted by @${poem.author.username} on ChatBee app.\n\n'
        'Join ChatBee - the most exciting social network for writers, readers and poets.\n\n'
        'Download ChatBee and start writing :\n\n'
        '$storeLink';

    await Share.shareXFiles([
      XFile(filePath, mimeType: 'image/png'),
    ], text: shareText);
  }

  /// Capture the poem card and save it to the device photo gallery.
  /// Returns the saved file path on success, null on failure.
  static Future<String?> generateAndSaveImage(
    BuildContext context,
    PoemModel poem,
  ) async {
    final result = await _captureBytes(context, poem);
    if (result == null) return null;

    try {
      final saveResult = await ImageGallerySaverPlus.saveImage(
        result.pngBytes,
        quality: 100,
        name: 'chatbee_poem_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (saveResult is Map && saveResult['isSuccess'] == true) {
        return saveResult['filePath'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[PoemShare] Gallery save failed: $e');
      return null;
    }
  }
}

class _CaptureResult {
  final Uint8List pngBytes;
  _CaptureResult(this.pngBytes);
}
