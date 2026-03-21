import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:chatbee/features/poems/widgets/color_picker_dialog.dart';

class FloatingToolbar extends StatelessWidget {
  final QuillController controller;
  final VoidCallback? onMoreOptions;
  final TextSelection? savedSelection;

  const FloatingToolbar({
    super.key,
    required this.controller,
    this.onMoreOptions,
    this.savedSelection,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]!.withValues(alpha: 0.92)
            : Colors.grey[800]!.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bold
            _ToolbarButton(
              icon: Icons.format_bold,
              isActive: _isBold,
              onTap: () => _toggleBold(),
            ),

            // Italic
            _ToolbarButton(
              icon: Icons.format_italic,
              isActive: _isItalic,
              onTap: () => _toggleItalic(),
            ),

            // Underline
            _ToolbarButton(
              icon: Icons.format_underline,
              isActive: _isUnderline,
              onTap: () => _toggleUnderline(),
            ),

            // Strikethrough
            _ToolbarButton(
              icon: Icons.format_strikethrough,
              isActive: _isStrikethrough,
              onTap: () => _toggleStrikethrough(),
            ),

            const _ToolbarDivider(),

            // Text Color
            _ColorButton(
              icon: Icons.format_color_text,
              color: _getTextColor(),
              onTap: () => _showTextColorPicker(context),
            ),

            // Highlight
            _ColorButton(
              icon: Icons.format_color_fill,
              color: _getHighlightColor(),
              isHighlight: true,
              onTap: () => _showHighlightColorPicker(context),
            ),

            const _ToolbarDivider(),

            // Font Size Options
            _ToolbarButton(
              icon: Icons.format_size,
              isActive: _hasCustomSize(),
              onTap: () => _showFontSizeMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  // Format getters
  TextSelection? get _effectiveSelection {
    final sel = controller.selection;
    if (sel.isValid && !sel.isCollapsed) return sel;
    return savedSelection;
  }

  bool get _isBold {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    final attrs = controller.getSelectionStyle();
    return attrs.containsKey(Attribute.bold.key);
  }

  bool get _isItalic {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    final attrs = controller.getSelectionStyle();
    return attrs.containsKey(Attribute.italic.key);
  }

  bool get _isUnderline {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    final attrs = controller.getSelectionStyle();
    return attrs.containsKey(Attribute.underline.key);
  }

  bool get _isStrikethrough {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    final attrs = controller.getSelectionStyle();
    return attrs.containsKey(Attribute.strikeThrough.key);
  }

  Color _getTextColor() {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return Colors.white;
    final attrs = controller.getSelectionStyle();
    final colorAttr = attrs.attributes[Attribute.color.key];
    if (colorAttr != null && colorAttr.value != null) {
      try {
        return Color(
            int.parse(colorAttr.value.toString().substring(1), radix: 16) +
                0xFF000000);
      } catch (e) {
        return Colors.white;
      }
    }
    return Colors.white;
  }

  Color _getHighlightColor() {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return Colors.transparent;
    final attrs = controller.getSelectionStyle();
    final bgAttr = attrs.attributes[Attribute.background.key];
    if (bgAttr != null && bgAttr.value != null) {
      try {
        return Color(
            int.parse(bgAttr.value.toString().substring(1), radix: 16) +
                0xFF000000);
      } catch (e) {
        return Colors.transparent;
      }
    }
    return Colors.transparent;
  }

  bool _hasCustomSize() {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    final attrs = controller.getSelectionStyle();
    return attrs.containsKey(Attribute.size.key);
  }

  void _restoreSelectionIfNeeded() {
    final sel = controller.selection;
    if (sel.isCollapsed && savedSelection != null && !savedSelection!.isCollapsed) {
      controller.updateSelection(savedSelection!, ChangeSource.local);
    }
  }

  // Toggle actions
  void _toggleBold() {
    HapticFeedback.lightImpact();
    _restoreSelectionIfNeeded();
    controller.formatSelection(Attribute.bold);
  }

  void _toggleItalic() {
    HapticFeedback.lightImpact();
    _restoreSelectionIfNeeded();
    controller.formatSelection(Attribute.italic);
  }

  void _toggleUnderline() {
    HapticFeedback.lightImpact();
    _restoreSelectionIfNeeded();
    controller.formatSelection(Attribute.underline);
  }

  void _toggleStrikethrough() {
    HapticFeedback.lightImpact();
    _restoreSelectionIfNeeded();
    controller.formatSelection(Attribute.strikeThrough);
  }

  // Color pickers
  void _showTextColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _getTextColor(),
        onColorSelected: (color) {
          _restoreSelectionIfNeeded();
          final selection = controller.selection;
          if (color == Colors.transparent) {
            controller
                .formatSelection(Attribute.clone(Attribute.color, null));
          } else {
            final hex = '#${color.value.toRadixString(16).substring(2)}';
            controller.formatSelection(ColorAttribute(hex));
          }

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

  void _showHighlightColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _getHighlightColor(),
        isForHighlight: true,
        onColorSelected: (color) {
          _restoreSelectionIfNeeded();
          final selection = controller.selection;
          if (color == Colors.transparent) {
            controller.formatSelection(
                Attribute.clone(Attribute.background, null));
          } else {
            final hex = '#${color.value.toRadixString(16).substring(2)}';
            controller.formatSelection(BackgroundAttribute(hex));
          }

          if (!selection.isCollapsed) {
            controller.updateSelection(
              TextSelection.collapsed(offset: selection.end),
              ChangeSource.local,
            );
            controller.formatSelection(Attribute.clone(Attribute.background, null));
          }
        },
      ),
    );
  }

  // Font size menu
  void _showFontSizeMenu(BuildContext context) {
    final sizes = [
      {'label': 'Small', 'value': 'small'},
      {'label': 'Normal', 'value': null},
      {'label': 'Large', 'value': 'large'},
      {'label': 'Huge', 'value': 'huge'},
    ];

    final size = MediaQuery.of(context).size;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        size.width / 2,
        size.height / 2,
        size.width / 2,
        size.height / 2,
      ),
      items: sizes.map((size) {
        return PopupMenuItem<String?>(
          value: size['value'],
          child: Text(size['label'] as String),
          onTap: () {
            HapticFeedback.lightImpact();
            _restoreSelectionIfNeeded();
            if (size['value'] == null) {
              controller
                  .formatSelection(Attribute.clone(Attribute.size, null));
            } else {
              controller.formatSelection(
                  Attribute.fromKeyValue('size', size['value']));
            }
          },
        );
      }).toList(),
    );
  }
}

// Toolbar button widget
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isHighlight;
  final VoidCallback onTap;

  const _ColorButton({
    required this.icon,
    required this.color,
    this.isHighlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              if (!isHighlight || color != Colors.transparent)
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color:
                          color == Colors.transparent ? Colors.white : color,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: Colors.white,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.3),
    );
  }
}
