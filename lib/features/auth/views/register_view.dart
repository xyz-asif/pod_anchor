import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:anchor/features/auth/controllers/auth_controller.dart';
import 'package:anchor/features/auth/widgets/auth_form.dart';
import 'package:anchor/shared/widgets/app_snackbar.dart';
import 'package:anchor/config/theme/text_styles.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
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
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Create Account', style: AppTextStyles.heading),
            SizedBox(height: 32.h),
            AuthForm(
              isRegister: true,
              isLoading: isLoading,
              onSubmit: ({name, required email, required password}) {
                ref
                    .read(authControllerProvider.notifier)
                    .register(name: name!, email: email, password: password);
              },
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
