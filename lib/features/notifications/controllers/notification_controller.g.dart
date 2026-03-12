// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationControllerHash() =>
    r'76970358043d44a383f5017b3d7fc14043d83af4';

/// Manages the notification list and unread badge count.
///
/// Copied from [NotificationController].
@ProviderFor(NotificationController)
final notificationControllerProvider =
    AsyncNotifierProvider<
      NotificationController,
      List<NotificationModel>
    >.internal(
      NotificationController.new,
      name: r'notificationControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NotificationController = AsyncNotifier<List<NotificationModel>>;
String _$unreadNotificationCountHash() =>
    r'87741c9eec853d2f9d357d11a6b8edd97f45d375';

/// Separate provider for badge count so it can be watched independently
/// without rebuilding the full notification list.
///
/// Copied from [UnreadNotificationCount].
@ProviderFor(UnreadNotificationCount)
final unreadNotificationCountProvider =
    NotifierProvider<UnreadNotificationCount, int>.internal(
      UnreadNotificationCount.new,
      name: r'unreadNotificationCountProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$unreadNotificationCountHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UnreadNotificationCount = Notifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
