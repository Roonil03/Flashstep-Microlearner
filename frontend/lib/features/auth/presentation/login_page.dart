import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import 'account_frame.dart';
import '../../../core/network/providers.dart';
import '../../../core/network/api_errors.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../../decks/data/data_sync_service.dart';

class LoginCubit extends Cubit<bool> {
  final AuthRepository _authRepository;

  LoginCubit(this._authRepository) : super(false);

  Future<String> login({
    required String email,
    required String password,
    String? expectedUserId,
  }) async {
    emit(true);
    try {
      final session = await _authRepository.login(
        email: email,
        password: password,
        expectedUserId: expectedUserId,
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

  String? _expectedUserId(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    return arguments is Map && arguments['expectedUserId'] is String
        ? arguments['expectedUserId'] as String
        : null;
  }

  Future<void> _resumeSync() async {
    try {
      await ref.read(deckSyncServiceProvider).syncNow();
    } catch (_) {
      // A later automatic or manual sync can retry; saved changes remain local.
    }
  }

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
      final expectedUserId = _expectedUserId(context);
      final username = await context.read<LoginCubit>().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        expectedUserId: expectedUserId,
      );
      if (!context.mounted) {
        return;
      }
      if (expectedUserId != null) unawaited(_resumeSync());
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
    final renewingSession = _expectedUserId(context) != null;
    return BlocProvider(
      create: (_) => LoginCubit(ref.read(authRepositoryProvider)),
      child: AccountFrame(
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
                  const AccountMark(),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      renewingSession
                          ? 'Sign in to sync your saved account'
                          : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
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
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscure = !_obscure;
                          });
                        },
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
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
                      onPressed: isLoading ? null : () => _handleLogin(context),

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
                  if (!renewingSession) const SizedBox(height: 16),
                  if (!renewingSession)
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.register);
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
    );
  }
}
