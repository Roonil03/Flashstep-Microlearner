import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/network/providers.dart';
import '../data/auth_repository.dart';

class LoginCubit extends Cubit<bool> {
  final AuthRepository _authRepository;
  
  LoginCubit(this._authRepository) : super(false);

  Future<String> login({
    required String email,
    required String password,
  }) async {
    emit(true);
    try {
      final session = await _authRepository.login(
        email: email,
        password: password,
      );
      emit(false);
      return session.username.isNotEmpty ? session.username : email;
    } catch (e) {
      emit(false);
      rethrow;
    }
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showTopSnackBar(BuildContext context, String username) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
        ),
        backgroundColor: const Color(0xFF003153),
        content: Text(
          'Welcome Back, $username!',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)){
        return;
    }
    final authRepository = ref.read(authRepositoryProvider);
    try{
      final username = await context.read<LoginCubit>().login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted){
          return;
      }
      _showTopSnackBar(context, username);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted){
          return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } catch (e) {
      if (!mounted){
        return;
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
          ),
          backgroundColor: isDark ? const Color(0xFFFF4C4C) : const Color(0xFF8B0000),
          content: const Text(
            'Wrong email or password',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final greenFieldFill = isDark
        ? const Color(0xFF063B2E)
        : const Color(0xFFEAF7EC);
    final greenTextColor = isDark
        ? const Color(0xFFB8F2C8)
        : const Color(0xFF0B5D1E);
    final fieldBorderColor = const Color(0xFF2E8B57);
    final buttonColor = isDark
        ? const Color(0xFF6EC1E4)
        : const Color(0xFF003153);
    final linkBlue = Colors.blueAccent;
    return BlocProvider(
      create: (_) => LoginCubit(ref.read(authRepositoryProvider)),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Builder(
                    builder: (context) {
                      final isLoading = context.select<LoginCubit, bool>(
                        (cubit) => cubit.state,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Login',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your account details to continue.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: greenTextColor),
                            cursorColor: greenTextColor,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: greenTextColor),
                              filled: true,
                              fillColor: greenFieldFill,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: fieldBorderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: fieldBorderColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            style: TextStyle(color: greenTextColor),
                            cursorColor: greenTextColor,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: greenTextColor),
                              filled: true,
                              fillColor: greenFieldFill,
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: fieldBorderColor),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: fieldBorderColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscure = !_obscure;
                                  });
                                },
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: greenTextColor,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _handleLogin(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.register,
                                );
                              },
                              child: Text(
                                'Register Here',
                                style: TextStyle(
                                  color: linkBlue,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}