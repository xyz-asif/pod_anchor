// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userSearchControllerHash() =>
    r'4e058bdea9422595186e13a7be037501f6091fe7';

/// Manages user search state with debounced searching and pagination.
///
/// Copied from [UserSearchController].
@ProviderFor(UserSearchController)
final userSearchControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      UserSearchController,
      List<UserModel>
    >.internal(
      UserSearchController.new,
      name: r'userSearchControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userSearchControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserSearchController = AutoDisposeAsyncNotifier<List<UserModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
