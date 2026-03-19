import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

/// Routes the user to the right screen based on notification content.
/// Maps backend `resourceType` values to app routes.
void navigateToNotification(BuildContext context, String resourceType, String resourceId) {
  // Guard against empty values
  if (resourceType.isEmpty || resourceId.isEmpty) return;

  switch (resourceType) {
    case 'chat_room':
      context.push('/chat/$resourceId');
      break;
    case 'poem':
      // Navigate to poem detail — uses the fetch wrapper for deep links
      context.push('/poem/$resourceId');
      break;
    case 'user':
    case 'profile':
      // Navigate to user profile (for followed, connection_accepted)
      context.push('/profile/$resourceId');
      break;
    case 'comment':
      // Comments are on poems — resourceId should be the poemId.
      // If backend sends commentId instead, this needs a backend change.
      context.push('/poem/$resourceId');
      break;
    case 'connection':
      // Navigate to the connections/friends tab
      context.push('/home');
      break;
    default:
      // Unknown type — go home
      context.push('/home');
  }
}
