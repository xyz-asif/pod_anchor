import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Full screen image viewer with swipe-to-dismiss.
class FullScreenImageViewer extends StatelessWidget {
  final String urlOrPath;
  final bool isLocal;
  final String heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.urlOrPath,
    required this.heroTag,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: Hero(
            tag: heroTag,
            child: isLocal
                ? Image.file(
                    File(urlOrPath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : CachedNetworkImage(
                    imageUrl: urlOrPath,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error_outline, color: Colors.white),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
