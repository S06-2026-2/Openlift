"""Seed da biblioteca de exercícios (BE-03, RF-10): 10 grupos musculares e
40 exercícios comuns.

Idempotente: pode rodar quantas vezes quiser. Cria o que falta, corrige o
grupo de um exercício que mudou de lugar e nunca duplica (busca por nome).

Uso (com o banco migrado):
    docker compose run --rm api python -m app.infra.db.seed
"""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.models.exercise import Exercise
from app.domain.models.muscle_group import MuscleGroup

LIBRARY: dict[str, list[str]] = {
    "Peito": ["Supino reto", "Supino inclinado", "Crucifixo com halteres", "Flexão de braço"],
    "Costas": ["Puxada frontal", "Remada curvada", "Remada baixa", "Barra fixa"],
    "Ombros": [
        "Desenvolvimento com halteres",
        "Elevação lateral",
        "Elevação frontal",
        "Crucifixo invertido",
    ],
    "Bíceps": ["Rosca direta", "Rosca alternada", "Rosca martelo", "Rosca Scott"],
    "Tríceps": ["Tríceps pulley", "Tríceps testa", "Tríceps francês", "Mergulho entre bancos"],
    "Quadríceps": [
        "Agachamento livre",
        "Leg press 45°",
        "Cadeira extensora",
        "Agachamento búlgaro",
    ],
    "Posterior": ["Levantamento terra romeno", "Stiff", "Mesa flexora", "Cadeira flexora"],
    "Glúteos": ["Elevação pélvica", "Afundo", "Glúteo na polia", "Cadeira abdutora"],
    "Panturrilha": [
        "Panturrilha em pé",
        "Panturrilha sentado",
        "Panturrilha no leg press",
        "Panturrilha unilateral",
    ],
    "Abdômen": ["Abdominal crunch", "Prancha", "Elevação de pernas", "Abdominal na polia"],
}


@dataclass
class SeedResult:
    groups_created: int = 0
    exercises_created: int = 0
    exercises_updated: int = 0

    def __str__(self) -> str:
        return (
            f"grupos criados: {self.groups_created} · "
            f"exercícios criados: {self.exercises_created} · "
            f"exercícios corrigidos: {self.exercises_updated}"
        )


def seed_exercises(db: Session) -> SeedResult:
    result = SeedResult()
    groups = {g.name: g for g in db.scalars(select(MuscleGroup))}
    exercises = {e.name: e for e in db.scalars(select(Exercise))}

    for group_name, exercise_names in LIBRARY.items():
        group = groups.get(group_name)
        if group is None:
            group = MuscleGroup(name=group_name)
            db.add(group)
            db.flush()  # garante o id antes de ligar os exercícios
            groups[group_name] = group
            result.groups_created += 1

        for exercise_name in exercise_names:
            exercise = exercises.get(exercise_name)
            if exercise is None:
                db.add(Exercise(name=exercise_name, muscle_group_id=group.id))
                result.exercises_created += 1
            elif exercise.muscle_group_id != group.id:
                exercise.muscle_group_id = group.id
                result.exercises_updated += 1

    db.commit()
    return result


def main() -> None:
    from app.infra.db.session import SessionLocal

    with SessionLocal() as db:
        result = seed_exercises(db)
    print(f"Seed de exercícios concluído — {result}")


if __name__ == "__main__":
    main()
