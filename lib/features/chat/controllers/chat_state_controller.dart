import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/services/audio_recorder_service.dart';

part 'chat_state_controller.g.dart';

@riverpod
class RecordingController extends _$RecordingController {
  Timer? _timer;

  @override
  RecordingState build(String roomId) {
    ref.onDispose(() => _timer?.cancel());
    return const RecordingState();
  }

  Future<void> start() async {
    final path = await ref.read(audioRecorderServiceProvider).startRecording();
    if (path != null) {
      state = state.copyWith(isRecording: true, durationSeconds: 0);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        state = state.copyWith(durationSeconds: state.durationSeconds + 1);
      });
    }
  }

  void stop() {
    _timer?.cancel();
    state = state.copyWith(isRecording: false);
  }

  void cancel() {
    _timer?.cancel();
    ref.read(audioRecorderServiceProvider).cancelRecording();
    state = const RecordingState();
  }
}

class RecordingState {
  final bool isRecording;
  final int durationSeconds;

  const RecordingState({this.isRecording = false, this.durationSeconds = 0});

  RecordingState copyWith({bool? isRecording, int? durationSeconds}) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

@riverpod
class ChatInputController extends _$ChatInputController {
  @override
  ChatInputState build(String roomId) {
    return const ChatInputState();
  }

  void setReply(String id, String content) {
    state = state.copyWith(
      replyToId: id,
      replyToContent: content,
      editingMessageId: null,
      editingContent: null,
    );
  }

  void setEdit(String id, String content) {
    state = state.copyWith(
      editingMessageId: id,
      editingContent: content,
      replyToId: null,
      replyToContent: null,
    );
  }

  void clear() {
    state = const ChatInputState();
  }
}

class ChatInputState {
  final String? replyToId;
  final String? replyToContent;
  final String? editingMessageId;
  final String? editingContent;

  const ChatInputState({
    this.replyToId,
    this.replyToContent,
    this.editingMessageId,
    this.editingContent,
  });

  ChatInputState copyWith({
    String? replyToId,
    String? replyToContent,
    String? editingMessageId,
    String? editingContent,
  }) {
    return ChatInputState(
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      editingMessageId: editingMessageId ?? this.editingMessageId,
      editingContent: editingContent ?? this.editingContent,
    );
  }
}
