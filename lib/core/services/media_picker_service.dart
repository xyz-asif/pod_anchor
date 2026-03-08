import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_picker_service.g.dart';

/// Represents a file picked by the user.
class PickedMedia {
  final String filePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final int? width;
  final int? height;
  final double? duration;

  const PickedMedia({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.width,
    this.height,
    this.duration,
  });
}

/// Wraps platform media pickers into a clean interface.
///
/// Supports:
/// - Pick image from gallery or camera (via `image_picker`)
/// - Pick video from gallery or camera (via `image_picker`)
/// - Pick a document file (via `file_picker`)
///
/// Voice recording and GIF picker will be added in later stages.
class MediaPickerService {
  final ImagePicker _imagePicker;

  MediaPickerService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  /// Pick an image from gallery or camera.
  /// Returns null if the user cancels.
  Future<PickedMedia?> pickImage({required ImageSource source}) async {
    final xfile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (xfile == null) return null;
    return _xFileToPickedMedia(xfile);
  }

  /// Pick a video from gallery or camera.
  /// Returns null if the user cancels.
  Future<PickedMedia?> pickVideo({required ImageSource source}) async {
    final xfile = await _imagePicker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (xfile == null) return null;
    return _xFileToPickedMedia(xfile);
  }

  /// Pick a document file (PDF, doc, zip, etc.).
  /// Returns null if the user cancels.
  Future<PickedMedia?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.path == null) return null;

    final mimeType = lookupMimeType(file.path!) ?? 'application/octet-stream';

    return PickedMedia(
      filePath: file.path!,
      fileName: file.name,
      mimeType: mimeType,
      fileSize: file.size,
    );
  }

  /// Helper to convert XFile to PickedMedia.
  Future<PickedMedia> _xFileToPickedMedia(XFile xfile) async {
    final file = File(xfile.path);
    final fileSize = await file.length();
    final fileName = xfile.name;
    final mimeType = lookupMimeType(xfile.path) ?? 'application/octet-stream';

    return PickedMedia(
      filePath: xfile.path,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
    );
  }
}

/// Riverpod provider for MediaPickerService.
@Riverpod(keepAlive: true)
MediaPickerService mediaPickerService(Ref ref) {
  return MediaPickerService();
}
