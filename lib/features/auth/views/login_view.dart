import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:anchor/features/auth/controllers/auth_controller.dart';
import 'package:anchor/features/auth/widgets/auth_form.dart';
import 'package:anchor/shared/widgets/app_snackbar.dart';
import 'package:anchor/config/theme/text_styles.dart';

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
            // context.go('/home');
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome Back', style: AppTextStyles.heading),
            SizedBox(height: 32.h),
            AuthForm(
              isLoading: isLoading,
              onSubmit: ({name, required email, required password}) {
                ref
                    .read(authControllerProvider.notifier)
                    .login(email: email, password: password);
              },
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
