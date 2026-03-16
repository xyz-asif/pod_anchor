import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/widgets/floating_toolbar.dart';
import 'package:chatbee/features/poems/widgets/word_counter.dart';
import 'package:chatbee/features/poems/widgets/publish_bottom_sheet.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class PoetryEditorScreen extends ConsumerStatefulWidget {
  final String? poemId;
  final PoemModel? existingPoem;

  const PoetryEditorScreen({super.key, this.poemId, this.existingPoem});

  @override
  ConsumerState<PoetryEditorScreen> createState() => _PoetryEditorScreenState();
}

class _PoetryEditorScreenState extends ConsumerState<PoetryEditorScreen> {
  late QuillController _quillController;
  late TextEditingController _titleController;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey _editorKey = GlobalKey();

  PoemModel? _currentPoem;

  bool _isPreviewMode = false;
  bool _showToolbar = false;
  bool _justSaved = false;
  Timer? _toolbarHideTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  int _wordCount = 0;
  int _lineCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();

    // Track the current poem so we can refresh audio UI after saving.
    _currentPoem = widget.existingPoem;

    // Initialize controller from existing poem or blank
    if (_currentPoem != null) {
      try {
        final doc = Document.fromJson(
          jsonDecode(_currentPoem!.contentJson) as List,
        );
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _quillController = QuillController.basic();
      }
      _titleController = TextEditingController(text: _currentPoem!.title);
    } else {
      _quillController = QuillController.basic();
      _titleController = TextEditingController();
    }

    // Listen for content changes → update word count
    _quillController.document.changes.listen((_) {
      _updateCounts();
    });

