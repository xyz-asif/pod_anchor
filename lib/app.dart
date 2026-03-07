import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/routes/app_router.dart';
import 'package:chatbee/core/services/websocket_service.dart';

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
    // Handle app lifecycle changes for WebSocket connection
    final wsService = ref.read(webSocketServiceProvider);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App going to background or being terminated
        // Gracefully disconnect WebSocket so server knows user is offline
        wsService.disconnect();
        break;
      case AppLifecycleState.resumed:
        // App coming back to foreground - reconnect if needed
        // The auth controller will handle reconnection
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'ChatBee',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
        );
      },
    );
  }
}
