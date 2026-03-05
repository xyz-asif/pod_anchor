import 'package:go_router/go_router.dart';
import 'package:chatbee/features/auth/views/login_view.dart';
import 'package:chatbee/features/auth/views/register_view.dart';

/// Centralized routing.
/// Add new routes here when you add new features.
class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      // ── Auth ──
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterView(),
      ),

      // ── Add more feature routes below ──
      // GoRoute(
      //   path: '/home',
      //   builder: (context, state) => const HomeView(),
      // ),
    ],
  );
}