    // Listen for selection changes → show/hide floating toolbar
    _quillController.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() {
    final selection = _quillController.selection;

    // Cancel any existing timer
    _toolbarHideTimer?.cancel();

    if (selection.isValid && !selection.isCollapsed && !_isPreviewMode) {
      setState(() {
        _showToolbar = true;
      });

      // Auto-hide toolbar after 5 seconds of inactivity
      _toolbarHideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showToolbar = false;
          });
        }
      });
    } else {
      setState(() {
        _showToolbar = false;
      });
    }
  }

  void _updateCounts() {
    final text = _quillController.document.toPlainText().trim();
    setState(() {
      if (text.isEmpty) {
        _wordCount = 0;
        _charCount = 0;
        _lineCount = 0;
      } else {
        _wordCount = text
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
        _charCount = text.length;
        _lineCount = text.split('\n').length;
      }
    });
  }

  Future<void> _toggleExistingAudioPlayback() async {
    final audioUrl = _currentPoem?.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No audio attached to this poem.',
        type: SnackbarType.error,
      );
      return;
    }

    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }

    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      await _audioPlayer.play();
      setState(() => _isPlayingAudio = true);
      _audioPlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isPlayingAudio = false);
        }
      });
    } catch (e) {
      AppSnackbar.show(
        context,
        message: 'Unable to play audio.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _deletePoem() async {
    if (widget.poemId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete poem?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(poemRepoProvider).deletePoem(widget.poemId!);
      ref.read(myPoemsControllerProvider.notifier).removePoem(widget.poemId!);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Poem deleted',
          type: SnackbarType.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to delete poem',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _toolbarHideTimer?.cancel();
    _quillController.removeListener(_onSelectionChanged);
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim();

    if (plainText.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Write something first',
        type: SnackbarType.error,
      );
      return;
    }

    final result = await showPublishBottomSheet(
      context: context,
      ref: ref,
      title: title.isEmpty ? 'Untitled Poem' : title,
      contentJson: contentJson,
      plainText: plainText,
      coverColor: '',
      existingPoemId: widget.poemId,
      existingPoem: _currentPoem,
    );

    if (result != null && mounted) {
      // Update local state so audio / title updates show up immediately
      setState(() {
        _currentPoem = result;
        _titleController.text = result.title;
      });
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Title field
                _buildTitleField(context),

                // Divider - make it more subtle
                Divider(
                  height: 1,
                  indent: 40,
                  endIndent: 40,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),

                // Audio player (if current poem has audio)
                if (_currentPoem?.hasAudio == true) ...[
                  _buildExistingAudioPlayer(),
                  const Divider(),
                ],

                // Poem body editor
                Expanded(child: _buildEditor(context)),

                // Word counter
                WordCounter(
                  words: _wordCount,
                  lines: _lineCount,
                  characters: _charCount,
                  showSavedIndicator: _justSaved,
                ),
              ],
            ),

            // Floating toolbar
            if (_showToolbar && !_isPreviewMode)
              Positioned(
                top: 200,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showToolbar ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: AnimatedSlide(
                      offset: _showToolbar ? Offset.zero : const Offset(0, 0.2),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: FloatingToolbar(controller: _quillController),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => context.pop(),
      ),
      actions: [
        if (widget.poemId != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _deletePoem,
          ),

        // Preview mode toggle
        IconButton(
          icon: Icon(
            _isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined,
          ),
          tooltip: _isPreviewMode ? 'Edit' : 'Preview',
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isPreviewMode = !_isPreviewMode;
            });
          },
        ),

        // Undo
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Undo',
          onPressed: () {
            HapticFeedback.lightImpact();
            _quillController.undo();
          },
        ),

        // Redo
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: 'Redo',
          onPressed: () {
            HapticFeedback.lightImpact();
            _quillController.redo();
          },
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF5F0EB)
        : const Color(0xFF1A1A2E);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        readOnly: _isPreviewMode,
        textAlign: TextAlign.center,
        style: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 1.5,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: 'Untitled Poem',
          hintStyle: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textColor.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
            height: 1.2,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: textColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) {
          _editorFocusNode.requestFocus();
        },
      ),
    );
  }

  Widget _buildExistingAudioPlayer() {
    final duration = _currentPoem?.audioDuration ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleExistingAudioPlayback,
            icon: Icon(
              _isPlayingAudio
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Voice recording attached',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                if (duration > 0)
                  Text(
                    '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final poemId = _currentPoem?.id;
              if (poemId == null) return;
              try {
                final updated = await ref
                    .read(poemRepoProvider)
                    .updatePoem(
                      poemId,
                      CreatePoemRequest(
                        title: _titleController.text.trim(),
                        contentJson: jsonEncode(
                          _quillController.document.toDelta().toJson(),
                        ),
                        plainText: _quillController.document
                            .toPlainText()
                            .trim(),
                        hashtags: _currentPoem?.hashtags ?? [],
                        mood: _currentPoem?.mood ?? '',
                        isOriginal: _currentPoem?.isOriginal ?? false,
                        visibility: _currentPoem?.visibility ?? 'public',
                        audioUrl: '',
                        audioDuration: 0,
                        coverColor: _currentPoem?.coverColor ?? '',
                      ),
                    );
                ref
                    .read(myPoemsControllerProvider.notifier)
                    .updatePoem(updated);

                if (mounted) {
                  setState(() {
                    _currentPoem = updated;
                    _isPlayingAudio = false;
                  });
                }

                AppSnackbar.show(
                  context,
                  message: 'Audio removed',
                  type: SnackbarType.success,
                );
              } catch (e) {
                AppSnackbar.show(
                  context,
                  message: 'Failed to remove audio',
                  type: SnackbarType.error,
                );
              }
            },
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    _quillController.readOnly = _isPreviewMode;

    return Container(
      key: _editorKey,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: QuillEditor.basic(
        controller: _quillController,
        focusNode: _editorFocusNode,
        config: QuillEditorConfig(
          placeholder: 'Begin writing...',
          padding: const EdgeInsets.symmetric(vertical: 8),
          customStyles: DefaultStyles(
            paragraph: DefaultTextBlockStyle(
              GoogleFonts.lato(
                fontSize: 18,
                height: 1.2, // Tighter height
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(0, 8), // Add space between paragraphs
              const VerticalSpacing(0, 0),
              null,
            ),
            placeHolder: DefaultTextBlockStyle(
              GoogleFonts.lato(
                fontSize: 18,
                height: 1.2,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
              const HorizontalSpacing(0, 0),
              const VerticalSpacing(0, 8),
              const VerticalSpacing(0, 0),
              null,
            ),
          ),
        ),
      ),
    );
  }
}
