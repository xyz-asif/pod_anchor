import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/routes/app_router.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/connections/controllers/friends_controller.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'dart:developer';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/core/widgets/connectivity_wrapper.dart';
import 'package:chatbee/features/notifications/controllers/notification_controller.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    log('→ $state', name: 'LIFECYCLE');

    // Skip lifecycle handling if not logged in
    final isLoggedIn = ref.read(authNotifierProvider).isLoggedIn;
    if (!isLoggedIn) return;

    final wsService = ref.read(webSocketServiceProvider);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden: // iOS-specific background state
        // App is genuinely in background — notify server and close socket.
        // Note: detached is intentionally excluded (can fire spuriously on Android).
        wsService.disconnectAndNotifyServer();
        break;

      case AppLifecycleState.resumed:
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            // ── Step 1: Refresh Firebase token ────────────────────────────
            // Firebase tokens expire after 1 hour. If app was backgrounded
            // longer than that, stored token is stale and WS server will
            // reject it — causing a permanent disconnect until app restarts.
            final freshToken = await ref
                .read(authControllerProvider.notifier)
                .getAndRefreshToken();

            if (!mounted) return;

            // Inject fresh token before reconnecting
            if (freshToken != null) {
              wsService.updateToken(freshToken);
            }

            // ── Step 2: Reconnect WebSocket ────────────────────────────────
            final connected = await wsService.connectIfNeeded(
              timeout: const Duration(seconds: 8),
            );

            if (!mounted) return;

            if (connected) {
              log('WS reconnected, syncing presence', name: 'LIFECYCLE');
              wsService.sendPresenceStatus(true);
              wsService.requestPresenceSync();
            } else {
              log('WS reconnect failed (will retry via backoff)', name: 'LIFECYCLE');
            }

            // ── Step 3: Refresh UI data ────────────────────────────────────
            ref.read(chatListControllerProvider.notifier).backgroundRefresh();
            ref.read(friendsControllerProvider.notifier).refresh();
            ref.read(unreadNotificationCountProvider.notifier).refresh();

            // ── Step 4: Recover stuck session ─────────────────────────────
            // If the app cold-started offline, restoreSession() failed and
            // SessionGate is stuck on the error screen. Retry now that
            // network is back.
            if (!mounted) return;
            final authState = ref.read(authControllerProvider);
            if (authState.hasError) {
              log('Auth in error state — retrying session restore', name: 'LIFECYCLE');
              ref.read(authControllerProvider.notifier).restoreSession();
            }
          } catch (e, st) {
            log('Lifecycle resume handler error: $e\n$st', name: 'LIFECYCLE');
          }
        });
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the WebSocket event handler alive and active forever
    ref.watch(wsEventHandlerProvider);

    final router = ref.watch(goRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ConnectivityWrapper(
          child: MaterialApp.router(
            title: 'ChatBee',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            routerConfig: router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
          ),
        );
      },
    );
  }
}
