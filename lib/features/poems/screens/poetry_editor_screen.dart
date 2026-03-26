import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/widgets/floating_toolbar.dart';
import 'package:chatbee/features/poems/widgets/mention_text_field.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

// ── Static hashtag chips ──
const List<String> kStaticHashtags = [
  'love',
  'grief',
  'nature',
  'nostalgia',
  'hope',
  'dark',
  'spiritual',
  'humour',
  'life',
  'longing',
];

// ── Audio state enum ──
enum AudioState { idle, recording, recorded, uploading, uploaded }

class PoetryEditorScreen extends ConsumerStatefulWidget {
  final String? poemId;
  final PoemModel? existingPoem;

  const PoetryEditorScreen({super.key, this.poemId, this.existingPoem});

  @override
  ConsumerState<PoetryEditorScreen> createState() => _PoetryEditorScreenState();
}

class _PoetryEditorScreenState extends ConsumerState<PoetryEditorScreen>
    with SingleTickerProviderStateMixin {
  // ── Core editor ──
  late QuillController _quillController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey _editorKey = GlobalKey();

  PoemModel? _currentPoem;

  // ── Toolbar ──
  bool _showToolbar = false;
  double? _toolbarTop;
  Timer? _toolbarHideTimer;
  TextSelection? _lastNonCollapsedSelection;

  // ── Word count ──
  Timer? _countDebounce;
  StreamSubscription? _documentChangesSub;
  int _wordCount = 0;

  // ── Alignment ──
  String _textAlign = 'left';

  // ── Hashtag state ──
  final Set<String> _selectedHashtags = {};
  final TextEditingController _customTagController = TextEditingController();
  final List<String> _customTags = [];

  // ── Copyright state ──
  bool _isOriginal = false;
  bool _isPublishing = false;

  // ── Audio state ──
  AudioState _audioState = AudioState.idle;
  String? _recordingPath;
  String? _audioURL;
  int _audioDuration = 0;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlayingPreview = false;
  bool _isRecordingPaused = false;
  bool _isLoadingAudio = false;
  bool _hasEdits = false;
  StreamSubscription? _audioPlayerSub;

  // ── Pulse animation for recording ──
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _currentPoem = widget.existingPoem;

    // Initialize Quill controller
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

    // Initialize description
    _descriptionController = TextEditingController(
      text: _currentPoem?.description ?? '',
    );

    // Initialize alignment
    _textAlign = _currentPoem?.textAlign ?? 'left';

    // Initialize hashtags
    if (_currentPoem != null) {
      _selectedHashtags.addAll(
        _currentPoem!.hashtags.where((t) => kStaticHashtags.contains(t)),
      );
      _customTags.addAll(
        _currentPoem!.hashtags.where((t) => !kStaticHashtags.contains(t)),
      );
    }

    // Initialize original
    _isOriginal = _currentPoem?.isOriginal ?? false;

    // Initialize audio
    if (_currentPoem?.hasAudio == true) {
      _audioURL = _currentPoem!.audioUrl;
      _audioDuration = _currentPoem!.audioDuration;
      _audioState = AudioState.uploaded;
    }

    // Word count listener
    _documentChangesSub = _quillController.document.changes.listen((_) {
      _hasEdits = true;
      _countDebounce?.cancel();
      _countDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _updateCounts();
      });
    });

    // Selection listener for floating toolbar
    _quillController.addListener(_onSelectionChanged);

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _onSelectionChanged() {
    final selection = _quillController.selection;
    _toolbarHideTimer?.cancel();

    if (selection.isValid && !selection.isCollapsed) {
      _lastNonCollapsedSelection = selection;
      _calculateToolbarPosition();
      setState(() => _showToolbar = true);
      _toolbarHideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showToolbar = false);
      });
    } else {
      if (_showToolbar) {
        _toolbarHideTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && _quillController.selection.isCollapsed) {
            setState(() {
              _showToolbar = false;
              _lastNonCollapsedSelection = null;
            });
          }
        });
      }
    }
  }

  void _calculateToolbarPosition() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    final bottomPadding = 60.0;
    final visibleEditorHeight = screenHeight - topPadding - bottomPadding;
    final toolbarY = topPadding + (visibleEditorHeight * 0.15);
    setState(() {
      _showToolbar = true;
      _toolbarTop = toolbarY.clamp(topPadding + 8, screenHeight - 100);
    });
  }

  TextAlign get _textAlignEnum {
    switch (_textAlign) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  bool get _hasUnsavedChanges {
    final currentTitle = _titleController.text.trim();

    if (_currentPoem == null) {
      return _quillController.document.toPlainText().trim().isNotEmpty ||
          currentTitle.isNotEmpty;
    }

    // Quick check: if no document edits and title unchanged, skip expensive delta comparison
    if (!_hasEdits && currentTitle == _currentPoem!.title.trim()) return false;

    final currentDelta = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    return currentDelta != _currentPoem!.contentJson ||
        currentTitle != _currentPoem!.title.trim();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unsaved changes',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have unsaved changes. What would you like to do?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: Text(
              'Keep editing',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              'Discard',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
    return result == 'discard';
  }

  void _updateCounts() {
    final text = _quillController.document.toPlainText().trim();
    setState(() {
      if (text.isEmpty) {
        _wordCount = 0;
      } else {
        _wordCount = text
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
      }
    });
  }

  // ── Audio recording ──

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Microphone permission denied',
          type: SnackbarType.error,
        );
      }
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/poem_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _pulseController.repeat(reverse: true);
      setState(() {
        _audioState = AudioState.recording;
        _recordingPath = path;
        _recordingSeconds = 0;
        _isRecordingPaused = false;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordingSeconds++);
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Unable to start recording',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Recording failed',
          type: SnackbarType.error,
        );
      }
      setState(() {
        _audioState = AudioState.idle;
        _recordingPath = null;
        _audioDuration = 0;
        _isRecordingPaused = false;
      });
      return;
    }
    setState(() {
      _audioState = AudioState.recorded;
      _recordingPath = path;
      _audioDuration = _recordingSeconds;
      _isRecordingPaused = false;
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    await _recorder.cancel();
    setState(() {
      _audioState = AudioState.idle;
      _recordingPath = null;
      _recordingSeconds = 0;
      _audioDuration = 0;
      _isRecordingPaused = false;
    });
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    _recordingTimer?.cancel();
    setState(() => _isRecordingPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
    setState(() => _isRecordingPaused = false);
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _recordingPath = result.files.first.path;
      _audioState = AudioState.recorded;
      _audioDuration = 0;
    });
  }

  Future<void> _uploadAudio() async {
    if (_recordingPath == null) return;
    setState(() => _audioState = AudioState.uploading);
    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final uploadResult = await cloudinary.upload(filePath: _recordingPath!);
      setState(() {
        _audioURL = uploadResult.secureUrl;
        _audioState = AudioState.uploaded;
      });
    } catch (e) {
      setState(() => _audioState = AudioState.recorded);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Audio upload failed',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _togglePreviewPlayback() async {
    if (_isLoadingAudio) return;
    if (_isPlayingPreview) {
      await _previewPlayer.stop();
      setState(() => _isPlayingPreview = false);
      return;
    }
    final source = _audioURL != null
        ? AudioSource.uri(Uri.parse(_audioURL!))
        : (_recordingPath != null ? AudioSource.file(_recordingPath!) : null);
    if (source == null) return;

    setState(() => _isLoadingAudio = true);
    try {
      await _previewPlayer.setAudioSource(source);
      _previewPlayer.play();
      if (mounted)
        setState(() {
          _isPlayingPreview = true;
          _isLoadingAudio = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingAudio = false);
      return;
    }
    _audioPlayerSub?.cancel();
    _audioPlayerSub = _previewPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _isPlayingPreview = false);
      }
    });
  }

  void _removeAudio() {
    setState(() {
      _audioState = AudioState.idle;
      _recordingPath = null;
      _audioURL = null;
      _audioDuration = 0;
    });
  }

  // ── Custom tags ──

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase().replaceAll(
      '#',
      '',
    );
    if (tag.isEmpty ||
        _customTags.contains(tag) ||
        _selectedHashtags.contains(tag))
      return;
    if (_selectedHashtags.length + _customTags.length >= 10) {
      AppSnackbar.show(
        context,
        message: 'Maximum 10 hashtags',
        type: SnackbarType.error,
      );
      return;
    }
    setState(() {
      _customTags.add(tag);
      _customTagController.clear();
    });
  }

  List<String> get _allHashtags => [..._selectedHashtags, ..._customTags];

  // ── Delete poem ──

  Future<void> _deletePoem() async {
    if (widget.poemId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete poem?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(poemRepoProvider).deletePoem(widget.poemId!);
      ref.read(myPoemsControllerProvider.notifier).removePoem(widget.poemId!);
      try {
        ref
            .read(homeFeedControllerProvider.notifier)
            .removePoem(widget.poemId!);
      } catch (_) {}
      try {
        ref
            .read(exploreFeedControllerProvider.notifier)
            .removePoem(widget.poemId!);
      } catch (_) {}
      try {
        ref
            .read(audioFeedControllerProvider.notifier)
            .removePoem(widget.poemId!);
      } catch (_) {}
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

  // ── Publish flow ──

  bool get _isValidToPublish =>
      _wordCount > 0 && _wordCount <= 150 && !_isPublishing;

  void _prepareDocumentForSave() {
    final doc = _quillController.document;
    String text = doc.toPlainText();
    int trimCount = 0;
    for (int i = text.length - 1; i >= 0; i--) {
      if (text[i] == '\n')
        trimCount++;
      else
        break;
    }
    if (trimCount > 1) {
      doc.delete(doc.length - trimCount, trimCount - 1);
    }
    final attr = _textAlign == 'center'
        ? Attribute.centerAlignment
        : (_textAlign == 'right'
              ? Attribute.rightAlignment
              : Attribute.leftAlignment);
    doc.format(0, doc.length, attr);
  }

  Future<void> _onDraft() async {
    if (_isPublishing) return;
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Write something first',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      _prepareDocumentForSave();
      await _submit(visibility: 'private');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _onPublish() async {
    if (_isPublishing) return;
    final plainText = _quillController.document.toPlainText().trim();

    if (plainText.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Write something first',
        type: SnackbarType.error,
      );
      return;
    }

    if (_wordCount > 150) {
      AppSnackbar.show(
        context,
        message: 'Poem exceeds 150 word limit',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      _prepareDocumentForSave();
      await _submit(visibility: 'public');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _submit({required String visibility}) async {
    // Upload audio if recorded but not uploaded
    if (_audioState == AudioState.recorded && _recordingPath != null) {
      await _uploadAudio();
      if (_audioState != AudioState.uploaded) return; // upload failed
    }

    final contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      final request = CreatePoemRequest(
        title: title.isEmpty ? 'Untitled Poem' : title,
        contentJson: contentJson,
        plainText: plainText,
        hashtags: _allHashtags,
        mood: '',
        isOriginal: _isOriginal,
        visibility: visibility,
        audioUrl: _audioURL ?? '',
        audioDuration: _audioDuration,
        coverColor: '',
        description: description,
        textAlign: _textAlign,
      );

      PoemModel poem;
      if (widget.poemId != null) {
        poem = await ref
            .read(poemRepoProvider)
            .updatePoem(widget.poemId!, request);
        ref.read(myPoemsControllerProvider.notifier).updatePoem(poem);
        if (poem.isPublic) {
          try {
            ref.read(homeFeedControllerProvider.notifier).updatePoemInFeed(poem);
          } catch (_) {}
          try {
            ref
                .read(exploreFeedControllerProvider.notifier)
                .updatePoemInFeed(poem);
          } catch (_) {}
          try {
            ref
                .read(audioFeedControllerProvider.notifier)
                .updatePoemInFeed(poem);
          } catch (_) {}
        } else {
          try {
            ref.read(homeFeedControllerProvider.notifier).removePoem(poem.id);
          } catch (_) {}
          try {
            ref.read(exploreFeedControllerProvider.notifier).removePoem(poem.id);
          } catch (_) {}
          try {
            ref.read(audioFeedControllerProvider.notifier).removePoem(poem.id);
          } catch (_) {}
        }
      } else {
        poem = await ref.read(poemRepoProvider).createPoem(request);
        ref.read(myPoemsControllerProvider.notifier).prependPoem(poem);
        if (poem.isPublic) {
          try {
            ref.read(homeFeedControllerProvider.notifier).prependPoem(poem);
          } catch (_) {}
          try {
            ref.read(exploreFeedControllerProvider.notifier).prependPoem(poem);
          } catch (_) {}
          if (poem.hasAudio) {
            try {
              ref.read(audioFeedControllerProvider.notifier).prependPoem(poem);
            } catch (_) {}
          }
        }
      }

      if (mounted) {
        setState(() => _currentPoem = poem);
        context.pop(poem);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _countDebounce?.cancel();
    _documentChangesSub?.cancel();
    _audioPlayerSub?.cancel();
    _toolbarHideTimer?.cancel();
    _recordingTimer?.cancel();
    _quillController.removeListener(_onSelectionChanged);
    _quillController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _customTagController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    _recorder.dispose();
    _previewPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(context),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              // Main scrollable content
              SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 40.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title field ──
                    _buildTitleField(context),

                    SizedBox(height: 16.h),
                    Divider(
                      indent: 20,
                      endIndent: 20,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),

                    // ── Poem body editor ──
                    _buildEditor(context),

                    // ── Word counter ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 8.h),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$_wordCount / 150',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: _wordCount > 150
                                ? Colors.red
                                : Theme.of(context).textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.6),
                            fontWeight: _wordCount > 150
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                    Divider(
                      indent: 20,
                      endIndent: 20,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),

                    // ── Description field ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                      child: MentionTextField(
                        controller: _descriptionController,
                        hintText:
                            'Add a description... use @username to mention',
                        maxLength: 200,
                      ),
                    ),

                    SizedBox(height: 16.h),
                    Divider(
                      indent: 20,
                      endIndent: 20,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),

                    // ── Original content checkbox ──
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isOriginal,
                            onChanged: (v) =>
                                setState(() => _isOriginal = v ?? false),
                            activeColor: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _isOriginal = !_isOriginal),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '© ',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'This is my original work',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppTheme.textDarkColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      indent: 20,
                      endIndent: 20,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),

                    // ── Genres / Hashtags ──
                    _buildHashtagSection(),

                    Divider(
                      indent: 20,
                      endIndent: 20,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),

                    // ── Audio section ──
                    _buildAudioSection(),

                    Divider(
                      indent: 20,
                      endIndent: 20,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.2),
                    ),

                    SizedBox(height: 24.h),

                    // ── Publish Button ──
                    _buildPublishButton(),

                    SizedBox(height: 60.h),
                  ],
                ),
              ),

              // Floating toolbar
              if (_showToolbar)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  top:
                      _toolbarTop ??
                      (MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          16),
                  left: 16,
                  right: 16,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: FloatingToolbar(
                          controller: _quillController,
                          savedSelection: _lastNonCollapsedSelection,
                        ),
                      ),
                    ),
                  ),
                ),

              // Loading overlay for publishing
              if (_isPublishing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(24.r),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) context.pop();
        },
      ),
      actions: [
        if (widget.poemId != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _deletePoem,
          ),

        // Alignment segmented control
        Container(
          margin: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _alignButton('left', Icons.format_align_left),
              _alignButton('center', Icons.format_align_center),
              _alignButton('right', Icons.format_align_right),
            ],
          ),
        ),

        SizedBox(width: 4.w),

        // Undo
        IconButton(
          icon: Icon(
            Icons.undo,
            color: _quillController.hasUndo
                ? null
                : Theme.of(context).iconTheme.color?.withValues(alpha: 0.3),
          ),
          tooltip: 'Undo',
          onPressed: _quillController.hasUndo
              ? () {
                  HapticFeedback.lightImpact();
                  _quillController.undo();
                }
              : null,
        ),

        // Redo
        IconButton(
          icon: Icon(
            Icons.redo,
            color: _quillController.hasRedo
                ? null
                : Theme.of(context).iconTheme.color?.withValues(alpha: 0.3),
          ),
          tooltip: 'Redo',
          onPressed: _quillController.hasRedo
              ? () {
                  HapticFeedback.lightImpact();
                  _quillController.redo();
                }
              : null,
        ),

        // Draft button (only for new or draft poems)
        if (widget.existingPoem == null || !widget.existingPoem!.isPublic)
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: TextButton(
              onPressed: _isPublishing ? null : _onDraft,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMediumColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                'Draft',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPublishButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: SizedBox(
        width: double.infinity,
        height: 52.h,
        child: ElevatedButton(
          onPressed: _isValidToPublish ? _onPublish : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: AppTheme.primaryColor.withValues(
              alpha: 0.3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            elevation: 0,
          ),
          child: Text(
            widget.poemId != null ? 'Update Poem' : 'Publish Poem',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _alignButton(String align, IconData icon) {
    final isActive = _textAlign == align;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _textAlign = align);
        final attr = align == 'center'
            ? Attribute.centerAlignment
            : (align == 'right'
                  ? Attribute.rightAlignment
                  : Attribute.leftAlignment);
        _quillController.formatText(0, _quillController.document.length, attr);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Icon(
          icon,
          size: 18.r,
          color: isActive ? AppTheme.primaryColor : AppTheme.textLightColor,
        ),
      ),
    );
  }

  Widget _buildTitleField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF5F0EB)
        : const Color(0xFF1A1A2E);

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        textAlign: _textAlignEnum,
        style: TextStyle(
          fontFamily: 'JosefinSans',
          fontSize: 28.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: 1.0,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: 'Title',
          hintStyle: TextStyle(
            fontFamily: 'JosefinSans',
            fontSize: 28.sp,
            fontWeight: FontWeight.w500,
            color: textColor.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
            letterSpacing: 1.0,
            height: 1.2,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _editorFocusNode.requestFocus(),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Container(
      key: _editorKey,
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 160.h),
        child: QuillEditor.basic(
          controller: _quillController,
          focusNode: _editorFocusNode,
          config: QuillEditorConfig(
            placeholder: 'Begin writing...',
            scrollable: false,
            expands: false,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            customStyles: DefaultStyles(
              paragraph: DefaultTextBlockStyle(
                TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 18.sp,
                  height: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const HorizontalSpacing(0, 0),
                const VerticalSpacing(0, 8),
                const VerticalSpacing(0, 0),
                null,
              ),
              placeHolder: DefaultTextBlockStyle(
                TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 18.sp,
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
      ),
    );
  }

  Widget _buildHashtagSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GENRES',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.textLightColor,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: kStaticHashtags.map((tag) {
              final selected = _selectedHashtags.contains(tag);
              return FilterChip(
                label: Text('#$tag'),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      if (_allHashtags.length < 10) _selectedHashtags.add(tag);
                    } else {
                      _selectedHashtags.remove(tag);
                    }
                  });
                },
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  fontSize: 13.sp,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textMediumColor,
                ),
                backgroundColor: AppTheme.featureBackgroundColor,
                side: BorderSide(
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                ),
              );
            }).toList(),
          ),

          // Custom tags
          if (_customTags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _customTags.map((tag) {
                return Chip(
                  label: Text('#$tag'),
                  deleteIcon: Icon(Icons.close, size: 16.r),
                  onDeleted: () => setState(() => _customTags.remove(tag)),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.primaryColor,
                  ),
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
          ],

          SizedBox(height: 10.h),

          // Custom tag input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  onSubmitted: (_) => _addCustomTag(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textDarkColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add your own tag...',
                    hintStyle: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textLightColor,
                    ),
                    prefixText: '# ',
                    prefixStyle: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textMediumColor,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    filled: true,
                    fillColor: AppTheme.featureBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: _addCustomTag,
                child: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 20.r),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VOICE / AUDIO',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.textLightColor,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10.h),
          _buildAudioContent(),
        ],
      ),
    );
  }

  Widget _buildAudioContent() {
    switch (_audioState) {
      case AudioState.idle:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startRecording,
                icon: Icon(
                  Icons.mic_rounded,
                  size: 18.r,
                  color: AppTheme.primaryColor,
                ),
                label: Text(
                  'Record',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textDarkColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: Icon(
                  Icons.upload_file_rounded,
                  size: 18.r,
                  color: AppTheme.primaryColor,
                ),
                label: Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textDarkColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ),
          ],
        );

      case AudioState.recording:
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _pulseAnimation.value,
                      child: Icon(Icons.circle, size: 12.r, color: Colors.red),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _cancelRecording,
                    icon: Icon(Icons.close, color: Colors.red, size: 28.r),
                    tooltip: 'Cancel',
                  ),
                  IconButton(
                    onPressed: _isRecordingPaused
                        ? _resumeRecording
                        : _pauseRecording,
                    icon: Icon(
                      _isRecordingPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: AppTheme.primaryColor,
                      size: 32.r,
                    ),
                    tooltip: _isRecordingPaused ? 'Resume' : 'Pause',
                  ),
                  IconButton(
                    onPressed: _stopRecording,
                    icon: Icon(
                      Icons.stop_rounded,
                      color: AppTheme.primaryColor,
                      size: 32.r,
                    ),
                    tooltip: 'Stop',
                  ),
                ],
              ),
            ],
          ),
        );

      case AudioState.recorded:
      case AudioState.uploading:
      case AudioState.uploaded:
        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _audioState == AudioState.uploading
                    ? null
                    : _togglePreviewPlayback,
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoadingAudio
                      ? Padding(
                          padding: EdgeInsets.all(10.r),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : Icon(
                          _isPlayingPreview
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 24.r,
                          color: AppTheme.primaryColor,
                        ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _audioState == AudioState.uploading
                          ? 'Uploading...'
                          : _audioState == AudioState.uploaded
                          ? 'Audio ready'
                          : 'Recorded',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkColor,
                      ),
                    ),
                    if (_audioDuration > 0)
                      Text(
                        '${_audioDuration ~/ 60}:${(_audioDuration % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textLightColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (_audioState == AudioState.uploading)
                SizedBox(
                  width: 20.r,
                  height: 20.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                )
              else
                IconButton(
                  onPressed: _removeAudio,
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20.r,
                  ),
                  tooltip: 'Remove audio',
                ),
            ],
          ),
        );
    }
  }
}
