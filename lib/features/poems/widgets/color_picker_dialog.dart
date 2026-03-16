import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerDialog extends StatelessWidget {
  final Color initialColor;
  final Function(Color) onColorSelected;
  final bool isForHighlight;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
    this.isForHighlight = false,
  });

  // Curated poetry-friendly color palette
  static const List<Color> poetryColors = [
    Color(0xFF1A1A2E), // Ink Black
    Color(0xFF6B0F1A), // Deep Crimson
    Color(0xFF1B3A4B), // Midnight Blue
    Color(0xFF2D6A4F), // Forest Green
    Color(0xFFA0522D), // Burnt Sienna
    Color(0xFFC9928E), // Dusty Rose
    Color(0xFFD4A843), // Amber Gold
    Color(0xFF6A0572), // Plum
    Color(0xFF6C757D), // Storm Gray
    Color(0xFF2A9D8F), // Ocean Teal
    Color(0xFF9B8EC1), // Soft Lavender
    Color(0xFFF5F0EB), // Warm White
    Color(0xFFE63946), // Soft Red
    Color(0xFFF4A261), // Peach
    Color(0xFF264653), // Charcoal Blue
    Color(0xFF8B4513), // Saddle Brown
  ];

  // Highlight/background colors
  static const List<Color> highlightColors = [
    Color(0xFFFFFF00), // Yellow
    Color(0xFF90EE90), // Light Green
    Color(0xFFFFB6C1), // Light Pink
    Color(0xFF87CEEB), // Light Blue
    Color(0xFFDDA0DD), // Plum
    Color(0xFFFFA500), // Orange
    Color(0xFFE0E0E0), // Light Gray
    Color(0xFFFFF8DC), // Cornsilk
  ];

  @override
  Widget build(BuildContext context) {
    final colors = isForHighlight ? highlightColors : poetryColors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isForHighlight ? 'Highlight Color' : 'Text Color',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),

            // Curated palette grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((color) {
                return _ColorCircle(
                  color: color,
                  isSelected: color.value == initialColor.value,
                  onTap: () {
                    onColorSelected(color);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Custom color picker button
            TextButton.icon(
              onPressed: () {
                _showCustomColorPicker(context);
              },
              icon: const Icon(Icons.colorize),
              label: const Text('Custom Color'),
            ),

            // Reset button
            TextButton.icon(
              onPressed: () {
                onColorSelected(Colors.transparent);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.format_clear),
              label:
                  Text(isForHighlight ? 'Remove Highlight' : 'Default Color'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomColorPicker(BuildContext context) {
    Color tempColor = initialColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (color) {
              tempColor = color;
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onColorSelected(tempColor);
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 18,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}
