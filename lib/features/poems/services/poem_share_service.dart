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

    await Share.share(buffer.toString());
  }

  /// Capture a RepaintBoundary and save the PNG to the gallery.
  /// Returns the saved file path on success, null on failure.
  static Future<String?> downloadImage(GlobalKey repaintKey) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: 'chatbee_poem_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result is Map && result['isSuccess'] == true) {
        // result['filePath'] contains the saved file URI
        return result['filePath'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[PoemShare] Download failed: $e');
      return null;
    }
  }

  /// Insert a temporary OverlayEntry off-screen, capture it, then remove it.
  /// Returns the saved file path on success, null on failure.
  static Future<String?> generateAndSaveImage(
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
