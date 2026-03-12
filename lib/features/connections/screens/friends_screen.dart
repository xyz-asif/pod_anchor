import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/features/connections/controllers/friends_controller.dart';
import 'package:chatbee/features/connections/controllers/pending_requests_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/shared/widgets/friend_shimmer.dart';
import 'package:chatbee/shared/widgets/friend_action_button.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/shared/widgets/notification_bell.dart';

/// Friends screen with two tabs: Friends list and Pending requests.
class FriendsScreen extends ConsumerWidget {
  final int initialTabIndex;

  const FriendsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: false,
          actions: const [
            NotificationBell(),
          ],
          bottom: TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textMediumColor,
            indicatorColor: AppTheme.primaryColor,
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_FriendsTab(), _PendingRequestsTab()],
        ),
      ),
    );
  }
}

/// Tab showing accepted friends with real names, photos and last message.
class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab();

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  @override
  void initState() {
    super.initState();
    // Load fresh data every time the tab is visited
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendsControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsControllerProvider);

    return friendsState.when(
      loading: () => ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemBuilder: (_, __) => const FriendShimmer(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.toString(),
              style: TextStyle(fontSize: 14.sp, color: Colors.red),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () =>
                  ref.read(friendsControllerProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 64.r,
                  color: AppTheme.textLightColor,
                ),
                SizedBox(height: 12.h),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton.icon(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search users'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(friendsControllerProvider.notifier).refresh(),
          child: ListView.separated(
            itemCount: friends.length,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            separatorBuilder: (_, __) =>
                Divider(height: 1, indent: 72.w, color: AppTheme.borderColor),
            itemBuilder: (context, index) {
              final friend = friends[index];
              final connection = friend.connection;

              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 4.h,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24.r,
                      backgroundColor: AppTheme.primaryLight,
                      backgroundImage: friend.photoURL != null
                          ? CachedNetworkImageProvider(friend.photoURL!)
                          : null,
                      child: friend.photoURL == null
                          ? Text(
                              friend.displayName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    // Online indicator
                    if (friend.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12.r,
                          height: 12.r,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.r),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  friend.displayName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  friend.lastMessage ?? 'Tap to start chatting',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.textMediumColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 20.r,
                ),
                onTap: () async {
                  // Determine friend's user ID
                  final currentUserId = ref
                      .read(authControllerProvider)
                      .valueOrNull
                      ?.id;
                  final friendUserId = connection.senderId == currentUserId
                      ? connection.receiverId
                      : connection.senderId;

                  try {
                    // Get or create direct chat room
                    final room = await ref
                        .read(chatRepoProvider)
                        .getOrCreateDirectRoom(friendUserId);
                    
                    // Add room to chat list so ChatScreen can find it
                    ref.read(chatListControllerProvider.notifier).upsertRoom(room);
                    
                    if (context.mounted) {
                      context.push('/chat/${room.id}');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackbar.show(
                        context,
                        message: 'Could not open chat: $e',
                        type: SnackbarType.error,
                      );
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Tab showing pending friend requests received.
class _PendingRequestsTab extends ConsumerStatefulWidget {
  const _PendingRequestsTab();

  @override
  ConsumerState<_PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends ConsumerState<_PendingRequestsTab> {
  @override
  void initState() {
    super.initState();
    // Load fresh data every time the tab is visited
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingRequestsControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingState = ref.watch(pendingRequestsControllerProvider);

    // Side effects for accept/reject errors
    ref.listen(pendingRequestsControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) => AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        ),
      );
    });

    return pendingState.when(
      loading: () => ListView.builder(
        itemCount: 5,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemBuilder: (_, __) => const PendingRequestShimmer(),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.toString(),
              style: TextStyle(fontSize: 14.sp, color: Colors.red),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => ref
                  .read(pendingRequestsControllerProvider.notifier)
                  .refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 64.r,
                  color: AppTheme.textLightColor,
                ),
                SizedBox(height: 12.h),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(pendingRequestsControllerProvider.notifier).refresh(),
          child: ListView.separated(
            itemCount: requests.length,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            separatorBuilder: (_, __) =>
                Divider(height: 1, indent: 72.w, color: AppTheme.borderColor),
            itemBuilder: (context, index) {
              final request = requests[index];
              final isProcessing = ref
                  .read(pendingRequestsControllerProvider.notifier)
                  .isProcessing(request.id);

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ListTile(
                  key: ValueKey(request.id),
                  leading: CircleAvatar(
                    radius: 22.r,
                    backgroundColor: AppTheme.primaryLight,
                    backgroundImage: request.senderPhotoURL != null
                        ? CachedNetworkImageProvider(request.senderPhotoURL!)
                        : null,
                    child: request.senderPhotoURL == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 22.r,
                            color: AppTheme.primaryColor,
                          )
                        : null,
                  ),
                  title: Text(
                    request.senderDisplayName ?? request.senderEmail ?? 'Friend Request',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    request.senderDisplayName != null
                        ? 'Wants to connect'
                        : request.senderEmail != null
                            ? 'New connection request'
                            : 'New connection request',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textMediumColor,
                    ),
                  ),
                  trailing: isProcessing
                      ? FriendActionButton(
                          icon: Icons.hourglass_empty,
                          color: Colors.grey,
                          onPressed: () {}, // Empty callback when loading
                          isLoading: true,
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Accept
                            FriendActionButton(
                              icon: Icons.check_rounded,
                              color: Colors.green,
                              onPressed: () => ref
                                  .read(
                                    pendingRequestsControllerProvider.notifier,
                                  )
                                  .accept(request.id),
                            ),
                            SizedBox(width: 8.w),
                            // Reject
                            FriendActionButton(
                              icon: Icons.close_rounded,
                              color: Colors.red.shade400,
                              onPressed: () => ref
                                  .read(
                                    pendingRequestsControllerProvider.notifier,
                                  )
                                  .reject(request.id),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
