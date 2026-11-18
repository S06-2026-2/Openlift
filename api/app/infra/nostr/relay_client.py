"""Cliente WebSocket dos relays NOSTR, em modo **somente leitura** (BE-08).

O backend nunca assina nem publica evento (ADR-0006). Este cliente só faz
`REQ` com filtros da NIP-01, junta os eventos de todos os relays até o
`EOSE` e devolve **apenas eventos verificados** (RF-51, RNF-02): estrutura,
`id` recalculado e assinatura Schnorr. Evento inválido é descartado e
registrado em log com o `event_id` (RNF-14), nunca "consertado".

- Relays vêm de `settings.NOSTR_RELAYS` (ADR-0007), nunca de URL no código.
- Relay fora do ar ou que cai no meio da leitura: nova tentativa com backoff
  exponencial (RF-50). Esgotadas as tentativas, os demais relays seguem.
- Mesmo evento vindo de relays diferentes aparece uma vez (dedup por `id`).

Uso (dentro de uma corrotina):

    client = RelayClient.from_settings()
    events = await client.fetch([{"kinds": [7], "#e": event_ids}])
"""

import asyncio
import json
import logging
import uuid
from collections.abc import Awaitable, Callable, Sequence
from typing import Any

import websockets

from app.core.config import get_settings
from app.core.nostr import event_problem

logger = logging.getLogger("openlift.nostr")

Filter = dict[str, Any]
Event = dict[str, Any]
Connect = Callable[[str], Any]  # devolve um async context manager com send/recv
Sleep = Callable[[float], Awaitable[None]]


class RelayDisconnected(Exception):
    """O relay fechou a conexão antes do `EOSE`."""


def _default_connect(url: str) -> Any:
    return websockets.connect(url, open_timeout=10, close_timeout=2, max_size=2**22)


class RelayClient:
    def __init__(
        self,
        relay_urls: Sequence[str],
        *,
        timeout: float = 10.0,
        max_retries: int = 3,
        backoff_base: float = 0.5,
        connect: Connect = _default_connect,
        sleep: Sleep = asyncio.sleep,
    ) -> None:
        self.relay_urls = list(relay_urls)
        self.timeout = timeout
        self.max_retries = max_retries
        self.backoff_base = backoff_base
        self._connect = connect
        self._sleep = sleep

    @classmethod
    def from_settings(cls) -> "RelayClient":
        settings = get_settings()
        return cls(
            settings.nostr_relay_urls,
            timeout=settings.nostr_relay_timeout_seconds,
            max_retries=settings.nostr_relay_max_retries,
        )

    async def fetch(self, filters: Sequence[Filter]) -> list[Event]:
        """Eventos verificados que casam com `filters`, de todos os relays,
        sem repetição, do mais antigo para o mais novo."""
        if not filters or not self.relay_urls:
            return []
        per_relay = await asyncio.gather(
            *(self._fetch_with_retry(url, filters) for url in self.relay_urls)
        )
        seen: dict[str, Event] = {}
        for url, events in zip(self.relay_urls, per_relay, strict=True):
            for event in events:
                event_id = event.get("id") if isinstance(event, dict) else None
                if isinstance(event_id, str) and event_id in seen:
                    continue
                problem = event_problem(event)
                if problem:
                    logger.warning(
                        "Evento NOSTR descartado: %s",
                        problem,
                        extra={"event_id": event_id, "relay": url, "reason": problem},
                    )
                    continue
                seen[event["id"]] = event
        return sorted(seen.values(), key=lambda e: (e["created_at"], e["id"]))

    async def _fetch_with_retry(self, url: str, filters: Sequence[Filter]) -> list[Event]:
        received: list[Event] = []
        for attempt in range(self.max_retries + 1):
            try:
                await self._fetch_once(url, filters, received)
                return received
            except Exception as exc:  # noqa: BLE001 — qualquer falha de rede vira nova tentativa
                if attempt == self.max_retries:
                    logger.error(
                        "Relay indisponível depois de %d tentativas: %s",
                        attempt + 1,
                        type(exc).__name__,
                        extra={"relay": url, "attempts": attempt + 1},
                    )
                    return received
                delay = self.backoff_base * 2**attempt
                logger.warning(
                    "Falha ao ler o relay (%s); nova tentativa em %.1f s",
                    type(exc).__name__,
                    delay,
                    extra={"relay": url, "attempt": attempt + 1},
                )
                await self._sleep(delay)
        return received  # pragma: no cover — o laço sempre retorna

    async def _fetch_once(self, url: str, filters: Sequence[Filter], received: list[Event]) -> None:
        subscription = uuid.uuid4().hex[:16]
        async with self._connect(url) as ws:
            await ws.send(json.dumps(["REQ", subscription, *filters]))
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=self.timeout)
                except websockets.ConnectionClosed as exc:
                    raise RelayDisconnected(url) from exc
                message = _parse(raw)
                if message is None:
                    continue
                kind = message[0]
                if kind == "EVENT" and len(message) >= 3 and message[1] == subscription:
                    received.append(message[2])
                elif kind == "EOSE" and len(message) >= 2 and message[1] == subscription:
                    await ws.send(json.dumps(["CLOSE", subscription]))
                    return
                elif kind == "CLOSED" and len(message) >= 2 and message[1] == subscription:
                    reason = message[2] if len(message) > 2 else ""
                    logger.warning("Relay encerrou a assinatura: %s", reason, extra={"relay": url})
                    return


def _parse(raw: Any) -> list[Any] | None:
    try:
        message = json.loads(raw)
    except (TypeError, ValueError):
        return None
    if not isinstance(message, list) or not message or not isinstance(message[0], str):
        return None
    return message
