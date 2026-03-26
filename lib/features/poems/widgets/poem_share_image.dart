import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:chatbee/features/poems/models/poem_model.dart';

/// Off-screen widget captured into a PNG for sharing/downloading.
/// Wrapped in a RepaintBoundary with the provided [repaintKey].
///
/// Uses a phone-friendly width (420 logical px) so text fills the frame
/// naturally. Captured at 3× pixel ratio → 1260px actual output.
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

  CrossAxisAlignment get _crossAxisAlignment {
    switch (poem.textAlign) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'right':
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build a read-only QuillController from the stored Delta JSON.
    // This preserves every inline format: bold, italic, underline,
    // strikethrough, text color, background highlight — exactly as authored.
    final quillController = QuillController(
      document: Document.fromJson(jsonDecode(poem.contentJson) as List),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        // Phone-friendly width — text fills the frame like the Miraquill example.
        // Captured at 3× → 1260px actual width (sharp on retina screens).
        width: 420,
        color: const Color(0xFF1A1F2E),
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _crossAxisAlignment,
          children: [
            // ── Title ──
            if (poem.title.isNotEmpty && poem.title != 'Untitled Poem') ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  poem.title,
                  textAlign: _textAlign,
                  style: const TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF0F2F8),
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Poem body — rendered from Quill Delta ──
            // QuillEditor renders all inline + block formatting from the delta:
            // colors, highlights, bold, italic, underline, strikethrough,
            // AND alignment (center/right/left as stored in the delta attributes).
            SizedBox(
              width: double.infinity,
              child: IgnorePointer(
                child: QuillEditor.basic(
                  controller: quillController,
                  config: QuillEditorConfig(
                    scrollable: false,
                    autoFocus: false,
                    expands: false,
                    padding: EdgeInsets.zero,
                    showCursor: false,
                    customStyles: DefaultStyles(
                      paragraph: DefaultTextBlockStyle(
                        const TextStyle(
                          fontFamily: 'JosefinSans',
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFFE0E4EF),
                          decoration: TextDecoration.none,
                        ),
                        const HorizontalSpacing(0, 0),
                        const VerticalSpacing(0, 6),
                        const VerticalSpacing(0, 0),
                        null,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Attribution ──
            if (poem.isOriginal && poem.author.username.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Text(
                  '— @${poem.author.username}',
                  textAlign: _textAlign,
                  style: const TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF9CA3AF),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],

            // ── Branding ──
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.bottomRight,
              child: Text(
                'ChatBee',
                style: TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
