import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? senderName;
  final String? senderPhotoUrl;

  const MediaBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.senderName,
    this.senderPhotoUrl,
  });

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
        return _AudioBubble(
          message: message,
          isMe: isMe,
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
        );
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

class _ImageBubble extends StatefulWidget {
  final MessageResponse message;
  final bool isMe;

  const _ImageBubble({required this.message, required this.isMe});

  @override
  State<_ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<_ImageBubble> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();
  }

  Future<void> _checkIfDownloaded() async {
    final dir = await getTemporaryDirectory();
    final fileName = widget.message.metadata?.fileName ?? 'image_${widget.message.id}.jpg';
    final savePath = '${dir.path}/${widget.message.id}_$fileName';
    final file = File(savePath);
    if (await file.exists()) {
      setState(() => _isDownloaded = true);
    }
  }

  Future<void> _handleDownload() async {
    if (_isDownloaded) return;

    final isUploading = widget.message.status == 'uploading';
    final imageUrl = widget.message.content;

    if (isUploading || !imageUrl.startsWith('http')) return;

    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final dir = await getTemporaryDirectory();
      final fileName = widget.message.metadata?.fileName ?? 'image_${widget.message.id}.jpg';
      final savePath = '${dir.path}/${widget.message.id}_$fileName';
      final file = File(savePath);

      if (!await file.exists()) {
        // For Cloudinary URLs, add download=true parameter and proper headers
        var downloadUrl = imageUrl;
        if (downloadUrl.contains('cloudinary.com')) {
          // Add download flag for Cloudinary
          downloadUrl = '$downloadUrl?download=true';
        }

        await _dio.download(
          downloadUrl,
          savePath,
          options: Options(
            headers: {
              'Accept': '*/*',
            },
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          },
        );
      }

      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
      });
    } catch (e) {
      debugPrint('Error downloading image: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  void _handleTap() {
    final isUploading = widget.message.status == 'uploading';
    if (isUploading) return;

    final isLocal = isUploading && !widget.message.content.startsWith('http');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          urlOrPath: widget.message.content,
          isLocal: isLocal,
          heroTag: 'image_${widget.message.id}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = widget.message.status == 'uploading';
    final isLocal = isUploading && !widget.message.content.startsWith('http');
    final showDownload = !isUploading && !isLocal && !_isDownloaded;

    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Hero(
            tag: 'image_${widget.message.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: isLocal
                  ? Image.file(
                      File(widget.message.content),
                      width: 220.w,
                      height: _calculateHeight(),
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.message.content,
                      width: 220.w,
                      height: _calculateHeight(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 220.w,
                        height: _calculateHeight(),
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: widget.isMe ? Colors.white : AppTheme.primaryColor,
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
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          // Download button overlay
          if (showDownload && !_isDownloading)
            Positioned(
              right: 8.w,
              bottom: 8.h,
              child: GestureDetector(
                onTap: _handleDownload,
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
              ),
            ),
          // Download progress ring
          if (_isDownloading)
            Positioned(
              right: 8.w,
              bottom: 8.h,
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      Center(
                        child: Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateHeight() {
    final meta = widget.message.metadata;
    if (meta?.width != null && meta?.height != null && meta!.width! > 0) {
      final ratio = meta.height! / meta.width!;
      return (220.w * ratio).clamp(100.h, 400.h);
    }
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
      borderRadius: BorderRadius.circular(4.r), // Reduced from 12.r for tighter WhatsApp-style
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
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();
  }

  Future<void> _checkIfDownloaded() async {
    final dir = await getTemporaryDirectory();
    final fileName = widget.message.metadata?.fileName ?? 'downloaded_file';
    final savePath = '${dir.path}/${widget.message.id}_$fileName';
    final file = File(savePath);
    if (await file.exists()) {
      setState(() => _isDownloaded = true);
    }
  }

  Future<void> _handleDownload() async {
    if (_isDownloaded) {
      await _openFile();
      return;
    }

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
        _downloadProgress = 0.0;
      });

      final dir = await getTemporaryDirectory();
      final fileName = widget.message.metadata?.fileName ?? 'downloaded_file';
      final savePath = '${dir.path}/${widget.message.id}_$fileName';
      final file = File(savePath);

      if (!await file.exists()) {
        // For Cloudinary URLs, add download=true parameter and proper headers
        var downloadUrl = pathOrUrl;
        if (downloadUrl.contains('cloudinary.com')) {
          // Add download flag for Cloudinary
          downloadUrl = '$downloadUrl?download=true';
        }

        await _dio.download(
          downloadUrl,
          savePath,
          options: Options(
            headers: {
              'Accept': '*/*',
            },
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
          },
        );
      }

      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
      });

      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint('Error downloading file: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _openFile() async {
    final dir = await getTemporaryDirectory();
    final fileName = widget.message.metadata?.fileName ?? 'downloaded_file';
    final savePath = '${dir.path}/${widget.message.id}_$fileName';
    await OpenFilex.open(savePath);
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.message.metadata?.fileName ?? 'Unknown file';
    final fileSize = widget.message.metadata?.fileSize ?? 0;
    final thumbnailUrl = widget.message.metadata?.thumbnailURL;

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
    final hasPreview = thumbnailUrl != null && !isUploading;
    final ext = fileName.split('.').last.toUpperCase();

    // WhatsApp-style file bubble
    return GestureDetector(
      onTap: _handleDownload,
      child: Container(
        width: 240.w,
        decoration: BoxDecoration(
          color: widget.isMe
              ? AppTheme.primaryColor
              : AppTheme.featureBackgroundColor,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: hasPreview
            ? _buildPreviewLayout(thumbnailUrl, fileName, sizeStr, ext, isUploading)
            : _buildNoPreviewLayout(fileName, sizeStr, ext, isUploading),
      ),
    );
  }

  Widget _buildPreviewLayout(String thumbnailUrl, String fileName, String sizeStr, String ext, bool isUploading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail with dark overlay at bottom
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                width: 240.w,
                height: 180.h,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 240.w,
                  height: 180.h,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 240.w,
                  height: 180.h,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 40.sp,
                  ),
                ),
              ),
            ),
            // Dark gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(4.r)),
                ),
              ),
            ),
            // Download button overlay (if not downloaded)
            if (!_isDownloaded && !isUploading && !_isDownloading)
              Positioned(
                right: 8.w,
                top: 8.h,
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
            // Download progress ring
            if (_isDownloading)
              Positioned(
                right: 8.w,
                top: 8.h,
                child: SizedBox(
                  width: 32.r,
                  height: 32.r,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      Center(
                        child: Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // File info section with dark background
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filename
              Text(
                fileName,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: widget.isMe ? Colors.white : AppTheme.textDarkColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              // File details: pages • size • type
              Row(
                children: [
                  Text(
                    sizeStr,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: widget.isMe ? Colors.white70 : AppTheme.textMediumColor,
                    ),
                  ),
                  Text(
                    ' • ',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: widget.isMe ? Colors.white70 : AppTheme.textMediumColor,
                    ),
                  ),
                  Text(
                    ext,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: widget.isMe ? Colors.white70 : AppTheme.textMediumColor,
                    ),
                  ),
                ],
              ),
              // Timestamp at bottom right
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.message.createdAt != null)
                      Text(
                        '${widget.message.createdAt!.hour.toString().padLeft(2, '0')}:${widget.message.createdAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: widget.isMe ? Colors.white60 : AppTheme.textLightColor,
                        ),
                      ),
                    if (widget.isMe) ...[
                      SizedBox(width: 3.w),
                      _buildReadStatus(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoPreviewLayout(String fileName, String sizeStr, String ext, bool isUploading) {
    return Padding(
      padding: EdgeInsets.all(12.r),
      child: Row(
        children: [
          // File icon in circle
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: _isDownloading
                ? _buildDownloadProgressRing()
                : (!_isDownloaded && !isUploading)
                    ? Icon(
                        Icons.download_rounded,
                        color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                        size: 24.sp,
                      )
                    : Icon(
                        _getFileIcon(fileName),
                        color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                        size: 24.sp,
                      ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: widget.isMe ? Colors.white : AppTheme.textDarkColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      isUploading
                          ? 'Uploading...'
                          : _isDownloading
                          ? '${(_downloadProgress * 100).toInt()}%'
                          : sizeStr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: widget.isMe ? Colors.white70 : AppTheme.textMediumColor,
                      ),
                    ),
                    if (!isUploading && !_isDownloading)
                      Text(
                        ' • $ext',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: widget.isMe ? Colors.white70 : AppTheme.textMediumColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Timestamp and status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message.createdAt != null)
                Text(
                  '${widget.message.createdAt!.hour.toString().padLeft(2, '0')}:${widget.message.createdAt!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: widget.isMe ? Colors.white60 : AppTheme.textLightColor,
                  ),
                ),
              if (widget.isMe) ...[
                SizedBox(width: 3.w),
                _buildReadStatus(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgressRing() {
    return SizedBox(
      width: 24.r,
      height: 24.r,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
            strokeWidth: 2.5,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isMe ? Colors.white : AppTheme.primaryColor,
            ),
          ),
          Center(
            child: Icon(
              Icons.download_rounded,
              color: widget.isMe ? Colors.white : AppTheme.primaryColor,
              size: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadStatus() {
    if (widget.message.status == 'read') {
      return Icon(
        Icons.done_all,
        size: 14.r,
        color: const Color(0xFF53BDEB),
      );
    } else if (widget.message.status == 'delivered') {
      return Icon(
        Icons.done_all,
        size: 14.r,
        color: Colors.white.withValues(alpha: 0.6),
      );
    } else {
      return Icon(
        Icons.check,
        size: 14.r,
        color: Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

// Global audio controller to manage single playback
class _AudioController {
  static final _AudioController _instance = _AudioController._internal();
  factory _AudioController() => _instance;
  _AudioController._internal();

  final Set<String> _playingMessages = {};
  final Map<String, VoidCallback> _pauseCallbacks = {};

  void register(String messageId, VoidCallback onPauseOthers) {
    _pauseCallbacks[messageId] = onPauseOthers;
  }

  void unregister(String messageId) {
    _pauseCallbacks.remove(messageId);
    _playingMessages.remove(messageId);
  }

  void play(String messageId) {
    // Pause all other playing messages
    for (final id in _playingMessages.toList()) {
      if (id != messageId) {
        _pauseCallbacks[id]?.call();
      }
    }
    _playingMessages.clear();
    _playingMessages.add(messageId);
  }

  void pause(String messageId) {
    _playingMessages.remove(messageId);
  }

  bool isPlaying(String messageId) => _playingMessages.contains(messageId);
}

final _audioController = _AudioController();

class _AudioBubble extends StatefulWidget {
  final MessageResponse message;
  final bool isMe;
  final String? senderName;
  final String? senderPhotoUrl;

  const _AudioBubble({
    required this.message,
    required this.isMe,
    this.senderName,
    this.senderPhotoUrl,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _audioController.register(widget.message.id, _pauseOthers);
    _initAudio();
  }

  void _pauseOthers() {
    if (mounted && _isPlaying) {
      _player?.pause();
    }
  }

  Future<void> _initAudio() async {
    if (_player != null || _isDisposed) return;
    
    try {
      _player = AudioPlayer();
      
      _player!.playerStateStream.listen((state) {
        if (_isDisposed || !mounted) return;
        
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _audioController.pause(widget.message.id);
            _player?.seek(Duration.zero);
            _player?.pause();
          }
        });
        
        if (state.playing) {
          _audioController.play(widget.message.id);
        } else {
          _audioController.pause(widget.message.id);
        }
      });

      _player!.durationStream.listen((d) {
        if (!_isDisposed && mounted && d != null) {
          setState(() => _duration = d);
        }
      });

      _player!.positionStream.listen((p) {
        if (!_isDisposed && mounted) {
          setState(() => _position = p);
        }
      });

      // Pre-load the audio to get duration - don't await to avoid Future completion issues
      final isLocal = widget.message.status == 'uploading' &&
          !widget.message.content.startsWith('http');
      if (isLocal) {
        _player!.setFilePath(widget.message.content).catchError((e) {
          if (!_isDisposed) debugPrint('Error setting file path: $e');
          return null;
        });
      } else {
        _player!.setUrl(widget.message.content).catchError((e) {
          if (!_isDisposed) debugPrint('Error setting URL: $e');
          return null;
        });
      }
    } on PlatformException catch (e) {
      // Ignore "abort" errors from widget disposal during loading
      if (e.code != 'abort' && !_isDisposed) {
        debugPrint('Error loading audio: $e');
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Error loading audio: $e');
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_player == null || _isDisposed) return;
    try {
      if (_isPlaying) {
        await _player!.pause();
        _audioController.pause(widget.message.id);
      } else {
        await _player!.play();
        _audioController.play(widget.message.id);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioController.unregister(widget.message.id);
    _player?.stop();
    _player?.dispose();
    _player = null;
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: widget.isMe 
            ? AppTheme.primaryColor 
            : AppTheme.featureBackgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
          bottomLeft: Radius.circular(widget.isMe ? 16.r : 4.r),
          bottomRight: Radius.circular(widget.isMe ? 4.r : 16.r),
        ),
      ),
      child: Row(
        children: [
          // User Avatar with Mic overlay (WhatsApp style)
          Stack(
            children: [
              // Avatar - show sender photo or first letter of name
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  image: widget.senderPhotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(widget.senderPhotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.senderPhotoUrl == null
                    ? Center(
                        child: Text(
                          _getInitials(widget.senderName),
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: widget.isMe ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      )
                    : null,
              ),
              // Mic icon overlay at bottom right
              Positioned(
                right: -2.w,
                bottom: -2.h,
                child: Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    color: widget.isMe 
                        ? AppTheme.primaryColor
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isMe 
                          ? AppTheme.primaryColor
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 12.r,
                    color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: widget.isMe 
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? Colors.white : AppTheme.primaryColor,
                size: 20.r,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          
          // Waveform visualization
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bars
                SizedBox(
                  height: 26.h,
                  child: _buildWaveform(),
                ),
                SizedBox(height: 4.h),
                // Duration and timestamp row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.message.status == 'uploading'
                          ? '...'
                          : _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: widget.isMe 
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.textMediumColor,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.message.createdAt != null)
                          Text(
                            '${widget.message.createdAt!.hour.toString().padLeft(2, '0')}:${widget.message.createdAt!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: widget.isMe 
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppTheme.textLightColor,
                            ),
                          ),
                        if (widget.isMe) ...[
                          SizedBox(width: 4.w),
                          _buildReadStatus(),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    final barCount = 28;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    final activeBars = (barCount * progress).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(barCount, (index) {
        // Generate pseudo-random heights based on index
        final heights = [8, 14, 10, 18, 12, 16, 8, 20, 14, 10, 16, 8, 18, 12, 
                        20, 10, 14, 8, 16, 12, 18, 10, 14, 8, 16, 12, 20, 10];
        final height = heights[index % heights.length].h;
        final isActive = index <= activeBars;
        final isCurrent = index == activeBars && _isPlaying;

        return Container(
          width: 3.w,
          height: height,
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF53BDEB) // Blue dot for current position
                : isActive
                    ? (widget.isMe 
                        ? const Color(0xFF53BDEB) // Blue for played portion
                        : AppTheme.primaryColor)
                    : (widget.isMe 
                        ? Colors.white.withValues(alpha: 0.3) // White for unplayed
                        : Colors.grey.shade400),
            borderRadius: BorderRadius.circular(2.r),
          ),
        );
      }),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  Widget _buildReadStatus() {
    if (widget.message.status == 'read') {
      return Icon(
        Icons.done_all,
        size: 14.r,
        color: const Color(0xFF53BDEB), // Blue checkmarks for read
      );
    } else if (widget.message.status == 'delivered') {
      return Icon(
        Icons.done_all,
        size: 14.r,
        color: Colors.white.withValues(alpha: 0.6),
      );
    } else {
      return Icon(
        Icons.check,
        size: 14.r,
        color: Colors.white.withValues(alpha: 0.6),
      );
    }
  }
}
