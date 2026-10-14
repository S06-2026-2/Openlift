// FE-02 — Tela de cadastro (e-mail + senha + confirmação). Ao concluir, o
// AuthController cria a conta e já entra; o redirect do roteador leva ao
// /dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_form_shell.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth?.isSubmitting ?? false) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _goToLogin() {
    ref.read(authControllerProvider.notifier).clearError();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final isSubmitting = auth?.isSubmitting ?? false;
    final errorMessage = auth?.errorMessage;

    return AuthFormShell(
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMessage != null) ...[
                ErrorBanner(message: errorMessage),
                const SizedBox(height: 16),
              ],
              AppTextField(
                label: 'E-mail',
                hintText: 'voce@exemplo.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
                validator: AuthValidators.email,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Senha',
                hintText: 'Mínimo de ${AuthValidators.minPasswordLength} caracteres',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
                validator: AuthValidators.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip:
                      _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirmar senha',
                controller: _confirmController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !isSubmitting,
                validator: (value) => AuthValidators.confirmation(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _submit(),
                prefixIcon: const Icon(Icons.lock_reset_rounded),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Criar conta',
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isSubmitting ? null : _goToLogin,
                child: const Text('Já tem conta? Entrar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
