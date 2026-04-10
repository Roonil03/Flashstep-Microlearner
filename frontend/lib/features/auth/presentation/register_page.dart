import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/network/providers.dart';
import '../data/auth_repository.dart';

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

  bool isLoading = false;

  String? passwordErrorText;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = passwordController.text.trim();
    final nextError = password.isEmpty
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
      showSnack("Account created successfully!");
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      showSnack("Registration failed: $e");
    }

    setState(() => isLoading = false);
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAppDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = !isAppDark;
    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
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
                    _inputField("Password", passwordController, isDark,
                        obscure: true, errorText: passwordErrorText,),
                    const SizedBox(height: 15),
                    _inputField("Confirm Password",
                        confirmPasswordController, isDark,
                        obscure: true),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.lightBlue
                              : const Color(0xFF003153),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Register"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(
                            context, AppRoutes.login);
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
    );
  }

  Widget _inputField(
      String label, TextEditingController controller, bool isDark,
      {bool obscure = false, String? errorText,}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.green.withOpacity(0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        errorText: errorText,        
      ),
    );
  }
}