// Formulário do perfil (ADR-0012): foto, nome de usuário único, nome de
// exibição e bio. O mesmo formulário serve para criar (antes de entrar na
// aba Social) e para editar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../data/photo_picker.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';
import 'profile_controller.dart';
import 'widgets/profile_avatar.dart';

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, this.initial, this.onSaved});

  /// Perfil atual, ao editar. `null` = criação.
  final SocialProfile? initial;

  /// Chamado depois de salvar (com o aviso de publicação, se houver).
  final void Function(String? warning)? onSaved;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

enum _Availability { unknown, checking, available, taken }

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _displayName;
  late final TextEditingController _bio;

  String? _avatarUrl;
  ImageProvider? _avatarPreview;
  bool _uploading = false;
  bool _saving = false;
  String? _error;
  _Availability _availability = _Availability.unknown;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _username = TextEditingController(text: initial?.username ?? '');
    _displayName = TextEditingController(text: initial?.displayName ?? '');
    _bio = TextEditingController(text: initial?.bio ?? '');
    _avatarUrl = initial?.avatarUrl;
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await ref.read(photoPickerProvider).pick();
    if (photo == null || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final media = await ref
          .read(profileRepositoryProvider)
          .uploadPhoto(photo.bytes, photo.name);
      if (!mounted) return;
      setState(() {
        _avatarUrl = media.url;
        _avatarPreview = MemoryImage(photo.bytes);
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = profileErrorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _checkAvailability() async {
    if (validateUsername(_username.text) != null) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _availability = _Availability.checking);
    try {
      final free =
          await ref.read(profileRepositoryProvider).isAvailable(_username.text);
      if (!mounted) return;
      setState(() =>
          _availability = free ? _Availability.available : _Availability.taken);
    } on Object {
      if (mounted) setState(() => _availability = _Availability.unknown);
    }
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final warning = await ref.read(myProfileProvider.notifier).save(
            ProfileInput(
              username: _username.text,
              displayName: _displayName.text,
              bio: _bio.text,
              avatarUrl: _avatarUrl,
            ),
          );
      widget.onSaved?.call(warning);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = profileErrorMessage(e);
          if (_error!.contains('em uso')) _availability = _Availability.taken;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? get _availabilityText => switch (_availability) {
        _Availability.available => 'Disponível',
        _Availability.taken => 'Esse nome já está em uso',
        _Availability.checking => 'Verificando...',
        _Availability.unknown => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _displayName.text.isNotEmpty
        ? _displayName.text
        : (_username.text.isNotEmpty ? _username.text : 'OpenLift');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                ProfileAvatar(
                  name: name,
                  url: _avatarUrl,
                  image: _avatarPreview,
                  radius: 48,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: 'Escolher foto',
                    onPressed: _uploading ? null : _pickPhoto,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _username,
            autocorrect: false,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_availability != _Availability.unknown) {
                setState(() => _availability = _Availability.unknown);
              }
            },
            onFieldSubmitted: (_) => _checkAvailability(),
            validator: (value) => validateUsername(value ?? ''),
            decoration: InputDecoration(
              labelText: 'Nome de usuário',
              prefixText: '@',
              helperText: _availabilityText ??
                  'Único na rede. 3 a 20 letras sem acento, números, _ ou ponto.',
              helperStyle: _availability == _Availability.taken
                  ? TextStyle(color: theme.colorScheme.error)
                  : _availability == _Availability.available
                      ? TextStyle(color: theme.colorScheme.secondary)
                      : null,
              suffixIcon: IconButton(
                tooltip: 'Verificar nome',
                icon: Icon(
                  _availability == _Availability.available
                      ? Icons.check_circle_rounded
                      : Icons.manage_search_rounded,
                  size: 20,
                ),
                onPressed: _checkAvailability,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _displayName,
            enabled: !_saving,
            maxLength: 50,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nome (opcional)',
              hintText: 'Como você quer aparecer',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _bio,
            enabled: !_saving,
            maxLength: 160,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Bio (opcional)',
              hintText: 'Seu treino, seus objetivos, sua modalidade',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seu perfil, suas fotos e o que você publicar aqui ficam públicos '
            'na rede aberta NOSTR, visíveis em qualquer app compatível. A '
            'localização das fotos é removida antes de publicar.',
            style: theme.textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: _isEditing ? 'Salvar perfil' : 'Criar perfil',
            icon:
                _isEditing ? Icons.check_rounded : Icons.arrow_forward_rounded,
            isLoading: _saving,
            onPressed: _uploading ? null : _save,
          ),
        ],
      ),
    );
  }
}
