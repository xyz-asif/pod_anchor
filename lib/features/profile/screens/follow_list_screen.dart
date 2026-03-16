import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/profile/repos/follow_repo.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

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
  List<UserSearchResult> _users = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        _hasMore &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final repo = ref.read(followRepoProvider);
      final page = widget.isFollowers
          ? await repo.getFollowers(widget.userId)
          : await repo.getFollowing(widget.userId);
      if (mounted) {
        setState(() {
          _users = page.users;
          _hasMore = page.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final repo = ref.read(followRepoProvider);
      final page = widget.isFollowers
          ? await repo.getFollowers(widget.userId,
              before: _users.isNotEmpty ? _users.last.id : null)
          : await repo.getFollowing(widget.userId,
              before: _users.isNotEmpty ? _users.last.id : null);
      if (mounted) {
        setState(() {
          _users.addAll(page.users);
          _hasMore = page.hasMore;
        });
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFollowers ? 'Followers' : 'Following';

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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Colors.red, fontSize: 14.sp)),
            SizedBox(height: 8.h),
            TextButton(onPressed: _loadInitial, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
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
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _users.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final user = _users[index];
          return ListTile(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            onTap: () => context.push('/profile/${user.id}'),
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
            title: Text(user.displayName,
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDarkColor)),
            subtitle: Text('@${user.username}',
                style: TextStyle(
                    fontSize: 13.sp, color: AppTheme.textLightColor)),
          );
        },
      ),
    );
  }
}
