// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friends_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendsControllerHash() => r'b9000adcab6c66a6d68a47ade2490d196e80495d';

/// Manages the accepted friends list.
///
/// Copied from [FriendsController].
@ProviderFor(FriendsController)
final friendsControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      FriendsController,
      List<ConnectionModel>
    >.internal(
      FriendsController.new,
      name: r'friendsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$friendsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FriendsController = AutoDisposeAsyncNotifier<List<ConnectionModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
