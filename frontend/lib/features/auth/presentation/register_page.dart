import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import 'account_frame.dart';
import '../../../core/network/providers.dart';
import '../../../core/network/api_errors.dart';
import '../data/auth_api.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool isLoading = false;

  String? passwordErrorText;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_validatePassword);
    passwordController.addListener(_clearValidationSnack);
    confirmPasswordController.addListener(_clearValidationSnack);
  }

  void _clearValidationSnack() {
    if (mounted) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
  }

  void _validatePassword() {
    final password = passwordController.text.trim();
    final nextError =
        password.isEmpty
            ? null
            : password.length < 8
            ? 'Password must be at least 8 characters'
            : null;

    if (nextError != passwordErrorText) {
      setState(() {
        passwordErrorText = nextError;
      });
    }
  }

  Future<void> register() async {
    if (isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showSnack("Please fill all fields");
      return;
    }

    if (password.length < 8) {
      setState(() {
        passwordErrorText = 'Password must be at least 8 characters';
      });
      showSnack("Password must be at least 8 characters");
      return;
    }

    if (password != confirmPassword) {
      showSnack("Passwords do not match");
      return;
    }

    setState(() => isLoading = true);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.register(
        email: email,
        username: username,
        password: password,
      );
      if (!mounted) return;
      showSnack("Account created successfully! Sign in to get started.");
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      showSnack(e is AuthApiException ? e.message : networkErrorMessage(e));
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    passwordController.removeListener(_validatePassword);
    passwordController.removeListener(_clearValidationSnack);
    confirmPasswordController.removeListener(_clearValidationSnack);
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness != Brightness.dark;
    final theme = isDark ? AppTheme.dark() : AppTheme.light();
    return AccountFrame(
      theme: theme,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccountMark(),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                'Create an account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your account to study across devices.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _inputField("Username", usernameController),
            const SizedBox(height: 15),
            _inputField("Email", emailController),
            const SizedBox(height: 15),
            _inputField(
              "Password",
              passwordController,
              obscure: true,
              hidden: _obscurePassword,
              onToggleVisibility:
                  () => setState(() => _obscurePassword = !_obscurePassword),
              errorText: passwordErrorText,
            ),
            const SizedBox(height: 15),
            _inputField(
              "Confirm Password",
              confirmPasswordController,
              obscure: true,
              hidden: _obscureConfirmation,
              onToggleVisibility:
                  () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : register,
                child:
                    isLoading
                        ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text("Create account"),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'These pages are information placeholders. Account creation does not accept future terms or data practices.',
              style: theme.textTheme.bodySmall,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.termsOfService),
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.privacyPolicy),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                }
              },
              child: const Text("Back to login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool hidden = true,
    VoidCallback? onToggleVisibility,
    String? errorText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !isLoading,
      obscureText: obscure && hidden,
      keyboardType:
          label == 'Email' ? TextInputType.emailAddress : TextInputType.text,
      textInputAction:
          label == 'Confirm Password'
              ? TextInputAction.done
              : TextInputAction.next,
      onFieldSubmitted: label == 'Confirm Password' ? (_) => register() : null,
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return 'Enter ${label.toLowerCase()}';
        if (label == 'Email' &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Enter a valid email address';
        }
        if (label == 'Username') {
          final usernameLength = text.toLowerCase().runes.length;
          if (usernameLength < 3 || usernameLength > 50) {
            return 'Use 3 to 50 characters';
          }
        }
        if (obscure && text.length < 8) return 'Use at least 8 characters';
        if (label == 'Confirm Password' &&
            text != passwordController.text.trim()) {
          return 'Passwords do not match';
        }
        return null;
      },

      decoration: InputDecoration(
        labelText: label,
        suffixIcon:
            obscure
                ? IconButton(
                  tooltip: '${hidden ? 'Show' : 'Hide'} ${label.toLowerCase()}',
                  onPressed: isLoading ? null : onToggleVisibility,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
                : null,

        errorText: errorText,
      ),
    );
  }
}
