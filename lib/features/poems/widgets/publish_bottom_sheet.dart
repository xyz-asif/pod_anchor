import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

// ── Static hashtag chips — the fixed set ──
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

// ── Mood options — same as backend ValidMoods ──
const List<String> kMoods = [
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

/// Audio state for the recording section
enum AudioState { idle, recording, recorded, uploading, uploaded }

/// Call this function to show the bottom sheet.
/// Returns a PoemModel if the poem was saved, null if dismissed.
Future<PoemModel?> showPublishBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String contentJson,
  required String plainText,
  required String coverColor,
  String? existingPoemId, // non-null when editing an existing poem
  PoemModel? existingPoem, // pass to pre-fill fields when editing
}) {
  return showModalBottomSheet<PoemModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PublishBottomSheet(
      ref: ref,
      title: title,
      contentJson: contentJson,
      plainText: plainText,
      coverColor: coverColor,
      existingPoemId: existingPoemId,
      existingPoem: existingPoem,
    ),
  );
}

class PublishBottomSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final String title;
  final String contentJson;
  final String plainText;
  final String coverColor;
  final String? existingPoemId;
  final PoemModel? existingPoem;

  const PublishBottomSheet({
    super.key,
    required this.ref,
    required this.title,
    required this.contentJson,
    required this.plainText,
    required this.coverColor,
    this.existingPoemId,
    this.existingPoem,
  });

  @override
  ConsumerState<PublishBottomSheet> createState() => _PublishBottomSheetState();
}

