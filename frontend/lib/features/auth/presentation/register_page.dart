import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/network/providers.dart';

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
  bool _obscure = true;
  bool isLoading = false;

  String? passwordErrorText;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_validatePassword);
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
      showSnack("Registration failed: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    passwordController.removeListener(_validatePassword);
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _inputField("Email", emailController, isDark),
                      const SizedBox(height: 15),
                      _inputField("Username", usernameController, isDark),
                      const SizedBox(height: 15),
                      _inputField(
                        "Password",
                        passwordController,
                        isDark,
                        obscure: true,
                        errorText: passwordErrorText,
                      ),
                      const SizedBox(height: 15),
                      _inputField(
                        "Confirm Password",
                        confirmPasswordController,
                        isDark,
                        obscure: true,
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark
                                    ? Colors.lightBlue
                                    : const Color(0xFF003153),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child:
                              isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text("Register"),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.login,
                          );
                        },
                        child: const Text(
                          "Already have an account? Login here",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    bool isDark, {
    bool obscure = false,
    String? errorText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !isLoading,
      obscureText: obscure && _obscure,
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
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text))
          return 'Enter a valid email address';
        if (label == 'Username' && (text.length < 3 || text.length > 50))
          return 'Use 3 to 50 characters';
        if (obscure && text.length < 8) return 'Use at least 8 characters';
        if (label == 'Confirm Password' &&
            text != passwordController.text.trim())
          return 'Passwords do not match';
        return null;
      },
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon:
            obscure
                ? IconButton(
                  tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
                : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        errorText: errorText,
      ),
    );
  }
}
