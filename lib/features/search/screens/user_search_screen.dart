import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/search/controllers/user_search_controller.dart';
import 'package:chatbee/features/search/models/user_search_model.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/shared/widgets/friend_shimmer.dart';
import 'package:chatbee/shared/widgets/friend_action_button.dart';

/// User search screen with connection status and actions
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Initial search to show all users and refresh data on every visit
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(userSearchControllerProvider.notifier).search('');
      if (mounted) {
        _listAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(userSearchControllerProvider.notifier).loadMore();
    }
  }

  void _onSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(userSearchControllerProvider.notifier).search(query);
      _listAnimationController.reset();
      _listAnimationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Handle side effects
    ref.listen(userSearchControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) => AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        ),
      );
    });

    final state = ref.watch(userSearchControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Find People',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDarkColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar - Elegant Dark Theme
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: AppTheme.textDarkColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textLightColor,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.primaryColor,
                    size: 22.r,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppTheme.textLightColor,
                            size: 20.r,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // Results List
          Expanded(
            child: state.when(
              loading: () => ListView.builder(
                itemCount: 5,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemBuilder: (_, __) => const FriendShimmer(),
              ),
              error: (e, _) => _buildEmptyState('Something went wrong'),
              data: (searchState) {
                if (searchState.users.isEmpty) {
                  return _buildEmptyState(
                    _searchController.text.isEmpty
                        ? 'Start typing to search for users'
                        : 'No users found',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(userSearchControllerProvider.notifier).search(_searchController.text);
                    _listAnimationController.reset();
                    _listAnimationController.forward();
                  },
                  child: AnimatedBuilder(
                    animation: _listAnimationController,
                    builder: (context, child) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: searchState.users.length +
                            (searchState.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == searchState.users.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final user = searchState.users[index];
                          return _UserListTile(
                            user: user,
                            onAction: (action) => _handleAction(user, action),
                            animation: _listAnimationController,
                            index: index,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64.r,
            color: AppTheme.textLightColor.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(UserSearchModel user, ConnectionAction action) async {
    final controller = ref.read(userSearchControllerProvider.notifier);

    try {
      switch (action) {
        case ConnectionAction.addFriend:
          await controller.sendFriendRequest(user.id);
          AppSnackbar.show(
            context,
            message: 'Friend request sent',
            type: SnackbarType.success,
          );
          break;
        case ConnectionAction.accept:
          if (user.connectionId == null) {
            AppSnackbar.show(
              context,
              message: 'Cannot accept - request not found',
              type: SnackbarType.error,
            );
            return;
          }
          await controller.acceptFriendRequest(user.id, user.connectionId!);
          AppSnackbar.show(
            context,
            message: 'Friend request accepted',
            type: SnackbarType.success,
          );
          break;
        case ConnectionAction.reject:
          if (user.connectionId == null) {
            AppSnackbar.show(
              context,
              message: 'Cannot reject - request not found',
              type: SnackbarType.error,
            );
            return;
          }
          await controller.rejectFriendRequest(user.id, user.connectionId!);
          AppSnackbar.show(
            context,
            message: 'Friend request rejected',
            type: SnackbarType.info,
          );
          break;
        case ConnectionAction.cancel:
          if (user.connectionId == null) {
            AppSnackbar.show(
              context,
              message: 'Cannot cancel - request not found',
              type: SnackbarType.error,
            );
            return;
          }
          await controller.cancelFriendRequest(user.id, user.connectionId!);
          AppSnackbar.show(
            context,
            message: 'Request cancelled',
            type: SnackbarType.info,
          );
          break;
        case ConnectionAction.unfriend:
          if (user.connectionId == null) {
            AppSnackbar.show(
              context,
              message: 'Cannot unfriend - connection not found',
              type: SnackbarType.error,
            );
            return;
          }
          final confirmed = await _showUnfriendConfirmDialog(user.displayName);
          if (confirmed) {
            await controller.removeConnection(user.id, user.connectionId!);
            AppSnackbar.show(
              context,
              message: 'Unfriended ${user.displayName}',
              type: SnackbarType.info,
            );
          }
          break;
      }
    } catch (e) {
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: SnackbarType.error,
      );
    }
  }

  Future<bool> _showUnfriendConfirmDialog(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Unfriend $name?'),
            content: Text(
              'This will remove them from your friends list. You can add them again later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Unfriend',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Connection action types
enum ConnectionAction {
  addFriend,
  accept,
  reject,
  cancel,
  unfriend,
}

/// User list tile with action buttons - Elegant Dark Theme Design
class _UserListTile extends StatelessWidget {
  final UserSearchModel user;
  final Function(ConnectionAction) onAction;
  final Animation<double> animation;
  final int index;

  const _UserListTile({
    required this.user,
    required this.onAction,
    required this.animation,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Staggered animation - items slide in from bottom
    final double start = (index * 0.1).clamp(0.0, 0.8);
    final double end = (start + 0.2).clamp(0.0, 1.0);
    final double t = animation.value;
    
    // Calculate animation progress for this item
    double itemProgress = 0.0;
    if (t > start) {
      itemProgress = ((t - start) / (end - start)).clamp(0.0, 1.0);
    }
    
    // Slide and fade animation
    final slideOffset = (1 - itemProgress) * 50.h;
    final fadeOpacity = itemProgress;

    return Opacity(
      opacity: fadeOpacity,
      child: Transform.translate(
        offset: Offset(0, slideOffset),
        child: Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with gradient ring
              Container(
                width: 52.r,
                height: 52.r,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                padding: EdgeInsets.all(2.r),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: user.photoURL != null
                        ? Image.network(
                            user.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                          )
                        : _buildDefaultAvatar(),
                  ),
                ),
              ),

              SizedBox(width: 14.w),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDarkColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.textMediumColor,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        user.bio!,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppTheme.textLightColor,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Action Button
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.3),
            AppTheme.primaryColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 26.r,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (user.connectionStatus) {
      case 'none':
      case 'rejected':
        return FriendActionButton(
          icon: Icons.person_add_rounded,
          color: AppTheme.primaryColor,
          onPressed: () => onAction(ConnectionAction.addFriend),
        );

      case 'pending_sent':
        return FriendActionButton(
          icon: Icons.close_rounded,
          color: AppTheme.textLightColor,
          onPressed: () => onAction(ConnectionAction.cancel),
        );

      case 'pending_received':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FriendActionButton(
              icon: Icons.check_rounded,
              color: Colors.green,
              onPressed: () => onAction(ConnectionAction.accept),
            ),
            SizedBox(width: 8.w),
            FriendActionButton(
              icon: Icons.close_rounded,
              color: Colors.red.shade400,
              onPressed: () => onAction(ConnectionAction.reject),
            ),
          ],
        );

      case 'accepted':
        return FriendActionButton(
          icon: Icons.person_remove_rounded,
          color: Colors.red.withValues(alpha: 0.8),
          onPressed: () => onAction(ConnectionAction.unfriend),
        );

      case 'blocked':
        return FriendActionButton(
          icon: Icons.block_rounded,
          color: Colors.grey,
          onPressed: () {}, // Empty callback when blocked
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
