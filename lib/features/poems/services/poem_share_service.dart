import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_share_image.dart';

class PoemShareService {
  /// Render [PoemShareImage] off-screen and return the raw PNG bytes.
  /// Returns null if capture fails.
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
    // Give Flutter one frame to lay out and paint the off-screen widget.
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return _CaptureResult(byteData.buffer.asUint8List());
    } finally {
      entry.remove();
    }
  }

  /// Capture the poem card and open the native share sheet so the user can
  /// send the image to WhatsApp, Instagram, or any other app.
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

    final shareText = 'Posted by @${poem.author.username} on ChatBee app.\n\n'
        'Join ChatBee - the most exciting social network for writers, readers and poets.\n\n'
        'Download ChatBee and start writing :\n\n'
        'https://play.google.com/store/apps/details?id=com.asif.chat&hl=en';

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'image/png')],
      text: shareText,
    );
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
