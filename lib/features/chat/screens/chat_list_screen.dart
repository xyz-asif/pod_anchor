import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Chat list screen — shows all chat rooms sorted by recent activity.
///
/// Each tile shows: avatar, name, last message preview, time, unread badge, online dot.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(chatListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: roomsState.when(
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
                    ref.read(chatListControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64.r,
                    color: AppTheme.textLightColor,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No chats yet',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppTheme.textMediumColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Add friends to start chatting',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.textLightColor,
                    ),
                  ),
                ],
              ),
            );
          }

          final currentUserId = ref
              .read(authControllerProvider)
              .valueOrNull
              ?.id;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(chatListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              itemCount: rooms.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 76.w, color: AppTheme.borderColor),
              itemBuilder: (context, index) {
                final room = rooms[index];

                // For direct chats, find the OTHER participant
                final otherParticipant = room.participants.firstWhere(
                  (p) => p.id != currentUserId,
                  orElse: () => room.participants.isNotEmpty
                      ? room.participants.first
                      : throw Exception('No participants'),
                );

                final displayName =
                    otherParticipant.displayName ??
                    otherParticipant.email ??
                    'User';
                final isOnline = otherParticipant.isOnline;
                final hasUnread = room.unreadCount > 0;

                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26.r,
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: otherParticipant.photoURL != null
                            ? CachedNetworkImageProvider(
                                otherParticipant.photoURL!,
                              )
                            : null,
                        child: otherParticipant.photoURL == null
                            ? Text(
                                displayName[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : null,
                      ),
                      // Online indicator
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14.r,
                            height: 14.r,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.r,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                      color: AppTheme.textDarkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    room.lastMessage ?? 'No messages yet',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: hasUnread
                          ? AppTheme.textDarkColor
                          : AppTheme.textMediumColor,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Time
                      if (room.lastUpdated != null)
                        Text(
                          timeago.format(room.lastUpdated!, locale: 'en_short'),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: hasUnread
                                ? AppTheme.primaryColor
                                : AppTheme.textLightColor,
                          ),
                        ),
                      SizedBox(height: 4.h),
                      // Unread badge
                      if (hasUnread)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            room.unreadCount > 99
                                ? '99+'
                                : '${room.unreadCount}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    ref
                        .read(chatListControllerProvider.notifier)
                        .clearUnreadCount(room.id);
                    context.push('/chat/${room.id}');
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
