"""Comandos de operação da API.

    python -m app.cli replay            # reconstrói likes a partir dos relays
    python -m app.cli replay --dry-run  # mostra o resultado sem gravar

Usa as mesmas variáveis da API (`DATABASE_URL`, `NOSTR_RELAYS`...). Passo a
passo em docs/runbook/replay.md.
"""

import argparse
import asyncio
import logging
import sys
from collections.abc import Sequence

from app.infra.nostr.relay_client import RelayClient
from app.services.replay_service import ReplayAborted, ReplayResult, replay_likes


def _summary(result: ReplayResult, dry_run: bool) -> str:
    title = "Replay (simulação, nada gravado)" if dry_run else "Replay concluído"
    return "\n".join(
        [
            f"{title}:",
            f"  treinos publicados: {result.shared_events}",
            f"  relays que responderam: {result.relays_ok} de {result.relays_total}",
            f"  reações kind 7 verificadas: {result.reactions}",
            f"  likes antes: {result.likes_before}",
            f"  likes depois: {result.likes_after}",
            f"  tempo: {result.seconds:.1f} s",
        ]
    )


def _replay(dry_run: bool) -> int:
    from app.infra.db.session import SessionLocal

    with SessionLocal() as db:
        try:
            result = asyncio.run(replay_likes(db, RelayClient.from_settings(), dry_run=dry_run))
        except ReplayAborted as exc:
            print(f"Replay cancelado: {exc}", file=sys.stderr)
            return 1
    print(_summary(result, dry_run))
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    replay = commands.add_parser(
        "replay", help="Apaga o cache de likes e reconstrói a partir dos relays (RF-53)"
    )
    replay.add_argument("--dry-run", action="store_true", help="Calcula sem gravar nada no banco")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    if args.command == "replay":
        return _replay(args.dry_run)
    return 2  # pragma: no cover — o argparse já recusa comando desconhecido


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
