import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service for recording voice messages.
class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentPath;
  DateTime? _startTime;

  AudioRecorderService();

  /// Starts recording and returns the path where it's saving.
  Future<String?> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/voice_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentPath = path;
        _startTime = DateTime.now();

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        return path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stops recording and returns the path and duration in seconds.
  Future<(String?, int)> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (_startTime == null) return (path, 0);

      final durationStr = DateTime.now().difference(_startTime!).inSeconds;
      _startTime = null;
      _currentPath = null;

      return (path, durationStr);
    } catch (e) {
      return (null, 0);
    }
  }

  /// Cancels and deletes the current recording.
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.stop();
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _currentPath = null;
      _startTime = null;
    } catch (e) {
      // Ignored
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});
