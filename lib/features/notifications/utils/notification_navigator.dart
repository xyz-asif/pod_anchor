import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

/// Routes the user to the right screen based on notification content.
/// Add new cases here when you add new features (posts, comments, etc.).
void navigateToNotification(BuildContext context, String resourceType, String resourceId) {
  switch (resourceType) {
    case 'chat_room':
      context.push('/chat/$resourceId');
      break;
    case 'connection':
      // Navigate to the connections/friends tab
      context.push('/home');
      break;
    // Future cases:
    // case 'post':
    //   context.push('/post/$resourceId');
    //   break;
    default:
      // Unknown type — go home
      context.push('/home');
  }
}
