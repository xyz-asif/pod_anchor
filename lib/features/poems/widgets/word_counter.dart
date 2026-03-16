import 'package:flutter/material.dart';

class WordCounter extends StatelessWidget {
  final int words;
  final int lines;
  final int characters;
  final bool showSavedIndicator;

  const WordCounter({
    super.key,
    required this.words,
    required this.lines,
    required this.characters,
    this.showSavedIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF5F0EB).withValues(alpha: 0.5)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Word count info
          Row(
            children: [
              Text(
                'Words: $words',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              _buildDivider(textColor),
              Text(
                'Lines: $lines',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              _buildDivider(textColor),
              Text(
                'Characters: $characters',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          // Saved indicator
          AnimatedOpacity(
            opacity: showSavedIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 12,
                  color: textColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Saved',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      width: 1,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}
