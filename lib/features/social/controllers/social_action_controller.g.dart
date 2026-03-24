// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_action_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$socialActionControllerHash() =>
    r'5cb821eef09ea39b418ca0a75d417c6e942a918c';

/// Centralized controller for social actions (like, repost, delete).
///
/// Eliminates duplicated setState logic from PoemCard and other widgets.
/// After each action, emits a [SocialEvent] so all feed controllers
/// and listening widgets update automatically.
///
/// Copied from [SocialActionController].
@ProviderFor(SocialActionController)
final socialActionControllerProvider =
    AutoDisposeAsyncNotifierProvider<SocialActionController, void>.internal(
      SocialActionController.new,
      name: r'socialActionControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$socialActionControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SocialActionController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
