// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$followListControllerHash() =>
    r'bcaaddb05ee37127883eb006c3c965abf68cd526';

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

abstract class _$FollowListController
    extends BuildlessAutoDisposeNotifier<FollowListState> {
  late final FollowListArgs args;

  FollowListState build(FollowListArgs args);
}

/// See also [FollowListController].
@ProviderFor(FollowListController)
const followListControllerProvider = FollowListControllerFamily();

/// See also [FollowListController].
class FollowListControllerFamily extends Family<FollowListState> {
  /// See also [FollowListController].
  const FollowListControllerFamily();

  /// See also [FollowListController].
  FollowListControllerProvider call(FollowListArgs args) {
    return FollowListControllerProvider(args);
  }

  @override
  FollowListControllerProvider getProviderOverride(
    covariant FollowListControllerProvider provider,
  ) {
    return call(provider.args);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'followListControllerProvider';
}

/// See also [FollowListController].
class FollowListControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<FollowListController, FollowListState> {
  /// See also [FollowListController].
  FollowListControllerProvider(FollowListArgs args)
    : this._internal(
        () => FollowListController()..args = args,
        from: followListControllerProvider,
        name: r'followListControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$followListControllerHash,
        dependencies: FollowListControllerFamily._dependencies,
        allTransitiveDependencies:
            FollowListControllerFamily._allTransitiveDependencies,
        args: args,
      );

  FollowListControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.args,
  }) : super.internal();

  final FollowListArgs args;

  @override
  FollowListState runNotifierBuild(covariant FollowListController notifier) {
    return notifier.build(args);
  }

  @override
  Override overrideWith(FollowListController Function() create) {
    return ProviderOverride(
      origin: this,
      override: FollowListControllerProvider._internal(
        () => create()..args = args,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        args: args,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<FollowListController, FollowListState>
  createElement() {
    return _FollowListControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FollowListControllerProvider && other.args == args;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, args.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FollowListControllerRef
    on AutoDisposeNotifierProviderRef<FollowListState> {
  /// The parameter `args` of this provider.
  FollowListArgs get args;
}

class _FollowListControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          FollowListController,
          FollowListState
        >
    with FollowListControllerRef {
  _FollowListControllerProviderElement(super.provider);

  @override
  FollowListArgs get args => (origin as FollowListControllerProvider).args;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