class _PublishBottomSheetState extends ConsumerState<PublishBottomSheet>
    with SingleTickerProviderStateMixin {
  // ── Hashtag state ──
  final Set<String> _selectedHashtags = {};
  final TextEditingController _customTagController = TextEditingController();
  final List<String> _customTags = [];

  // ── Mood state ──
  String? _selectedMood;

  // ── Copyright state ──
  bool _isOriginal = false;

  // ── Audio state ──
  AudioState _audioState = AudioState.idle;
  String? _recordingPath; // local file path after recording
  String? _audioURL; // Cloudinary URL after upload
  int _audioDuration = 0; // seconds
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlayingPreview = false;
  bool _isRecordingPaused = false;
  bool _isLoadingAudio = false;
  StreamSubscription? _audioPlayerSub;

  // pulse animation (recording indicator)
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ── Submit state ──
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill if editing
    if (widget.existingPoem != null) {
      final p = widget.existingPoem!;
      _selectedHashtags.addAll(
        p.hashtags.where((t) => kStaticHashtags.contains(t)),
      );
      _customTags.addAll(p.hashtags.where((t) => !kStaticHashtags.contains(t)));
      _selectedMood = p.mood.isEmpty ? null : p.mood;
      _isOriginal = p.isOriginal;
      if (p.hasAudio) {
        _audioURL = p.audioUrl;
        _audioDuration = p.audioDuration;
        _audioState = AudioState.uploaded;
      }
    }

    // Pulsing animation for recording indicator dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _customTagController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _audioPlayerSub?.cancel();
    _previewPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Recording ──

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted)
        AppSnackbar.show(
          context,
          message: 'Microphone permission denied',
          type: SnackbarType.error,
        );
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
      if (mounted)
        AppSnackbar.show(
          context,
          message: 'Unable to start recording. Please try again.',
          type: SnackbarType.error,
        );
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();

    if (path == null || path.isEmpty) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Recording failed. Please try again.',
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

    final file = result.files.first;
    setState(() {
      _recordingPath = file.path;
      _audioState = AudioState.recorded;
      _audioDuration = 0; // duration unknown until uploaded
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
      if (mounted)
        AppSnackbar.show(
          context,
          message: 'Audio upload failed. Try again.',
          type: SnackbarType.error,
        );
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

    if (source == null) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No audio available to play',
          type: SnackbarType.error,
        );
      }
      return;
    }

    setState(() => _isLoadingAudio = true);

    try {
      await _previewPlayer.setAudioSource(source);
      _previewPlayer.play();
      if (mounted) {
        setState(() {
          _isPlayingPreview = true;
          _isLoadingAudio = false;
        });
      }
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

  // ── Custom tag input ──

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

  // ── Submit ──

  Future<void> _submit(String visibility) async {
    // If audio is recorded but not uploaded yet, upload first
    if (_audioState == AudioState.recorded && _recordingPath != null) {
      await _uploadAudio();
      if (_audioState != AudioState.uploaded) return; // upload failed
    }

    setState(() => _isSubmitting = true);

    try {
      final request = CreatePoemRequest(
        title: widget.title,
        contentJson: widget.contentJson,
        plainText: widget.plainText,
        hashtags: _allHashtags,
        mood: _selectedMood ?? '',
        isOriginal: _isOriginal,
        visibility: visibility,
        audioUrl: _audioURL ?? '',
        audioDuration: _audioDuration,
        coverColor: widget.coverColor,
      );

      PoemModel poem;
      if (widget.existingPoemId != null) {
        poem = await ref
            .read(poemRepoProvider)
            .updatePoem(widget.existingPoemId!, request);
        ref.read(myPoemsControllerProvider.notifier).updatePoem(poem);
        try { ref.read(homeFeedControllerProvider.notifier).updatePoemInFeed(poem); } catch (_) {}
        try { ref.read(exploreFeedControllerProvider.notifier).updatePoemInFeed(poem); } catch (_) {}
      } else {
        poem = await ref.read(poemRepoProvider).createPoem(request);
        ref.read(myPoemsControllerProvider.notifier).prependPoem(poem);
        try { ref.read(homeFeedControllerProvider.notifier).prependPoem(poem); } catch (_) {}
        try { ref.read(exploreFeedControllerProvider.notifier).prependPoem(poem); } catch (_) {}
      }

      if (mounted) Navigator.of(context).pop(poem);
    } catch (e) {
      if (mounted)
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isSubmitting) {
          AppSnackbar.show(context, message: 'Please wait...', type: SnackbarType.error);
        }
      },
      child: DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  child: Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 8.h,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.existingPoemId != null
                          ? 'Update poem'
                          : 'Publish poem',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDarkColor,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: AppTheme.borderColor),
                // Scrollable content — Flexible instead of Expanded
                Flexible(
                  child: ListView(
                    controller: scrollController,
                    shrinkWrap: false,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                    children: [
                      // ── Hashtags ──
                      _SectionLabel('Hashtags'),
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
                                  if (_allHashtags.length < 10)
                                    _selectedHashtags.add(tag);
                                } else {
                                  _selectedHashtags.remove(tag);
                                }
                              });
                            },
                            selectedColor: AppTheme.primaryColor.withOpacity(
                              0.15,
                            ),
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

                      // Custom tags added by user
                      if (_customTags.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _customTags.map((tag) {
                            return Chip(
                              label: Text('#$tag'),
                              deleteIcon: Icon(Icons.close, size: 16.r),
                              onDeleted: () =>
                                  setState(() => _customTags.remove(tag)),
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.1),
                              labelStyle: TextStyle(
                                fontSize: 13.sp,
                                color: AppTheme.primaryColor,
                              ),
                              side: BorderSide(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      SizedBox(height: 10.h),

                      // Custom hashtag input
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
                                  borderSide: BorderSide(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(
                                    color: AppTheme.borderColor,
                                  ),
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
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20.r,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24.h),

                      // ── Audio Section ──
                      _SectionLabel('Voice / Audio (optional)'),
                      SizedBox(height: 10.h),
                      _buildAudioSection(),

                      SizedBox(height: 24.h),

                      // ── Copyright ──
                      Row(
                        children: [
                          Checkbox(
                            value: _isOriginal,
                            onChanged: (v) =>
                                setState(() => _isOriginal = v ?? false),
                            activeColor: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 8.w),
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

                      SizedBox(height: 24.h),

                      // ── Action Buttons ──
                      Row(
                        children: [
                          // Draft button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submit('private'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                side: BorderSide(color: AppTheme.borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                'Save Draft',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  color: AppTheme.textMediumColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submit('public'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 20.r,
                                      height: 20.r,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.existingPoemId != null
                                          ? 'Update'
                                          : 'Publish',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 24.h,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildAudioSection() {
    Widget content;
    switch (_audioState) {
      case AudioState.idle:
        content = SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              // Record button
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
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Upload button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAudioFile,
                  icon: Icon(
                    Icons.upload_file_rounded,
                    size: 18.r,
                    color: AppTheme.textMediumColor,
                  ),
                  label: Text(
                    'Upload',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textMediumColor,
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
          ),
        );
        break;

      case AudioState.recording:
        content = Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Cancel
              GestureDetector(
                onTap: _cancelRecording,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Icon(Icons.delete_outline_rounded, size: 24.r, color: Colors.redAccent),
                ),
              ),
              
              // Center: Timer & Status
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Container(
                          width: 8.r, height: 8.r,
                          decoration: BoxDecoration(
                            color: (_isRecordingPaused ? Colors.orange : Colors.red)
                                .withValues(alpha: _isRecordingPaused ? 0.7 : _pulseAnimation.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _formatDuration(_recordingSeconds),
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDarkColor,
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _isRecordingPaused ? 'Paused' : 'Recording',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.textLightColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              // Right: Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pause / Resume
                  GestureDetector(
                    onTap: _isRecordingPaused ? _resumeRecording : _pauseRecording,
                    child: Container(
                      width: 40.r, height: 40.r,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecordingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: AppTheme.primaryColor, size: 20.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Stop / Done
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Container(
                      width: 40.r, height: 40.r,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.stop_rounded, color: Colors.white, size: 20.r),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        break;
      case AudioState.recorded:
        content = SizedBox(
          width: double.infinity,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppTheme.featureBackgroundColor,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePreviewPlayback,
                  icon: _isLoadingAudio
                      ? SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                        )
                      : Icon(
                          _isPlayingPreview
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          size: 36.r,
                          color: AppTheme.primaryColor,
                        ),
                  padding: EdgeInsets.zero,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio recorded',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textDarkColor,
                        ),
                      ),
                      if (_audioDuration > 0)
                        Text(
                          _formatDuration(_audioDuration),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _removeAudio,
                  child: Text(
                    'Remove',
                    style: TextStyle(fontSize: 13.sp, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case AudioState.uploading:
        content = SizedBox(
          width: double.infinity,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppTheme.featureBackgroundColor,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20.r,
                  height: 20.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Uploading audio...',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case AudioState.uploaded:
        content = SizedBox(
          width: double.infinity,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _togglePreviewPlayback,
                  icon: _isLoadingAudio
                      ? SizedBox(
                          width: 24.r,
                          height: 24.r,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                        )
                      : Icon(
                          _isPlayingPreview
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          size: 36.r,
                          color: Colors.green,
                        ),
                  padding: EdgeInsets.zero,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14.r,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Audio ready',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (_audioDuration > 0)
                        Text(
                          _formatDuration(_audioDuration),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _removeAudio,
                  child: Text(
                    'Remove',
                    style: TextStyle(fontSize: 13.sp, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
    }

    return content;
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.textLightColor,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: AppTheme.borderColor),
        ),
      ],
    );
  }
}
