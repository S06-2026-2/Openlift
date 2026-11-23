// Nova postagem de foto (ADR-0012): escolher a foto, escrever a legenda e
// publicar como `kind 20` nos relays. A localização é removida pela API
// antes de a foto ficar pública (RNF-12).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/page_layout.dart';
import '../data/photo_picker.dart';
import '../data/post_service.dart';
import '../domain/photo_post.dart';
import 'posts_controller.dart';
import 'profile_controller.dart';

class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key});

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  final _caption = TextEditingController();
  PickedPhoto? _photo;
  bool _publishing = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final photo = await ref.read(photoPickerProvider).pick();
    if (photo != null && mounted) {
      setState(() {
        _photo = photo;
        _error = null;
      });
    }
  }

  Future<void> _publish() async {
    final photo = _photo;
    if (photo == null || _publishing) return;
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      await ref.read(postServiceProvider).publish(photo, _caption.text);
      if (!mounted) return;
      ref.invalidate(postsFeedProvider);
      final messenger = ScaffoldMessenger.of(context);
      context.go(AppRoutes.feed);
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto publicada.')),
      );
    } on PostPublishException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = profileErrorMessage(e));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = _photo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova postagem'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.feed)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: pagePadding(constraints, top: 20),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: _publishing ? null : _pick,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: photo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Escolher foto',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JPEG, PNG ou WebP até 5 MB',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        )
                      : Image.memory(
                          photo.bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              photo.name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (photo != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _publishing ? null : _pick,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Trocar foto'),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              enabled: !_publishing,
              minLines: 2,
              maxLines: 6,
              maxLength: PhotoPostEvent.maxCaption,
              decoration: const InputDecoration(
                labelText: 'Legenda',
                hintText: 'Conte como foi o treino',
              ),
            ),
            Text(
              'A foto fica pública na rede aberta NOSTR. A localização dela é '
              'removida antes de publicar. Para compartilhar um treino com '
              'séries e cargas, publique pelo histórico em Treinos.',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Publicar',
              icon: Icons.send_rounded,
              isLoading: _publishing,
              onPressed: photo == null ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }
}
