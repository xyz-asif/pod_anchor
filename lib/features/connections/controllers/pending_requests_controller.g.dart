// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_requests_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingRequestsControllerHash() =>
    r'3cc7b9deeb74c9a5749a738263b0bc38314127b9';

/// Manages pending friend requests received by the current user.
///
/// Copied from [PendingRequestsController].
@ProviderFor(PendingRequestsController)
final pendingRequestsControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      PendingRequestsController,
      List<ConnectionModel>
    >.internal(
      PendingRequestsController.new,
      name: r'pendingRequestsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingRequestsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PendingRequestsController =
    AutoDisposeAsyncNotifier<List<ConnectionModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
