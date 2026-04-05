import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';

/// A text field with @mention autocomplete for the description field
class MentionTextField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final void Function(List<String>)? onMentionsChanged;

  const MentionTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Add a description... use @username to mention',
    this.maxLength = 200,
    this.onMentionsChanged,
  });

  @override
  ConsumerState<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends ConsumerState<MentionTextField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  String _currentQuery = '';
  final List<String> _suggestions = [];
  final List<String> _selectedMentions = [];

  // FIX #9: Internal focus node to detect focus loss
  late final FocusNode _effectiveFocusNode;
  bool _ownsNode = false;

  // FIX #9: Scroll listener to dismiss overlay on parent scroll
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _effectiveFocusNode = widget.focusNode!;
    } else {
      _effectiveFocusNode = FocusNode();
      _ownsNode = true;
    }
    widget.controller.addListener(_onTextChanged);
    // FIX #9: Dismiss overlay when focus is lost
    _effectiveFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FIX #9: Listen to parent scroll to dismiss overlay
    _scrollPosition?.removeListener(_onParentScroll);
    _scrollPosition = Scrollable.maybeOf(context)?.position;
    _scrollPosition?.addListener(_onParentScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _effectiveFocusNode.removeListener(_onFocusChanged);
    if (_ownsNode) _effectiveFocusNode.dispose();
    _scrollPosition?.removeListener(_onParentScroll);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onParentScroll() {
    _removeOverlay();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;

    if (cursor < 0 || cursor > text.length) {
      _removeOverlay();
      return;
    }

    final textBeforeCursor = text.substring(0, cursor);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final query = textBeforeCursor.substring(atIndex + 1);
      // Only search if query has content and no spaces
      if (!query.contains(' ') && query.isNotEmpty) {
        _currentQuery = query;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          _fetchSuggestions(query);
        });
        return;
      }
    }

    // No @ context or query has space - remove overlay
    _removeOverlay();
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;

    try {
      final response = await ref
          .read(socialRepoProvider)
          .searchUsersForMention(query);
      if (mounted && _currentQuery == query) {
        setState(() {
          _suggestions.clear();
          _suggestions.addAll(response);
        });
        if (_suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (_) {
      if (mounted) {
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4.h),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12.r),
            color: AppTheme.surfaceColor,
            child: Container(
              constraints: BoxConstraints(maxHeight: 200.h),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final username = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18.r,
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkColor,
                      ),
                    ),
                    onTap: () => _insertMention(username),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insertMention(String username) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursor);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final newText =
          '${text.substring(0, atIndex)}@$username ${text.substring(cursor)}';
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: atIndex + username.length + 2, // +2 for @ and space
        ),
      );

      // Track this mention
      if (!_selectedMentions.contains(username)) {
        _selectedMentions.add(username);
      }
    }

    _removeOverlay();
    HapticFeedback.lightImpact();
  }

  List<String> get mentions => _selectedMentions;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        maxLines: 3,
        minLines: 1,
        maxLength: widget.maxLength,
        style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor),
          filled: true,
          fillColor: AppTheme.featureBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          counterText: '', // Hide default counter
        ),
      ),
    );
  }
}
