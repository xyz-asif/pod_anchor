import 'package:go_router/go_router.dart';
import 'package:chatbee/features/auth/views/login_view.dart';
import 'package:chatbee/features/home/screens/home_screen.dart';
import 'package:chatbee/features/chat/screens/chat_screen.dart';
import 'package:chatbee/features/profile/screens/user_search_screen.dart';

/// Centralized routing.
class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      // ── Auth ──
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),

      // ── Home (bottom nav: chats, friends, profile) ──
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),

      // ── Chat ──
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) =>
            ChatScreen(roomId: state.pathParameters['roomId']!),
      ),

      // ── User Search ──
      GoRoute(
        path: '/search',
        builder: (context, state) => const UserSearchScreen(),
      ),
    ],
  );
}
