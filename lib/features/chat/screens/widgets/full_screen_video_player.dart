import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String urlOrPath;
  final bool isLocal;

  const FullScreenVideoPlayer({
    super.key,
    required this.urlOrPath,
    required this.isLocal,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.isLocal) {
        _videoPlayerController = VideoPlayerController.file(
          File(widget.urlOrPath),
        );
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.urlOrPath),
        );
      }

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing video player: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: _hasError
              ? Text(
                  'Failed to load video',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                )
              : _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
              ? Chewie(controller: _chewieController!)
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
