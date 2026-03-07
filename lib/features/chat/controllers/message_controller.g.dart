// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messageControllerHash() => r'3282b6bebd4b064bf7af7d82876d9a5e35f64094';

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

abstract class _$MessageController
    extends BuildlessAsyncNotifier<List<MessageResponse>> {
  late final String roomId;

  FutureOr<List<MessageResponse>> build(String roomId);
}

/// Manages messages for a specific chat room.
///
/// Takes roomId as a family parameter. Supports:
/// - Initial load + pagination (load older)
/// - Optimistic message sending
/// - Append from WebSocket
/// - Edit/delete/reaction updates
///
/// Copied from [MessageController].
@ProviderFor(MessageController)
const messageControllerProvider = MessageControllerFamily();

/// Manages messages for a specific chat room.
///
/// Takes roomId as a family parameter. Supports:
/// - Initial load + pagination (load older)
/// - Optimistic message sending
/// - Append from WebSocket
/// - Edit/delete/reaction updates
///
/// Copied from [MessageController].
class MessageControllerFamily
    extends Family<AsyncValue<List<MessageResponse>>> {
  /// Manages messages for a specific chat room.
  ///
  /// Takes roomId as a family parameter. Supports:
  /// - Initial load + pagination (load older)
  /// - Optimistic message sending
  /// - Append from WebSocket
  /// - Edit/delete/reaction updates
  ///
  /// Copied from [MessageController].
  const MessageControllerFamily();

  /// Manages messages for a specific chat room.
  ///
  /// Takes roomId as a family parameter. Supports:
  /// - Initial load + pagination (load older)
  /// - Optimistic message sending
  /// - Append from WebSocket
  /// - Edit/delete/reaction updates
  ///
  /// Copied from [MessageController].
  MessageControllerProvider call(String roomId) {
    return MessageControllerProvider(roomId);
  }

  @override
  MessageControllerProvider getProviderOverride(
    covariant MessageControllerProvider provider,
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
  String? get name => r'messageControllerProvider';
}

/// Manages messages for a specific chat room.
///
/// Takes roomId as a family parameter. Supports:
/// - Initial load + pagination (load older)
/// - Optimistic message sending
/// - Append from WebSocket
/// - Edit/delete/reaction updates
///
/// Copied from [MessageController].
class MessageControllerProvider
    extends
        AsyncNotifierProviderImpl<MessageController, List<MessageResponse>> {
  /// Manages messages for a specific chat room.
  ///
  /// Takes roomId as a family parameter. Supports:
  /// - Initial load + pagination (load older)
  /// - Optimistic message sending
  /// - Append from WebSocket
  /// - Edit/delete/reaction updates
  ///
  /// Copied from [MessageController].
  MessageControllerProvider(String roomId)
    : this._internal(
        () => MessageController()..roomId = roomId,
        from: messageControllerProvider,
        name: r'messageControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$messageControllerHash,
        dependencies: MessageControllerFamily._dependencies,
        allTransitiveDependencies:
            MessageControllerFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  MessageControllerProvider._internal(
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
  FutureOr<List<MessageResponse>> runNotifierBuild(
    covariant MessageController notifier,
  ) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(MessageController Function() create) {
    return ProviderOverride(
      origin: this,
      override: MessageControllerProvider._internal(
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
  AsyncNotifierProviderElement<MessageController, List<MessageResponse>>
  createElement() {
    return _MessageControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessageControllerProvider && other.roomId == roomId;
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
mixin MessageControllerRef on AsyncNotifierProviderRef<List<MessageResponse>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _MessageControllerProviderElement
    extends
        AsyncNotifierProviderElement<MessageController, List<MessageResponse>>
    with MessageControllerRef {
  _MessageControllerProviderElement(super.provider);

  @override
  String get roomId => (origin as MessageControllerProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
