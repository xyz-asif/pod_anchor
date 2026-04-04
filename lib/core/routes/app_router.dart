import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/auth/views/login_view.dart';
import 'package:chatbee/features/home/screens/home_screen.dart';
import 'package:chatbee/features/auth/widgets/session_gate.dart';
import 'package:chatbee/features/chat/screens/chat_screen.dart';
import 'package:chatbee/features/notifications/screens/notification_screen.dart';
import 'package:chatbee/features/profile/screens/other_profile_screen.dart';
import 'package:chatbee/features/profile/screens/profile_edit_screen.dart';
import 'package:chatbee/features/profile/screens/profile_setup_screen.dart';
import 'package:chatbee/features/profile/screens/username_setup_screen.dart';
import 'package:chatbee/features/profile/screens/follow_list_screen.dart';
import 'package:chatbee/features/profile/screens/settings_screen.dart';
import 'package:chatbee/features/feed/screens/explore_screen.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/screens/my_poems_screen.dart';
import 'package:chatbee/features/poems/screens/poetry_editor_screen.dart';
import 'package:chatbee/features/poems/screens/poem_standalone_screen.dart';

/// Global navigator key — used by NotificationService to navigate from outside widget tree.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider — created once and cached.
/// Uses AuthNotifier as refreshListenable so redirects fire on login/logout.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = authNotifier.isLoggedIn;
      final currentPath = state.matchedLocation;

      // Not logged in → go to login
      if (!isLoggedIn) {
        if (currentPath == '/login') return null;
        return '/login';
      }

      // Logged in → don't show login
      if (currentPath == '/login') return '/home';

      return null;
    },
    routes: [
      // ── Auth ──
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),

      // ── Profile Setup ──
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/username-setup',
        builder: (context, state) => const UsernameSetupScreen(),
      ),

      // ── Home (bottom nav: chats, friends, profile) ──
      GoRoute(
        path: '/home',
        builder: (context, state) => const SessionGate(child: HomeScreen()),
      ),

      // ── Poems ──
      GoRoute(
        path: '/my-poems',
        builder: (context, state) => const MyPoemsScreen(),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is PoemModel) {
            return PoetryEditorScreen(poemId: extra.id, existingPoem: extra);
          }
          return const PoetryEditorScreen();
        },
      ),
      GoRoute(
        path: '/poem/:id',
        builder: (context, state) {
          final poemId = state.pathParameters['id']!;
          final poem = state.extra as PoemModel?;
          return PoemStandaloneScreen(poemId: poemId, poem: poem);
        },
      ),

      // ── Chat ──
      GoRoute(
        path: '/chat/:roomId',
        builder: (context, state) =>
            ChatScreen(roomId: state.pathParameters['roomId']!),
      ),

      // ── New Profiles ──
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return OtherProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/profile/:id/followers',
        builder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return FollowListScreen(userId: userId, isFollowers: true);
        },
      ),
      GoRoute(
        path: '/profile/:id/following',
        builder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return FollowListScreen(userId: userId, isFollowers: false);
        },
      ),

      // ── Search ──
      GoRoute(
        path: '/search',
        builder: (context, state) => const ExploreScreen(),
      ),

      // ── Notifications ──
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
    ],
  );
});
