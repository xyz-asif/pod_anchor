// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationControllerHash() =>
    r'dba6223edb65b11844d23c4081d078ea82f4c192';

/// Manages the notification list and unread badge count.5
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
    r'4484ae540c876fd4dfa8dfbc5c23c6f6ec518902';

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
