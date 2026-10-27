// FE-04 — Caminho avançado (RF-04): usar uma identidade NOSTR que a pessoa
// já tem em outro app. Fica escondido em Perfil → Configurações avançadas;
// o fluxo padrão nunca mostra nada sobre chaves (ADR-0005).
//
// O campo é mascarado, não tem sugestão/autocorreção e o valor digitado
// nunca aparece em mensagem de erro (RNF-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../auth_controller.dart';

Future<bool?> showImportIdentitySheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const ImportIdentitySheet(),
  );
}

class ImportIdentitySheet extends ConsumerStatefulWidget {
  const ImportIdentitySheet({super.key});

  @override
  ConsumerState<ImportIdentitySheet> createState() =>
      _ImportIdentitySheetState();
}

class _ImportIdentitySheetState extends ConsumerState<ImportIdentitySheet> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .importNostrIdentity(_controller.text);
    if (!mounted) return;
    if (error == null) {
      _controller.clear();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Usar identidade NOSTR existente',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Se você já usa NOSTR em outro aplicativo, pode publicar seus '
            'treinos com a mesma identidade. Cole aqui sua chave privada '
            '(começa com "nsec1"). Ela fica só neste aparelho e nunca é '
            'enviada ao servidor do OpenLift.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A identidade atual deste aparelho será substituída.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            obscureText: _obscure,
            enabled: !_saving,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            onSubmitted: (_) => _import(),
            decoration: InputDecoration(
              hintText: 'nsec1…',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Usar esta identidade',
            isLoading: _saving,
            onPressed: _import,
          ),
        ],
      ),
    );
  }
}
