// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friends_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendsControllerHash() => r'3475f86dd1a1fbd7eda02aef9b1ff5856a108fa4';

/// Manages the accepted friends list, enriched with user display info.
///
/// Cross-references friend connections with chat room participant data
/// to get names, photos, online status, and last messages.
///
/// Copied from [FriendsController].
@ProviderFor(FriendsController)
final friendsControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      FriendsController,
      List<FriendWithInfo>
    >.internal(
      FriendsController.new,
      name: r'friendsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$friendsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FriendsController = AutoDisposeAsyncNotifier<List<FriendWithInfo>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
