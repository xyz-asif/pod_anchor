import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/routes/app_router.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/connections/controllers/friends_controller.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';

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

    // Handle app lifecycle changes for WebSocket connection
    final wsService = ref.read(webSocketServiceProvider);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background or being terminated
        // Backend grace period handles offline state, so we simply disconnect immediately
        wsService.disconnect();
        break;
      case AppLifecycleState.resumed:
        // App coming back to foreground - reconnect WebSocket and refresh data
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          // Reconnect WebSocket if not connected and wait for it
          final connected = await wsService.connectIfNeeded(
            timeout: const Duration(seconds: 8),
          );

          if (!mounted) return;

          if (connected) {
            print(
              '[AppLifecycle] WebSocket connected, sending presence updates',
            );
            wsService.sendPresenceStatus(true);
            wsService.requestPresenceSync();
          } else {
            print(
              '[AppLifecycle] WebSocket failed to connect in time, presence not sent',
            );
          }

          // Refresh chat list to get latest presence (online/offline status)
          ref.read(chatListControllerProvider.notifier).backgroundRefresh();

          // Refresh friends list to update online status
          ref.read(friendsControllerProvider.notifier).refresh();
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
        return MaterialApp.router(
          title: 'ChatBee',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
        );
      },
    );
  }
}
