import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDarkColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDarkColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        children: [
          // ── Account ──
          _SectionHeader(label: 'Account'),
          SizedBox(height: 6.h),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.delete_outline_rounded,
                iconColor: AppTheme.errorColor,
                label: 'Delete Account',
                labelColor: AppTheme.errorColor,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // ── Support ──
          _SectionHeader(label: 'Support'),
          SizedBox(height: 6.h),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.bug_report_outlined,
                iconColor: AppTheme.warningColor,
                label: 'Bug Report',
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(
                    context,
                    message: 'Bug report coming soon',
                    type: SnackbarType.info,
                  );
                },
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // ── Legal ──
          _SectionHeader(label: 'Legal'),
          SizedBox(height: 6.h),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.description_outlined,
                iconColor: AppTheme.primaryColor,
                label: 'Terms and Conditions',
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(
                    context,
                    message: 'Terms and Conditions coming soon',
                    type: SnackbarType.info,
                  );
                },
              ),
              _Divider(),
              _SettingsRow(
                icon: Icons.shield_outlined,
                iconColor: AppTheme.primaryColor,
                label: 'Privacy Policy',
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppSnackbar.show(
                    context,
                    message: 'Privacy Policy coming soon',
                    type: SnackbarType.info,
                  );
                },
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // ── App ──
          _SectionHeader(label: 'App'),
          SizedBox(height: 6.h),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.textMediumColor,
                label: 'App Version',
                trailing: Text(
                  '1.0.3',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 40.h),

          // ── Sign Out ──
          _SignOutButton(onTap: () => _confirmSignOut(context, ref)),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out?',
        confirmLabel: 'Sign Out',
        confirmColor: AppTheme.errorColor,
        onConfirm: () {
          Navigator.pop(ctx);
          ref.read(authControllerProvider.notifier).signOut();
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Delete Account',
        message:
            'This action is permanent and cannot be undone. All your poems, messages, and data will be deleted.',
        confirmLabel: 'Delete',
        confirmColor: AppTheme.errorColor,
        onConfirm: () {
          Navigator.pop(ctx);
          AppSnackbar.show(
            context,
            message: 'Account deletion coming soon',
            type: SnackbarType.info,
          );
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMediumColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Grouped card ─────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(children: children),
    );
  }
}

// ── Single row ───────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          child: Row(
            children: [
              // Icon badge — iOS style coloured square
              Container(
                width: 32.r,
                height: 32.r,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: iconColor, size: 17.r),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? AppTheme.textDarkColor,
                  ),
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.chevron_right_rounded,
                          size: 20.r,
                          color: AppTheme.textLightColor,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inset divider between rows ───────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 60.w),
      child: Divider(height: 1, color: AppTheme.borderColor),
    );
  }
}

// ── Sign out button ───────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 15.h),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            'Sign Out',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.errorColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Confirm dialog ────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDarkColor,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14.sp,
          color: AppTheme.textMediumColor,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMediumColor,
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(
            confirmLabel,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: confirmColor,
            ),
          ),
        ),
      ],
    );
  }
}
