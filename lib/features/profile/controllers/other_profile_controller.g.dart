// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'other_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$otherProfileControllerHash() =>
    r'd0e11a4ab84f15128d8fe911785c3dd42f5737f6';

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

abstract class _$OtherProfileController
    extends BuildlessAutoDisposeNotifier<OtherProfileState> {
  late final String userId;

  OtherProfileState build(String userId);
}

/// Controller for viewing another user's profile.
///
/// Manages profile data, poems, reposts, follow toggle, and chat creation.
///
/// Copied from [OtherProfileController].
@ProviderFor(OtherProfileController)
const otherProfileControllerProvider = OtherProfileControllerFamily();

/// Controller for viewing another user's profile.
///
/// Manages profile data, poems, reposts, follow toggle, and chat creation.
///
/// Copied from [OtherProfileController].
class OtherProfileControllerFamily extends Family<OtherProfileState> {
  /// Controller for viewing another user's profile.
  ///
  /// Manages profile data, poems, reposts, follow toggle, and chat creation.
  ///
  /// Copied from [OtherProfileController].
  const OtherProfileControllerFamily();

  /// Controller for viewing another user's profile.
  ///
  /// Manages profile data, poems, reposts, follow toggle, and chat creation.
  ///
  /// Copied from [OtherProfileController].
  OtherProfileControllerProvider call(String userId) {
    return OtherProfileControllerProvider(userId);
  }

  @override
  OtherProfileControllerProvider getProviderOverride(
    covariant OtherProfileControllerProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'otherProfileControllerProvider';
}

/// Controller for viewing another user's profile.
///
/// Manages profile data, poems, reposts, follow toggle, and chat creation.
///
/// Copied from [OtherProfileController].
class OtherProfileControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          OtherProfileController,
          OtherProfileState
        > {
  /// Controller for viewing another user's profile.
  ///
  /// Manages profile data, poems, reposts, follow toggle, and chat creation.
  ///
  /// Copied from [OtherProfileController].
  OtherProfileControllerProvider(String userId)
    : this._internal(
        () => OtherProfileController()..userId = userId,
        from: otherProfileControllerProvider,
        name: r'otherProfileControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$otherProfileControllerHash,
        dependencies: OtherProfileControllerFamily._dependencies,
        allTransitiveDependencies:
            OtherProfileControllerFamily._allTransitiveDependencies,
        userId: userId,
      );

  OtherProfileControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  OtherProfileState runNotifierBuild(
    covariant OtherProfileController notifier,
  ) {
    return notifier.build(userId);
  }

  @override
  Override overrideWith(OtherProfileController Function() create) {
    return ProviderOverride(
      origin: this,
      override: OtherProfileControllerProvider._internal(
        () => create()..userId = userId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<OtherProfileController, OtherProfileState>
  createElement() {
    return _OtherProfileControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OtherProfileControllerProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OtherProfileControllerRef
    on AutoDisposeNotifierProviderRef<OtherProfileState> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _OtherProfileControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          OtherProfileController,
          OtherProfileState
        >
    with OtherProfileControllerRef {
  _OtherProfileControllerProviderElement(super.provider);

  @override
  String get userId => (origin as OtherProfileControllerProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
