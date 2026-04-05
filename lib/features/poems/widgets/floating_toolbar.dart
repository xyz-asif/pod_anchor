import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:chatbee/features/poems/widgets/color_picker_dialog.dart';

class FloatingToolbar extends StatefulWidget {
  final QuillController controller;
  final VoidCallback? onMoreOptions;
  final TextSelection? savedSelection;

  /// Called whenever the user taps any formatting button.
  /// The parent can use this to reset auto-hide timers, etc.
  final VoidCallback? onInteraction;

  const FloatingToolbar({
    super.key,
    required this.controller,
    this.onMoreOptions,
    this.savedSelection,
    this.onInteraction,
  });

  @override
  State<FloatingToolbar> createState() => _FloatingToolbarState();
}

class _FloatingToolbarState extends State<FloatingToolbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(FloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Rebuild on every selection or style change so _isBold etc. stay accurate.
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ── Helpers ──

  /// Returns the best available non-collapsed selection.
  /// Prefers the live controller selection; falls back to the saved one only
  /// if the live one is collapsed (e.g. toolbar button tap caused focus loss).
  TextSelection? get _effectiveSelection {
    final sel = widget.controller.selection;
    if (sel.isValid && !sel.isCollapsed) return sel;
    return widget.savedSelection;
  }

  /// Restores the saved selection ONLY when the controller's current selection
  /// has collapsed AND the saved one is still valid within document bounds.
  void _restoreSelectionIfNeeded() {
    final sel = widget.controller.selection;
    if (!sel.isCollapsed) return; // Current selection is fine — don't touch it.
    if (widget.savedSelection == null || widget.savedSelection!.isCollapsed)
      return;

    final docLength = widget.controller.document.length;
    final saved = widget.savedSelection!;

    // Clamp to document bounds to prevent RangeError
    final clampedStart = saved.start.clamp(0, docLength - 1);
    final clampedEnd = saved.end.clamp(clampedStart, docLength);

    if (clampedStart < clampedEnd) {
      widget.controller.updateSelection(
        TextSelection(baseOffset: clampedStart, extentOffset: clampedEnd),
        ChangeSource.local,
      );
    }
  }

  // ── Format getters ──

  bool get _isBold {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    return widget.controller.getSelectionStyle().containsKey(
      Attribute.bold.key,
    );
  }

  bool get _isItalic {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    return widget.controller.getSelectionStyle().containsKey(
      Attribute.italic.key,
    );
  }

  bool get _isUnderline {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    return widget.controller.getSelectionStyle().containsKey(
      Attribute.underline.key,
    );
  }

  bool get _isStrikethrough {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    return widget.controller.getSelectionStyle().containsKey(
      Attribute.strikeThrough.key,
    );
  }

  Color _getTextColor() {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return Colors.white;
    final attrs = widget.controller.getSelectionStyle();
    final colorAttr = attrs.attributes[Attribute.color.key];
    if (colorAttr != null && colorAttr.value != null) {
      try {
        return Color(
          int.parse(colorAttr.value.toString().substring(1), radix: 16) +
              0xFF000000,
        );
      } catch (_) {
        return Colors.white;
      }
    }
    return Colors.white;
  }

  Color _getHighlightColor() {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed)
      return Colors.transparent;
    final attrs = widget.controller.getSelectionStyle();
    final bgAttr = attrs.attributes[Attribute.background.key];
    if (bgAttr != null && bgAttr.value != null) {
      try {
        return Color(
          int.parse(bgAttr.value.toString().substring(1), radix: 16) +
              0xFF000000,
        );
      } catch (_) {
        return Colors.transparent;
      }
    }
    return Colors.transparent;
  }

  bool _hasCustomSize() {
    final sel = _effectiveSelection;
    if (sel == null || !sel.isValid || sel.isCollapsed) return false;
    return widget.controller.getSelectionStyle().containsKey(
      Attribute.size.key,
    );
  }

  // ── Toggle actions ──

  void _notifyInteraction() {
    widget.onInteraction?.call();
  }

  void _toggleBold() {
    HapticFeedback.lightImpact();
    _notifyInteraction();
    _restoreSelectionIfNeeded();
    widget.controller.formatSelection(
      _isBold ? Attribute.clone(Attribute.bold, null) : Attribute.bold,
    );
  }

  void _toggleItalic() {
    HapticFeedback.lightImpact();
    _notifyInteraction();
    _restoreSelectionIfNeeded();
    widget.controller.formatSelection(
      _isItalic ? Attribute.clone(Attribute.italic, null) : Attribute.italic,
    );
  }

  void _toggleUnderline() {
    HapticFeedback.lightImpact();
    _notifyInteraction();
    _restoreSelectionIfNeeded();
    widget.controller.formatSelection(
      _isUnderline
          ? Attribute.clone(Attribute.underline, null)
          : Attribute.underline,
    );
  }

  void _toggleStrikethrough() {
    HapticFeedback.lightImpact();
    _notifyInteraction();
    _restoreSelectionIfNeeded();
    widget.controller.formatSelection(
      _isStrikethrough
          ? Attribute.clone(Attribute.strikeThrough, null)
          : Attribute.strikeThrough,
    );
  }

  // ── Color pickers ──

  void _showTextColorPicker(BuildContext context) {
    _notifyInteraction();
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _getTextColor(),
        onColorSelected: (color) {
          _restoreSelectionIfNeeded();
          final selection = widget.controller.selection;
          if (color == Colors.transparent) {
            widget.controller.formatSelection(
              Attribute.clone(Attribute.color, null),
            );
          } else {
            final hex = '#${color.value.toRadixString(16).substring(2)}';
            widget.controller.formatSelection(ColorAttribute(hex));
          }

          if (!selection.isCollapsed) {
            widget.controller.updateSelection(
              TextSelection.collapsed(offset: selection.end),
              ChangeSource.local,
            );
            widget.controller.formatSelection(
              Attribute.clone(Attribute.color, null),
            );
          }
        },
      ),
    );
  }

  void _showHighlightColorPicker(BuildContext context) {
    _notifyInteraction();
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: _getHighlightColor(),
        isForHighlight: true,
        onColorSelected: (color) {
          _restoreSelectionIfNeeded();
          final selection = widget.controller.selection;
          if (color == Colors.transparent) {
            widget.controller.formatSelection(
              Attribute.clone(Attribute.background, null),
            );
          } else {
            final hex = '#${color.value.toRadixString(16).substring(2)}';
            widget.controller.formatSelection(BackgroundAttribute(hex));
          }

          if (!selection.isCollapsed) {
            widget.controller.updateSelection(
              TextSelection.collapsed(offset: selection.end),
              ChangeSource.local,
            );
            widget.controller.formatSelection(
              Attribute.clone(Attribute.background, null),
            );
          }
        },
      ),
    );
  }

  // ── Font size menu ──

  void _showFontSizeMenu(BuildContext context) {
    _notifyInteraction();
    final sizes = [
      {'label': 'Small', 'value': 'small'},
      {'label': 'Normal', 'value': null},
      {'label': 'Large', 'value': 'large'},
      {'label': 'Huge', 'value': 'huge'},
    ];

    final screenSize = MediaQuery.of(context).size;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        screenSize.width / 2,
        screenSize.height / 2,
        screenSize.width / 2,
        screenSize.height / 2,
      ),
      items: sizes.map((size) {
        return PopupMenuItem<String?>(
          value: size['value'],
          child: Text(size['label'] as String),
          onTap: () {
            HapticFeedback.lightImpact();
            _restoreSelectionIfNeeded();
            if (size['value'] == null) {
              widget.controller.formatSelection(
                Attribute.clone(Attribute.size, null),
              );
            } else {
              widget.controller.formatSelection(
                Attribute.fromKeyValue('size', size['value']),
              );
            }
          },
        );
      }).toList(),
    );
  }

  // ── Build ──

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
              onTap: _toggleBold,
            ),

            // Italic
            _ToolbarButton(
              icon: Icons.format_italic,
              isActive: _isItalic,
              onTap: _toggleItalic,
            ),

            // Underline
            _ToolbarButton(
              icon: Icons.format_underline,
              isActive: _isUnderline,
              onTap: _toggleUnderline,
            ),

            // Strikethrough
            _ToolbarButton(
              icon: Icons.format_strikethrough,
              isActive: _isStrikethrough,
              onTap: _toggleStrikethrough,
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
}

// ── Private widgets (unchanged) ──

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
                      color: color == Colors.transparent ? Colors.white : color,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.white, width: 0.5),
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
