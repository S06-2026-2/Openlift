// Sprint 1 — Input padrão do design system (label, erro, tipos: texto/senha/número).

import 'package:flutter/material.dart';

/// Campo de entrada de texto padronizado do OpenLift.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.onChanged,
    this.textInputAction,
    this.initialValue,
    this.maxLines = 1,
  });

  /// Controlador de texto do campo.
  final TextEditingController? controller;

  /// Rótulo superior do campo.
  final String? label;

  /// Texto indicativo exibido dentro do campo quando vazio.
  final String? hintText;

  /// Função de validação para uso dentro de formulários [Form].
  final String? Function(String?)? validator;

  /// Se deve ocultar o conteúdo (ex.: para senhas).
  final bool obscureText;

  /// Tipo de teclado apropriado (numérico, e-mail, texto etc.).
  final TextInputType? keyboardType;

  /// Widget exibido no início do campo (ex.: ícone).
  final Widget? prefixIcon;

  /// Widget exibido no final do campo (ex.: botão de visibilidade de senha).
  final Widget? suffixIcon;

  /// Se o campo está habilitado para edição.
  final bool enabled;

  /// Callback disparado a cada alteração no texto.
  final ValueChanged<String>? onChanged;

  /// Ação do teclado ao confirmar (next, done etc.).
  final TextInputAction? textInputAction;

  /// Valor textual inicial (utilizado apenas se controller for nulo).
  final String? initialValue;

  /// Quantidade máxima de linhas visíveis.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          textInputAction: textInputAction,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
