import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/chat/models/message_type.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/chat/screens/widgets/full_screen_image_viewer.dart';
import 'package:chatbee/features/chat/screens/widgets/full_screen_video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

final _dio = Dio();

/// Wraps media content in a standardized bubble format.
class MediaBubble extends StatelessWidget {
  final MessageResponse message;
  final bool isMe;

  const MediaBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    switch (message.messageType) {
      case MessageType.image:
        return _ImageBubble(message: message, isMe: isMe);
      case MessageType.video:
        return _VideoBubble(message: message, isMe: isMe);
      case MessageType.file:
        return _FileBubble(message: message, isMe: isMe);
      case MessageType.audio:
        return _AudioBubble(message: message, isMe: isMe);
      case MessageType.gif:
        return _GifBubble(message: message, isMe: isMe);
      case MessageType.link:
      case MessageType.text:
        // Fallback for types not yet fully implemented or erroneously passed here
        return Text(
          '[${message.messageType.name}] ${message.metadata?.fileName ?? ""}',
          style: TextStyle(
            fontSize: 14.sp,
            color: isMe ? Colors.white : AppTheme.textDarkColor,
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }
}

class _ImageBubble extends StatelessWidget {
  final MessageResponse message;
  final bool isMe;

  const _ImageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isUploading = message.status == 'uploading';
    // When uploading, message.content holds the local file path
    final isLocal = isUploading && !message.content.startsWith('http');

    return GestureDetector(
      onTap: () {
        if (isUploading) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              urlOrPath: message.content,
              isLocal: isLocal,
              heroTag: 'image_${message.id}',
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Hero(
            tag: 'image_${message.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: isLocal
                  ? Image.file(
                      File(message.content),
                      width: 220.w,
                      height: _calculateHeight(),
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: message.content,
                      width: 220.w,
                      height: _calculateHeight(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 220.w,
                        height: _calculateHeight(),
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: isMe ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 220.w,
                        height: _calculateHeight(),
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppTheme.textMediumColor,
                          size: 40.sp,
                        ),
                      ),
                    ),
            ),
          ),
          if (isUploading)
            Container(
              width: 220.w,
              height: _calculateHeight(),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateHeight() {
    final meta = message.metadata;
    if (meta?.width != null && meta?.height != null && meta!.width! > 0) {
      final ratio = meta.height! / meta.width!;
      return (220.w * ratio).clamp(100.h, 400.h);
    }
    // If we don't know the size, return null to let the widget decide (contain/cover)
    // or return a reasonable default that isn't always square.
    return 220.w;
  }
}

class _VideoBubble extends StatelessWidget {
  final MessageResponse message;
  final bool isMe;

  const _VideoBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isUploading = message.status == 'uploading';
    final duration = message.metadata?.duration ?? 0;

    // Format duration from seconds to MM:SS
    final minutes = (duration / 60).floor().toString().padLeft(2, '0');
    final seconds = (duration % 60).floor().toString().padLeft(2, '0');

    final isLocal = isUploading && !message.content.startsWith('http');

    return GestureDetector(
      onTap: () {
        if (isUploading) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenVideoPlayer(
              urlOrPath: message.content,
              isLocal: isLocal,
            ),
          ),
        );
      },
      child: Container(
        width: 220.w,
        height: 220.w,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: _buildThumbnail(
                message.content,
                message.metadata?.thumbnailURL,
              ),
            ),

            // Play icon overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white.withValues(alpha: isUploading ? 0.3 : 0.9),
                size: 64.sp,
              ),
            ),

            if (isUploading)
              const CircularProgressIndicator(color: Colors.white),

            // Duration badge
            Positioned(
              bottom: 8.h,
              right: 8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '$minutes:$seconds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String videoUrl, String? thumbnailUrl) {
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        width: 220.w,
        height: 220.w,
        fit: BoxFit.cover,
      );
    }

    // Attempt to generate Cloudinary thumbnail URL if it's a Cloudinary link
    if (videoUrl.contains('cloudinary.com/')) {
      final thumbUrl = videoUrl.replaceAll(
        '/video/upload/',
        '/video/upload/so_auto,c_fill,h_400,w_400/',
      );
      // Replace extension to jpg for better compatibility as a thumbnail
      final jpgThumbUrl = thumbUrl.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg');

      return CachedNetworkImage(
        imageUrl: jpgThumbUrl,
        width: 220.w,
        height: 220.w,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.black87),
        errorWidget: (context, url, error) => Container(color: Colors.black87),
      );
    }

    return Container(color: Colors.black87);
  }
}

