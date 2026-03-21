// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileControllerHash() => r'97d8dc35119385a1d40abc6bbd51a428733e7cbf';

/// Manages the current user's profile state.
///
/// Loads profile on build, supports update (displayName, bio, photoURL).
/// keepAlive: true ensures state persists across navigation.
///
/// Copied from [ProfileController].
@ProviderFor(ProfileController)
final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserModel?>.internal(
      ProfileController.new,
      name: r'profileControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileController = AsyncNotifier<UserModel?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
