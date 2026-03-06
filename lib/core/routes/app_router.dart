import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/auth/views/login_view.dart';
import 'package:chatbee/features/home/screens/home_screen.dart';
import 'package:chatbee/features/chat/screens/chat_screen.dart';
import 'package:chatbee/features/profile/screens/user_search_screen.dart';

/// GoRouter provider — created once and cached.
/// Uses AuthNotifier as refreshListenable so redirects fire on login/logout.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/login';

      // Not logged in → force login screen
      if (!isLoggedIn && !isOnLogin) return '/login';

      // Logged in but still on login → go home
      if (isLoggedIn && isOnLogin) return '/home';

      // No redirect needed
      return null;
    },
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
});
