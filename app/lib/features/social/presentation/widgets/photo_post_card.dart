// Card de uma postagem de foto (ADR-0012): autor, foto, curtir e legenda.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/nostr/nip19.dart';
import '../../../../core/router/app_routes.dart';
import '../../domain/photo_post.dart';
import '../../domain/profile_model.dart';
import '../network_workouts_view.dart' show shortNpub;
import '../posts_controller.dart';
import 'profile_avatar.dart';

/// "agora", "há 5 min", "há 3 h", "há 2 d" ou a data.
String timeAgo(DateTime when, DateTime now) {
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inHours < 1) return 'há ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'há ${diff.inHours} h';
  if (diff.inDays < 7) return 'há ${diff.inDays} d';
  final d = when.day.toString().padLeft(2, '0');
  final m = when.month.toString().padLeft(2, '0');
  return '$d/$m/${when.year}';
}

class PhotoPostCard extends StatelessWidget {
  const PhotoPostCard({
    super.key,
    required this.post,
    this.author,
    this.footer,
  });

  final PhotoPost post;
  final SocialProfile? author;

  /// Ações extras abaixo da foto (comentários entram aqui).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = author;
    final name = profile?.handle ?? shortNpub(Nip19.encodeNpub(post.pubkey));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: profile == null
                ? null
                : () => context.go(AppRoutes.person(profile.username)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  ProfileAvatar(
                    name: profile?.title ?? name,
                    url: profile?.avatarUrl,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    timeAgo(post.publishedAt, DateTime.now()),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: post.aspectRatio,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                semanticLabel: post.caption.isEmpty ? 'Foto' : post.caption,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(
              children: [
                PostLikeButton(post: post),
                if (footer != null) footer!,
              ],
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$name ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class PostLikeButton extends ConsumerWidget {
  const PostLikeButton({super.key, required this.post});

  final PhotoPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(
      postLikesProvider.select((state) => state[post.eventId]),
    );
    final liked = likes?.likedByMe ?? false;
    final count = likes?.count ?? 0;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: liked ? 'Você curtiu' : 'Curtir foto',
          onPressed: liked
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final error =
                      await ref.read(postLikesProvider.notifier).like(post);
                  if (error != null) {
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                  }
                },
          icon: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: liked ? theme.colorScheme.primary : null,
          ),
        ),
        Text(
          count == 1 ? '1 curtida' : '$count curtidas',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
