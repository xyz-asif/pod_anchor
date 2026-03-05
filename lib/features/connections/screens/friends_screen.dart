import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/features/connections/controllers/friends_controller.dart';
import 'package:chatbee/features/connections/controllers/pending_requests_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Friends screen with two tabs: Friends list and Pending requests.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          actions: [
            IconButton(
              icon: Icon(Icons.person_search_rounded, size: 24.r),
              onPressed: () => context.push('/search'),
            ),
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

/// Tab showing accepted friends.
class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsControllerProvider);

    return friendsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
              final connection = friends[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(
                    Icons.person_rounded,
                    size: 22.r,
                    color: AppTheme.primaryColor,
                  ),
                ),
                title: Text(
                  'Friend',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Connected ${connection.statusEnum.name}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
                trailing: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 20.r,
                ),
                onTap: () {
                  // Will open chat in Phase 4
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
class _PendingRequestsTab extends ConsumerWidget {
  const _PendingRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
              return ListTile(
                leading: CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppTheme.featureIconBackgroundColor,
                  child: Icon(
                    Icons.person_rounded,
                    size: 22.r,
                    color: AppTheme.primaryColor,
                  ),
                ),
                title: Text(
                  'Friend Request',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Wants to connect',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Accept
                    IconButton(
                      icon: Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 28.r,
                      ),
                      onPressed: () => ref
                          .read(pendingRequestsControllerProvider.notifier)
                          .accept(request.id),
                    ),
                    // Reject
                    IconButton(
                      icon: Icon(
                        Icons.cancel_rounded,
                        color: Colors.red.shade300,
                        size: 28.r,
                      ),
                      onPressed: () => ref
                          .read(pendingRequestsControllerProvider.notifier)
                          .reject(request.id),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
