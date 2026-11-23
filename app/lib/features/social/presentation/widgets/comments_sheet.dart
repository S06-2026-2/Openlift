// Botão de comentários (ícone + contagem) e a folha com a conversa e o campo
// para comentar (ADR-0012, kind 1111).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/nostr/nip19.dart';
import '../../domain/comment.dart';
import '../comments_controller.dart';
import '../network_workouts_view.dart' show shortNpub;
import '../profile_controller.dart';
import 'photo_post_card.dart' show timeAgo;
import 'profile_avatar.dart';

class CommentButton extends ConsumerWidget {
  const CommentButton({super.key, required this.target});

  final CommentTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      commentsProvider.select((state) => state[target.eventId]?.length ?? 0),
    );
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Comentários',
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          onPressed: () => showCommentsSheet(context, target),
        ),
        Text(
          count == 1 ? '1 comentário' : '$count comentários',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

Future<void> showCommentsSheet(BuildContext context, CommentTarget target) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CommentsSheet(target: target),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.target});

  final CommentTarget target;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Lê de novo ao abrir: pode ter chegado comentário novo.
    Future.microtask(() => ref
        .read(commentsProvider.notifier)
        .fetch([widget.target.eventId], force: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await ref
        .read(commentsProvider.notifier)
        .add(widget.target, _controller.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = ref.watch(
      commentsProvider
          .select((state) => state[widget.target.eventId] ?? const <Comment>[]),
    );
    final authors = ref.watch(authorProfilesProvider);
    ref.listen(
      commentsProvider.select((state) => state[widget.target.eventId]),
      (_, next) => ref
          .read(authorProfilesProvider.notifier)
          .load([for (final c in next ?? const <Comment>[]) c.pubkey]),
    );
    final now = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Comentários', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(
              child: comments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Ninguém comentou ainda. Seja a primeira pessoa.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final profile = authors[comment.pubkey];
                        final name = profile?.handle ??
                            shortNpub(Nip19.encodeNpub(comment.pubkey));
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileAvatar(
                              name: profile?.title ?? name,
                              url: profile?.avatarUrl,
                              radius: 14,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$name ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextSpan(text: comment.text),
                                      ],
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeAgo(comment.publishedAt, now),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_sending,
              minLines: 1,
              maxLines: 4,
              maxLength: CommentEvent.maxLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Escreva um comentário',
                errorText: _error,
                counterText: '',
                suffixIcon: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Enviar comentário',
                        icon: const Icon(Icons.send_rounded, size: 20),
                        onPressed: _send,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
