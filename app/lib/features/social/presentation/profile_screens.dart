// Telas de perfil da rede social (ADR-0012):
// - [ProfileSetupView]: cadastro de perfil, antes de entrar na aba Social;
// - [ProfileEditScreen]: editar o próprio perfil;
// - [PeopleSearchScreen]: buscar pessoas pelo nome de usuário;
// - [PersonProfileScreen]: perfil de uma pessoa, com seguir, a grade de
//   fotos e os treinos publicados.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/page_layout.dart';
import '../../workouts/presentation/widgets/state_views.dart';
import '../../../core/nostr/nostr_kinds.dart';
import '../domain/comment.dart';
import '../domain/photo_post.dart';
import '../domain/profile_model.dart';
import 'network_feed_controller.dart';
import 'posts_controller.dart';
import 'profile_controller.dart';
import 'profile_form.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/feed_workout_card.dart';
import 'widgets/photo_post_card.dart';
import 'widgets/profile_avatar.dart';

/// Primeiro acesso à aba Social: escolher o nome de usuário.
class ProfileSetupView extends StatelessWidget {
  const ProfileSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: pagePadding(constraints, top: 32),
        children: [
          const PageHeader(
            title: 'Crie seu perfil',
            subtitle: 'Escolha um nome de usuário para postar fotos, '
                'compartilhar treinos e encontrar outras pessoas.',
          ),
          const SizedBox(height: 28),
          ProfileForm(
            onSaved: (warning) {
              if (warning != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(warning)));
              }
            },
          ),
        ],
      ),
    );
  }
}

class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.feed)),
      ),
      body: profile.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorStateView(
          message: profileErrorMessage(error),
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
        data: (current) => LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: pagePadding(constraints, top: 32),
            children: [
              ProfileForm(
                initial: current,
                onSaved: (warning) {
                  final messenger = ScaffoldMessenger.of(context);
                  context.go(AppRoutes.feed);
                  messenger.showSnackBar(
                    SnackBar(content: Text(warning ?? 'Perfil atualizado.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  ConsumerState<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() => setState(() => _query = _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results =
        _query.isEmpty ? null : ref.watch(peopleSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar pessoas'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.feed)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: pagePadding(constraints, top: 20),
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Nome de usuário',
                hintText: '@nome',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (results == null)
              Text(
                'Digite o nome de usuário ou parte do nome. Para achar alguém '
                'pelo ID, use Treinos → Da rede.',
                style: theme.textTheme.bodySmall,
              )
            else
              ...results.when(
                loading: () => const [
                  SizedBox(height: 120, child: LoadingIndicator()),
                ],
                error: (error, _) => [Text(profileErrorMessage(error))],
                data: (people) => people.isEmpty
                    ? [
                        Text(
                          'Ninguém encontrado com "$_query".',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ]
                    : [
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < people.length; i++) ...[
                                if (i > 0) const Divider(),
                                _PersonTile(profile: people[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ProfileAvatar(name: profile.title, url: profile.avatarUrl),
      title: Text(profile.title),
      subtitle: profile.displayName == null ? null : Text(profile.handle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(AppRoutes.person(profile.username)),
    );
  }
}

/// Cabeçalho de perfil: foto, nomes, bio e o nome verificado (NIP-05).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, this.action});

  final SocialProfile profile;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProfileAvatar(
              name: profile.title,
              url: profile.avatarUrl,
              radius: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.title, style: theme.textTheme.headlineSmall),
                  if (profile.displayName != null)
                    Text(profile.handle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          profile.nip05,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.bio != null) ...[
          const SizedBox(height: 12),
          Text(profile.bio!, style: theme.textTheme.bodyMedium),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );
  }
}

class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByUsernameProvider(username));

    return Scaffold(
      appBar: AppBar(
        title: Text('@${normalizeUsername(username)}'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.feed)),
      ),
      body: profile.when(
        loading: () => const LoadingIndicator(message: 'Carregando perfil...'),
        error: (error, _) => ErrorStateView(
          message: profileErrorMessage(error),
          onRetry: () => ref.invalidate(profileByUsernameProvider(username)),
        ),
        data: (person) => _PersonBody(profile: person),
      ),
    );
  }
}

class _PersonBody extends ConsumerWidget {
  const _PersonBody({required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = ref.watch(myProfileProvider).valueOrNull;
    final isMe = mine?.pubkey == profile.pubkey;
    final workouts = ref.watch(personWorkoutsProvider(profile.pubkey));
    final posts = ref.watch(personPostsProvider(profile.pubkey));
    ref.watch(postLikesProvider);
    ref.listen(personPostsProvider(profile.pubkey), (_, next) {
      ref
          .read(postLikesProvider.notifier)
          .fetch(next.valueOrNull ?? const <PhotoPost>[]);
    });

    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: pagePadding(constraints, top: 24),
        children: [
          ProfileHeader(
            profile: profile,
            action: isMe
                ? AppButton(
                    label: 'Editar perfil',
                    icon: Icons.edit_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go(AppRoutes.profileEdit),
                  )
                : FollowButton(pubkey: profile.pubkey),
          ),
          const SizedBox(height: 28),
          SectionLabel(
            posts.valueOrNull == null
                ? 'Fotos'
                : posts.valueOrNull!.length == 1
                    ? '1 foto'
                    : '${posts.valueOrNull!.length} fotos',
          ),
          const SizedBox(height: 12),
          posts.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, __) => Text(
              'Não deu para ler as fotos agora.',
              style: theme.textTheme.bodySmall,
            ),
            data: (items) => items.isEmpty
                ? Text(
                    'Nenhuma foto publicada ainda.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : _PhotoGrid(posts: items, author: profile),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Treinos publicados'),
          const SizedBox(height: 12),
          ...workouts.when(
            loading: () => const [LinearProgressIndicator(minHeight: 2)],
            error: (_, __) => [
              Text(
                'Não deu para ler os treinos agora.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            data: (feed) => feed.workouts.isEmpty
                ? [
                    Text(
                      'Nenhum treino publicado ainda.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                : [
                    for (final workout in feed.workouts) ...[
                      FeedWorkoutCard(workout: workout, author: profile),
                      const SizedBox(height: 12),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

/// Seguir / Seguindo (publica a contact list, kind 3).
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.pubkey});

  final String pubkey;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  Future<void> _toggle(bool following) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(followingProvider.notifier);
    final error = following
        ? await notifier.unfollow(widget.pubkey)
        : await notifier.followPubkey(widget.pubkey);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(followingProvider).valueOrNull;
    final following = contacts?.contains(widget.pubkey) ?? false;

    return AppButton(
      label: following ? 'Seguindo' : 'Seguir',
      icon: following ? Icons.check_rounded : Icons.person_add_alt_rounded,
      variant:
          following ? AppButtonVariant.secondary : AppButtonVariant.primary,
      isLoading: _busy,
      onPressed: contacts == null ? null : () => _toggle(following),
    );
  }
}

/// Grade de fotos (3 colunas); tocar abre a postagem inteira.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.posts, required this.author});

  final List<PhotoPost> posts;
  final SocialProfile author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        return Semantics(
          button: true,
          label: post.caption.isEmpty ? 'Foto' : post.caption,
          child: InkWell(
            key: ValueKey('photo-${post.eventId}'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: PhotoPostCard(
                    post: post,
                    author: author,
                    footer: CommentButton(
                      target: CommentTarget(
                        eventId: post.eventId,
                        pubkey: post.pubkey,
                        kind: NostrKinds.picture,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
