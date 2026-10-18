// FE-02 — Tela de login (e-mail + senha). Nenhuma menção a chave NOSTR aqui:
// a identidade é resolvida de forma invisível pelo fluxo de autenticação.
//
// Sucesso não navega "na mão": o redirect do roteador (sessão ativa) leva ao
// /dashboard. Erros vêm do AuthController já em linguagem humana.

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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider).valueOrNull;
    if (auth?.isSubmitting ?? false) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _goToSignup() {
    ref.read(authControllerProvider.notifier).clearError();
    context.go(AppRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final isSubmitting = auth?.isSubmitting ?? false;
    final errorMessage = auth?.errorMessage;

    return AuthFormShell(
      title: 'Acesse sua conta',
      subtitle: 'Seu treino. Seus dados.',
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
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Senha',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !isSubmitting,
                validator: AuthValidators.password,
                onFieldSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Entrar',
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isSubmitting ? null : _goToSignup,
                child: const Text('Não tem conta? Cadastre-se'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
