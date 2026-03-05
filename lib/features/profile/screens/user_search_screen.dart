import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/features/profile/controllers/user_search_controller.dart';
import 'package:chatbee/features/connections/controllers/send_request_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// User search screen — search users by name or email to send friend requests.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(userSearchControllerProvider.notifier).search(query);
    });
  }

  void _sendFriendRequest(String userId) async {
    try {
      await ref
          .read(sendRequestControllerProvider.notifier)
          .sendRequest(userId);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Friend request sent!',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(userSearchControllerProvider);
    final sentRequests = ref.watch(sendRequestControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Users')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16.r),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(userSearchControllerProvider.notifier)
                              .search('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Results
          Expanded(
            child: searchState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Text(
                    e.toString(),
                    style: TextStyle(color: Colors.red, fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (users) {
                if (_searchController.text.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 64.r,
                          color: AppTheme.textLightColor,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Search for users to connect',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.textMediumColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textMediumColor,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final alreadySent = sentRequests.contains(user.id);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 22.r,
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: user.photoURL != null
                            ? CachedNetworkImageProvider(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 22.r,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                      ),
                      title: Text(
                        user.displayName ?? user.email,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textMediumColor,
                        ),
                      ),
                      trailing: alreadySent
                          ? Icon(
                              Icons.check_rounded,
                              color: Colors.green,
                              size: 22.r,
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.person_add_rounded,
                                color: AppTheme.primaryColor,
                                size: 22.r,
                              ),
                              onPressed: () => _sendFriendRequest(user.id),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
