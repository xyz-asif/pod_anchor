import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/core/utils/validators.dart';
import 'package:chatbee/shared/widgets/app_button.dart';
import 'package:chatbee/shared/widgets/app_text_field.dart';
import 'package:chatbee/shared/widgets/secure_text_field.dart';

/// Reusable auth form. Used by both Login and Register views.
///
/// Set [isRegister] to true to show the name field.
class AuthForm extends StatefulWidget {
  final bool isRegister;
  final bool isLoading;
  final void Function({
    String? name,
    required String email,
    required String password,
  })
  onSubmit;

  const AuthForm({
    super.key,
    this.isRegister = false,
    this.isLoading = false,
    required this.onSubmit,
  });

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      name: widget.isRegister ? _nameController.text.trim() : null,
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (widget.isRegister) ...[
            AppTextField(
              label: 'Name',
              controller: _nameController,
              validator: Validators.required,
            ),
            SizedBox(height: 16.h),
          ],
          AppTextField(
            label: 'Email',
            controller: _emailController,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16.h),
          SecureTextField(
            label: 'Password',
            controller: _passwordController,
            validator: Validators.password,
          ),
          SizedBox(height: 24.h),
          AppButton(
            text: widget.isRegister ? 'Register' : 'Login',
            isLoading: widget.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
