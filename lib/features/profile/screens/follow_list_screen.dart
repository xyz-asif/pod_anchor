import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

import 'package:chatbee/features/profile/controllers/follow_list_controller.dart';

/// Reusable screen for displaying a paginated list of followers or following.
class FollowListScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isFollowers; // true = followers, false = following

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.isFollowers,
  });

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  final ScrollController _scrollController = ScrollController();
  late final FollowListArgs _args;

  @override
  void initState() {
    super.initState();
    _args = FollowListArgs(userId: widget.userId, isFollowers: widget.isFollowers);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = ref.read(followListControllerProvider(_args));
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        state.hasMore &&
        !state.isLoadingMore) {
      ref.read(followListControllerProvider(_args).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFollowers ? 'Followers' : 'Following';

    // Listen for errors
    ref.listen<FollowListState>(
      followListControllerProvider(_args),
      (previous, next) {
        if (next.error != null && next.error != previous?.error) {
          AppSnackbar.show(context, message: next.error!, type: SnackbarType.error);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(followListControllerProvider(_args));

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error ?? 'An unexpected error occurred', 
                style: TextStyle(color: Colors.red, fontSize: 14.sp)),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => ref.invalidate(followListControllerProvider(_args)), 
              child: const Text('Retry')
            ),
          ],
        ),
      );
    }

    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64.r, color: AppTheme.textLightColor),
            SizedBox(height: 12.h),
            Text(
              widget.isFollowers ? 'No followers yet' : 'Not following anyone',
              style:
                  TextStyle(fontSize: 16.sp, color: AppTheme.textMediumColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(followListControllerProvider(_args)),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.users.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.users.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final user = state.users[index];

          return ListTile(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/profile/${user.id}');
            },
            leading: CircleAvatar(
              radius: 22.r,
              backgroundColor: AppTheme.borderColor,
              backgroundImage: user.photoURL.isNotEmpty
                  ? CachedNetworkImageProvider(user.photoURL)
                  : null,
              child: user.photoURL.isEmpty
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 16.sp, color: AppTheme.textDarkColor),
                    )
                  : null,
            ),
            title: Text(
              user.displayName.isNotEmpty ? user.displayName : 'Unknown',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDarkColor),
            ),
            subtitle: Text(
              user.username.isNotEmpty ? '@${user.username}' : '',
              style: TextStyle(
                  fontSize: 13.sp, color: AppTheme.textLightColor),
            ),
            trailing: _FollowButton(
              user: user, 
              args: _args,
              isLoading: state.loadingUserIds.contains(user.id),
            ),
          );
        },
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final UserSearchResult user;
  final FollowListArgs args;
  final bool isLoading;

  const _FollowButton({
    required this.user,
    required this.args,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide follow button if it's me
    final me = ref.watch(authControllerProvider).valueOrNull;
    if (me == null || me.id == user.id) return const SizedBox.shrink();

    return SizedBox(
      height: 32.h,
      width: 92.w,
      child: ElevatedButton(
        onPressed: isLoading ? null : () {
          HapticFeedback.selectionClick();
          ref.read(followListControllerProvider(args).notifier).toggleFollow(user.id);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              user.isFollowing ? AppTheme.featureBackgroundColor : AppTheme.primaryColor,
          foregroundColor: user.isFollowing ? AppTheme.textDarkColor : Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r)),
        ),
        child: isLoading
            ? SizedBox(
                width: 12.r,
                height: 12.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: user.isFollowing ? AppTheme.primaryColor : Colors.white,
                ))
            : Text(user.isFollowing ? 'Unfollow' : 'Follow',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
