import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/network/providers.dart';
import '../../../core/network/api_errors.dart';
import '../data/auth_api.dart';
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
      if (!isClosed) emit(false);
      return session.username.isNotEmpty ? session.username : email;
    } catch (e) {
      if (!isClosed) emit(false);
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
        margin: const EdgeInsets.only(top: 16, left: 16, right: 16),

        content: Text('Welcome Back, $username!'),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    if (context.read<LoginCubit>().state ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final username = await context.read<LoginCubit>().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!context.mounted) {
        return;
      }
      _showTopSnackBar(context, username);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      final palette = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
          backgroundColor: palette.errorContainer,
          content: Text(
            e is AuthApiException ? e.message : networkErrorMessage(e),
            style: TextStyle(color: palette.onErrorContainer),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (_) => LoginCubit(ref.read(authRepositoryProvider)),
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
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
                            'Flashstep Microlearner',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const Divider(height: 32),
                          Semantics(
                            header: true,
                            child: Text(
                              'Welcome back',
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to keep your decks and reviews in sync.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'name@example.com',
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
                            enabled: !isLoading,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!isLoading) _handleLogin(context);
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                tooltip:
                                    _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscure = !_obscure;
                                  });
                                },
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
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
                            child: FilledButton(
                              onPressed:
                                  isLoading
                                      ? null
                                      : () => _handleLogin(context),

                              child:
                                  isLoading
                                      ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Log in'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.register);
                              },
                              child: const Text('Create an account'),
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
