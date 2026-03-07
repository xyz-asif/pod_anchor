// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_list_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatListControllerHash() =>
    r'1c0b2da399f23e3cc7faf9708ea7914b86b3538e';

/// Manages the chat room list state (main chat list screen).
///
/// Auto-loads rooms on build. Supports:
/// - Refresh (pull-to-refresh)
/// - Optimistic room reordering on new message
/// - Unread count updates
/// - Sorted by lastUpdated (newest first)
///
/// Copied from [ChatListController].
@ProviderFor(ChatListController)
final chatListControllerProvider =
    AsyncNotifierProvider<ChatListController, List<RoomResponse>>.internal(
      ChatListController.new,
      name: r'chatListControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$chatListControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ChatListController = AsyncNotifier<List<RoomResponse>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
