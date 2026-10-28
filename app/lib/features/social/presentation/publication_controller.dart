// FE-05 — Estado das publicações desta sessão, por treino (RF-22, RF-25).
//
// O status durável (local/publicado/falhou) vem do backend no WorkoutModel.
// Aqui fica o que só existe enquanto o app está aberto: "publicando...", o
// resultado de cada relay e a mensagem de erro da última tentativa.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../workouts/domain/workout_model.dart';
import '../../workouts/presentation/workout_controller.dart';
import '../data/nostr_relay_service.dart';
import '../data/workout_publisher.dart';
import '../domain/workout_event_adapter.dart';

@immutable
class PublicationState {
  const PublicationState({
    this.isPublishing = false,
    this.relays = const [],
    this.errorMessage,
  });

  final bool isPublishing;

  /// Resultado por relay da última tentativa (vazio enquanto publica).
  final List<RelayPublishResult> relays;
  final String? errorMessage;

  int get acceptedCount => relays.where((r) => r.accepted).length;

  bool get hasFailedRelay => relays.any((r) => !r.accepted);

  /// Resumo da tentativa para o SnackBar.
  String get summary {
    final error = errorMessage;
    if (error != null) return error;
    if (acceptedCount == 0) {
      return 'Nenhum relay aceitou o treino. Tente novamente pelo histórico.';
    }
    return 'Treino publicado em $acceptedCount de ${relays.length} '
        '${relays.length == 1 ? 'relay' : 'relays'}.';
  }
}

class PublicationController extends Notifier<Map<int, PublicationState>> {
  @override
  Map<int, PublicationState> build() => const {};

  Future<bool> hasConsent() => ref.read(workoutPublisherProvider).hasConsent();

  Future<void> saveConsent() =>
      ref.read(workoutPublisherProvider).saveConsent();

  /// Publica (ou republica) o treino salvo e devolve como terminou. `null`
  /// quando não começou (treino sem id ou já publicando). Nunca lança.
  Future<PublicationState?> publish(WorkoutModel workout) async {
    final id = workout.id;
    if (id == null || state[id]?.isPublishing == true) return null;
    _set(id, const PublicationState(isPublishing: true));

    PublicationState result;
    try {
      final library = await ref.read(exerciseLibraryProvider.future);
      final outcome = await ref.read(workoutPublisherProvider).publish(
        workout,
        {for (final exercise in library) exercise.id: exercise},
      );
      result = PublicationState(relays: outcome.relays);
    } on WorkoutEventException catch (e) {
      result = PublicationState(errorMessage: e.message);
    } on ApiException catch (e) {
      result = PublicationState(errorMessage: e.message);
    } on Object {
      result = const PublicationState(
        errorMessage: 'Não foi possível publicar o treino. Tente novamente.',
      );
    }
    _set(id, result);
    // O status durável mudou (ou pode ter mudado) no backend.
    ref.invalidate(workoutControllerProvider);
    ref.invalidate(workoutByIdProvider(id));
    return result;
  }

  void _set(int id, PublicationState value) => state = {...state, id: value};
}

final publicationControllerProvider =
    NotifierProvider<PublicationController, Map<int, PublicationState>>(
  PublicationController.new,
);
