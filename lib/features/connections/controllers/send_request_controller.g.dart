// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_request_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sendRequestControllerHash() =>
    r'395e8a2718e39a1e526264d05f0ce9ee06343261';

/// Handles sending friend requests from the search screen.
/// State holds the set of user IDs that have been sent a request
/// in this session (to disable the button after sending).
///
/// Copied from [SendRequestController].
@ProviderFor(SendRequestController)
final sendRequestControllerProvider =
    AutoDisposeNotifierProvider<SendRequestController, Set<String>>.internal(
      SendRequestController.new,
      name: r'sendRequestControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sendRequestControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SendRequestController = AutoDisposeNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
