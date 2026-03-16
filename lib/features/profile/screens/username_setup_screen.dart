import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/profile/controllers/profile_setup_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _isConfirming = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      ref.read(usernameControllerProvider.notifier).checkUsername('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(usernameControllerProvider.notifier).checkUsername(value.toLowerCase().trim());
    });
  }

  Future<void> _onConfirm() async {
    final usernameState = ref.read(usernameControllerProvider);
    if (!usernameState.isAvailable) return;

    setState(() => _isConfirming = true);
    try {
      await ref.read(usernameControllerProvider.notifier).confirmUsername(usernameState.username);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usernameState = ref.watch(usernameControllerProvider);

    // Status color for the feedback text below the field
    Color statusColor = AppTheme.textMediumColor;
    if (usernameState.status == UsernameCheckStatus.available) {
      statusColor = Colors.green;
    } else if (usernameState.status == UsernameCheckStatus.taken ||
        usernameState.status == UsernameCheckStatus.invalidFormat ||
        usernameState.status == UsernameCheckStatus.reserved) {
      statusColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose a username', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your username is how other poets find you. You can only set this once.',
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor),
            ),

            SizedBox(height: 28.h),

            // ── Username Field ──
            TextField(
              controller: _controller,
              onChanged: _onUsernameChanged,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 16.sp, color: AppTheme.textDarkColor),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: TextStyle(fontSize: 16.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                hintText: 'yourname',
                hintStyle: TextStyle(color: AppTheme.textLightColor),
                filled: true,
                fillColor: AppTheme.featureBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: usernameState.status == UsernameCheckStatus.available
                        ? Colors.green
                        : AppTheme.primaryColor,
                  ),
                ),
                // Show check or X icon on the right based on status
                suffixIcon: _buildSuffixIcon(usernameState.status),
              ),
            ),

            SizedBox(height: 8.h),

            // ── Status message ──
            if (usernameState.statusMessage.isNotEmpty)
              Text(
                usernameState.statusMessage,
                style: TextStyle(fontSize: 13.sp, color: statusColor),
              ),

            SizedBox(height: 8.h),

            Text(
              '3–30 characters. Letters, numbers, and underscores only.',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
            ),

            const Spacer(),

            // ── Confirm Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (usernameState.isAvailable && !_isConfirming) ? _onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: AppTheme.borderColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isConfirming
                    ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm username', style: TextStyle(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),

            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon(UsernameCheckStatus status) {
    switch (status) {
      case UsernameCheckStatus.checking:
        return Padding(
          padding: EdgeInsets.all(12.r),
          child: SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(strokeWidth: 2)),
        );
      case UsernameCheckStatus.available:
        return Icon(Icons.check_circle_rounded, color: Colors.green, size: 22.r);
      case UsernameCheckStatus.taken:
      case UsernameCheckStatus.invalidFormat:
      case UsernameCheckStatus.reserved:
        return Icon(Icons.cancel_rounded, color: Colors.red, size: 22.r);
      default:
        return null;
    }
  }
}
