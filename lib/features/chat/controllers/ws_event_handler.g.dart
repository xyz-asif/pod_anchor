// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_event_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wsEventHandlerHash() => r'09b4a80df6c3dea7d13a1b13600d27f31eb27e94';

/// Listens to WebSocket events and dispatches them to the correct controllers.
///
/// This is a keepAlive provider that starts listening when first read.
/// Typically initialized right after auth (when WS connects).
///
/// Copied from [wsEventHandler].
@ProviderFor(wsEventHandler)
final wsEventHandlerProvider = StreamProvider<WsEvent>.internal(
  wsEventHandler,
  name: r'wsEventHandlerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wsEventHandlerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WsEventHandlerRef = StreamProviderRef<WsEvent>;
String _$typingControllerHash() => r'cb0138c2ddac034186ef726bee562b1f4a56faf3';

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

abstract class _$TypingController
    extends BuildlessAutoDisposeNotifier<Map<String, bool>> {
  late final String roomId;

  Map<String, bool> build(String roomId);
}

/// Typing state for a specific room.
/// Maps userId → true/false (typing or not).
///
/// Copied from [TypingController].
@ProviderFor(TypingController)
const typingControllerProvider = TypingControllerFamily();

/// Typing state for a specific room.
/// Maps userId → true/false (typing or not).
///
/// Copied from [TypingController].
class TypingControllerFamily extends Family<Map<String, bool>> {
  /// Typing state for a specific room.
  /// Maps userId → true/false (typing or not).
  ///
  /// Copied from [TypingController].
  const TypingControllerFamily();

  /// Typing state for a specific room.
  /// Maps userId → true/false (typing or not).
  ///
  /// Copied from [TypingController].
  TypingControllerProvider call(String roomId) {
    return TypingControllerProvider(roomId);
  }

  @override
  TypingControllerProvider getProviderOverride(
    covariant TypingControllerProvider provider,
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
  String? get name => r'typingControllerProvider';
}

/// Typing state for a specific room.
/// Maps userId → true/false (typing or not).
///
/// Copied from [TypingController].
class TypingControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<TypingController, Map<String, bool>> {
  /// Typing state for a specific room.
  /// Maps userId → true/false (typing or not).
  ///
  /// Copied from [TypingController].
  TypingControllerProvider(String roomId)
    : this._internal(
        () => TypingController()..roomId = roomId,
        from: typingControllerProvider,
        name: r'typingControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$typingControllerHash,
        dependencies: TypingControllerFamily._dependencies,
        allTransitiveDependencies:
            TypingControllerFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  TypingControllerProvider._internal(
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
  Map<String, bool> runNotifierBuild(covariant TypingController notifier) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(TypingController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TypingControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<TypingController, Map<String, bool>>
  createElement() {
    return _TypingControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TypingControllerProvider && other.roomId == roomId;
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
mixin TypingControllerRef on AutoDisposeNotifierProviderRef<Map<String, bool>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _TypingControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<TypingController, Map<String, bool>>
    with TypingControllerRef {
  _TypingControllerProviderElement(super.provider);

  @override
  String get roomId => (origin as TypingControllerProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
