// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_state_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordingControllerHash() =>
    r'ef22d1040767d30dcbebe7423492f580dc6537bb';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$RecordingController
    extends BuildlessAutoDisposeNotifier<RecordingState> {
  late final String roomId;

  RecordingState build(String roomId);
}

/// See also [RecordingController].
@ProviderFor(RecordingController)
const recordingControllerProvider = RecordingControllerFamily();

/// See also [RecordingController].
class RecordingControllerFamily extends Family<RecordingState> {
  /// See also [RecordingController].
  const RecordingControllerFamily();

  /// See also [RecordingController].
  RecordingControllerProvider call(String roomId) {
    return RecordingControllerProvider(roomId);
  }

  @override
  RecordingControllerProvider getProviderOverride(
    covariant RecordingControllerProvider provider,
  ) {
    return call(provider.roomId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'recordingControllerProvider';
}

/// See also [RecordingController].
class RecordingControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<RecordingController, RecordingState> {
  /// See also [RecordingController].
  RecordingControllerProvider(String roomId)
    : this._internal(
        () => RecordingController()..roomId = roomId,
        from: recordingControllerProvider,
        name: r'recordingControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$recordingControllerHash,
        dependencies: RecordingControllerFamily._dependencies,
        allTransitiveDependencies:
            RecordingControllerFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  RecordingControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  RecordingState runNotifierBuild(covariant RecordingController notifier) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(RecordingController Function() create) {
    return ProviderOverride(
      origin: this,
      override: RecordingControllerProvider._internal(
        () => create()..roomId = roomId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<RecordingController, RecordingState>
  createElement() {
    return _RecordingControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingControllerProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RecordingControllerRef on AutoDisposeNotifierProviderRef<RecordingState> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _RecordingControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<RecordingController, RecordingState>
    with RecordingControllerRef {
  _RecordingControllerProviderElement(super.provider);

  @override
  String get roomId => (origin as RecordingControllerProvider).roomId;
}

String _$chatInputControllerHash() =>
    r'd446e3e44b3374bb58149c83b69275189afd69c0';

abstract class _$ChatInputController
    extends BuildlessAutoDisposeNotifier<ChatInputState> {
  late final String roomId;

  ChatInputState build(String roomId);
}

/// See also [ChatInputController].
@ProviderFor(ChatInputController)
const chatInputControllerProvider = ChatInputControllerFamily();

/// See also [ChatInputController].
class ChatInputControllerFamily extends Family<ChatInputState> {
  /// See also [ChatInputController].
  const ChatInputControllerFamily();

  /// See also [ChatInputController].
  ChatInputControllerProvider call(String roomId) {
    return ChatInputControllerProvider(roomId);
  }

  @override
  ChatInputControllerProvider getProviderOverride(
    covariant ChatInputControllerProvider provider,
  ) {
    return call(provider.roomId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatInputControllerProvider';
}

/// See also [ChatInputController].
class ChatInputControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<ChatInputController, ChatInputState> {
  /// See also [ChatInputController].
  ChatInputControllerProvider(String roomId)
    : this._internal(
        () => ChatInputController()..roomId = roomId,
        from: chatInputControllerProvider,
        name: r'chatInputControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatInputControllerHash,
        dependencies: ChatInputControllerFamily._dependencies,
        allTransitiveDependencies:
            ChatInputControllerFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  ChatInputControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  ChatInputState runNotifierBuild(covariant ChatInputController notifier) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(ChatInputController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatInputControllerProvider._internal(
        () => create()..roomId = roomId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChatInputController, ChatInputState>
  createElement() {
    return _ChatInputControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatInputControllerProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatInputControllerRef on AutoDisposeNotifierProviderRef<ChatInputState> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ChatInputControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<ChatInputController, ChatInputState>
    with ChatInputControllerRef {
  _ChatInputControllerProviderElement(super.provider);

  @override
  String get roomId => (origin as ChatInputControllerProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
