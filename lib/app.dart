import 'dart:async';
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
  Timer? _disconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();
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
        // ── DEBOUNCE: Only disconnect if app stays backgrounded for 3s ──
        // Android fires `paused` on transient events (notification shade,
        // app switcher, permission dialogs, biometric prompt, share sheet).
        // The 3-second delay lets these resolve without killing the socket.
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 3), () {
          log('Disconnect timer fired — app still in background',
              name: 'LIFECYCLE');
          wsService.disconnectAndNotifyServer();
        });
        break;

      case AppLifecycleState.hidden:
        // On Android 13+, hidden fires AFTER paused. The timer from
        // the paused case already covers it. Do nothing here.
        break;

      case AppLifecycleState.resumed:
        // ── CANCEL any pending disconnect — user came back ──
        _disconnectTimer?.cancel();
        _disconnectTimer = null;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            // Step 1: Refresh Firebase token (expires every 1 hour)
            final freshToken = await ref
                .read(authControllerProvider.notifier)
                .getAndRefreshToken();

            if (!mounted) return;

            if (freshToken != null) {
              wsService.updateToken(freshToken);
            }

            // Step 2: Reconnect WebSocket if needed
            final connected = await wsService.connectIfNeeded(
              timeout: const Duration(seconds: 8),
            );

            if (!mounted) return;

            if (connected) {
              log('WS connected on resume', name: 'LIFECYCLE');
              // Send presence update in case we were already connected
              // (connectIfNeeded returned true without reconnecting).
              // If we just freshly reconnected, _doConnect's .ready callback
              // already sent these — the duplicate is harmless (idempotent).
              wsService.sendPresenceStatus(true);
              // DO NOT call requestPresenceSync() here.
              // _doConnect sends it on fresh connections, and the 60s
              // periodic timer handles ongoing sync. This eliminates
              // the duplicate sync_presence calls visible in the logs.
            } else {
              log('WS reconnect failed (will retry via backoff)',
                  name: 'LIFECYCLE');
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