class _GifBubble extends StatelessWidget {
  final MessageResponse message;
  final bool isMe;

  const _GifBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: CachedNetworkImage(
        imageUrl: message.content,
        width: 220.w,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: 220.w,
          height: 150.h,
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: 220.w,
          height: 150.h,
          color: Colors.grey.withValues(alpha: 0.1),
          child: Icon(
            Icons.broken_image_rounded,
            color: AppTheme.textMediumColor,
          ),
        ),
      ),
    );
  }
}

class _FileBubble extends StatefulWidget {
  final MessageResponse message;
  final bool isMe;

  const _FileBubble({required this.message, required this.isMe});

  @override
  State<_FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends State<_FileBubble> {
  bool _isDownloading = false;

  Future<void> _handleTap() async {
    final isUploading = widget.message.status == 'uploading';
    final pathOrUrl = widget.message.content;

    if (isUploading) {
      if (!pathOrUrl.startsWith('http')) {
        await OpenFilex.open(pathOrUrl);
      }
      return;
    }

    try {
      setState(() {
        _isDownloading = true;
      });

      final dir = await getTemporaryDirectory();
      final fileName = widget.message.metadata?.fileName ?? 'downloaded_file';
      final savePath = '${dir.path}/${widget.message.id}_$fileName';
      final file = File(savePath);

      if (!await file.exists()) {
        await _dio.download(pathOrUrl, savePath);
      }

      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint('Error downloading/opening file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.message.metadata?.fileName ?? 'Unknown file';
    final fileSize = widget.message.metadata?.fileSize ?? 0;

    // Format file size
    String sizeStr;
    if (fileSize < 1024) {
      sizeStr = '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      sizeStr = '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      sizeStr = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    final isUploading = widget.message.status == 'uploading';

    return GestureDetector(
      onTap: _isDownloading ? null : _handleTap,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.borderColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              child: _isDownloading
                  ? SizedBox(
                      width: 24.sp,
                      height: 24.sp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMe
                            ? Colors.white
                            : AppTheme.primaryColor,
                      ),
                    )
                  : Icon(
                      Icons.insert_drive_file_rounded,
                      color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                      size: 24.sp,
                    ),
            ),
            SizedBox(width: 12.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: widget.isMe
                          ? Colors.white
                          : AppTheme.textDarkColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    isUploading
                        ? 'Uploading...'
                        : _isDownloading
                        ? 'Downloading...'
                        : sizeStr,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: widget.isMe
                          ? Colors.white70
                          : AppTheme.textMediumColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  final MessageResponse message;
  final bool isMe;

  const _AudioBubble({required this.message, required this.isMe});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  AudioPlayer? _playerInstance;
  AudioPlayer get _player => _playerInstance ??= AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initAudio() async {
    try {
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _player.seek(Duration.zero);
              _player.pause();
            }
          });
        }
      });

      _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _duration = d);
      });

      _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  bool _isLoaded = false;
  Future<void> _loadAndPlay() async {
    try {
      await _initAudio();
      if (!_isLoaded) {
        final isLocal =
            widget.message.status == 'uploading' &&
            !widget.message.content.startsWith('http');
        if (isLocal) {
          await _player.setFilePath(widget.message.content);
        } else {
          await _player.setUrl(widget.message.content);
        }
        _isLoaded = true;
      }
      _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  @override
  void dispose() {
    _playerInstance?.stop();
    _playerInstance?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.15)
            : AppTheme.borderColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.isMe ? Colors.white : AppTheme.primaryColor,
              size: 32.sp,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _loadAndPlay();
              }
            },
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: SizedBox(
              width: 120.w,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble(),
                  min: 0,
                  max: _duration.inMilliseconds > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1,
                  activeColor: widget.isMe
                      ? Colors.white
                      : AppTheme.primaryColor,
                  inactiveColor: widget.isMe
                      ? Colors.white38
                      : Colors.grey.shade300,
                  onChanged: (val) {
                    _player.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            widget.message.status == 'uploading'
                ? '...'
                : '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: TextStyle(
              fontSize: 10.sp,
              color: widget.isMe ? Colors.white70 : AppTheme.textMediumColor,
            ),
          ),
        ],
      ),
    );
  }
}
