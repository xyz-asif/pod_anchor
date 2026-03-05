import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/config/theme/app_theme.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  @override
  Widget build(BuildContext context) {
    // 1. Side effects FIRST
    ref.listen(authControllerProvider, (prev, next) {
      next.when(
        data: (user) {
          if (user != null) {
            context.go('/home');
          }
        },
        error: (e, _) => AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        ),
        loading: () {},
      );
    });

    // 2. Watch state
    final state = ref.watch(authControllerProvider);
    final isLoading = state.isLoading;

    // 3. Build UI
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // App icon / logo placeholder
              Container(
                width: 100.r,
                height: 100.r,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  size: 48.r,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 24.h),

              // Title
              Text(
                'ChatBee',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDarkColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Connect with friends instantly',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.textMediumColor,
                ),
              ),

              const Spacer(flex: 2),

              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signInWithGoogle(),
                  icon: isLoading
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.login_rounded, size: 22.r),
                  label: Text(
                    isLoading ? 'Signing in...' : 'Sign in with Google',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 48.h),
            ],
          ),
        ),
      ),
    );
  }
}
