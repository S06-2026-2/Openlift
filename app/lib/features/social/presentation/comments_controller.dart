// Comentários das fotos e treinos na tela (ADR-0012), por evento comentado.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/comment_service.dart';
import '../data/post_service.dart' show PostPublishException;
import '../domain/comment.dart';

class CommentsController
    extends AutoDisposeNotifier<Map<String, List<Comment>>> {
  final Set<String> _requested = {};

  @override
  Map<String, List<Comment>> build() {
    _requested.clear();
    return const {};
  }

  List<Comment> of(String eventId) => state[eventId] ?? const [];

  /// Lê dos relays os comentários de [eventIds] ainda não pedidos. Com
  /// [force], lê de novo. Falha deixa como estava.
  Future<void> fetch(Iterable<String> eventIds, {bool force = false}) async {
    final ids = [
      for (final id in eventIds.toSet())
        if (force || _requested.add(id)) id,
    ];
    if (ids.isEmpty) return;
    _requested.addAll(ids);
    try {
      final loaded = await ref.read(commentServiceProvider).load(ids);
      final next = {...state};
      for (final entry in loaded.entries) {
        // Junta com os publicados aqui que o relay ainda não devolveu.
        final known = {for (final c in entry.value) c.eventId};
        final pending = [
          for (final c in next[entry.key] ?? const <Comment>[])
            if (!known.contains(c.eventId)) c,
        ];
        next[entry.key] = [...entry.value, ...pending]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      state = next;
    } on Object {
      for (final id in ids) {
        _requested.remove(id);
      }
    }
  }

  /// Comenta [target]. Devolve a mensagem de erro para a tela, ou `null`.
  Future<String?> add(CommentTarget target, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return 'Escreva alguma coisa antes de enviar.';
    if (clean.length > CommentEvent.maxLength) {
      return 'O comentário pode ter até ${CommentEvent.maxLength} caracteres.';
    }
    try {
      final comment =
          await ref.read(commentServiceProvider).publish(target, clean);
      state = {
        ...state,
        target.eventId: [...of(target.eventId), comment],
      };
      return null;
    } on PostPublishException catch (e) {
      return e.message;
    } on Object {
      return const PostPublishException().message;
    }
  }
}

final commentsProvider = NotifierProvider.autoDispose<CommentsController,
    Map<String, List<Comment>>>(
  CommentsController.new,
);
