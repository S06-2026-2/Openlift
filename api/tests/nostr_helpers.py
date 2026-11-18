"""Ferramentas de teste para NOSTR: assinar eventos e simular relays.

O backend nunca assina evento (ADR-0006). Assinar existe **só aqui**, para
produzir eventos de "outros clientes" (likes, treinos) que o worker vai ler.
As chaves são derivadas de um rótulo em tempo de execução: nenhuma chave
privada fica versionada (RNF-01, gitleaks), igual aos testes do app.
"""

import hashlib
import json
from collections.abc import Iterable
from typing import Any

import websockets

from app.core import schnorr
from app.core.nostr import compute_event_id

Event = dict[str, Any]


# ---------------------------------------------------------------------------
# Chaves e assinatura (BIP-340), só para testes
# ---------------------------------------------------------------------------


def secret_for(label: str) -> int:
    """Chave privada descartável e determinística para um rótulo de teste."""
    return (
        int.from_bytes(hashlib.sha256(f"openlift-teste:{label}".encode()).digest(), "big")
        % (schnorr.N - 1)
        + 1
    )


def _point(secret: int) -> tuple[int, int]:
    affine = schnorr._to_affine(schnorr._multiply(schnorr._to_jacobian(schnorr.G), secret))
    assert affine is not None
    return affine


def pubkey_of(secret: int) -> str:
    return _point(secret)[0].to_bytes(32, "big").hex()


def sign(message: bytes, secret: int) -> bytes:
    """Assinatura BIP-340 (referência do BIP, com aux = 32 bytes zero)."""
    px, py = _point(secret)
    d = secret if py % 2 == 0 else schnorr.N - secret
    t = d ^ int.from_bytes(schnorr._tagged_hash("BIP0340/aux", bytes(32)), "big")
    pk = px.to_bytes(32, "big")
    k0 = (
        int.from_bytes(
            schnorr._tagged_hash("BIP0340/nonce", t.to_bytes(32, "big") + pk + message), "big"
        )
        % schnorr.N
    )
    rx, ry = _point(k0)
    k = k0 if ry % 2 == 0 else schnorr.N - k0
    r = rx.to_bytes(32, "big")
    e = (
        int.from_bytes(schnorr._tagged_hash("BIP0340/challenge", r + pk + message), "big")
        % schnorr.N
    )
    return r + ((k + e * d) % schnorr.N).to_bytes(32, "big")


def make_event(
    label: str,
    *,
    kind: int,
    tags: list[list[str]] | None = None,
    content: str = "",
    created_at: int = 1_792_445_400,
) -> Event:
    secret = secret_for(label)
    event: Event = {
        "pubkey": pubkey_of(secret),
        "created_at": created_at,
        "kind": kind,
        "tags": tags or [],
        "content": content,
    }
    event["id"] = compute_event_id(event)
    event["sig"] = sign(bytes.fromhex(event["id"]), secret).hex()
    return event


def make_reaction(
    label: str, target: Event, *, content: str = "+", created_at: int = 1_792_446_000
) -> Event:
    """Like NIP-25 (`kind 7`) de `label` sobre o evento `target`."""
    return make_event(
        label,
        kind=7,
        tags=[["e", target["id"]], ["p", target["pubkey"]], ["k", str(target["kind"])]],
        content=content,
        created_at=created_at,
    )


def tampered(event: Event, **changes: Any) -> Event:
    """Cópia do evento com campos trocados, sem reassinar."""
    copy = json.loads(json.dumps(event))
    copy.update(changes)
    return copy


# ---------------------------------------------------------------------------
# Relay falso
# ---------------------------------------------------------------------------


def matches(event: Event, flt: dict[str, Any]) -> bool:
    """Filtro da NIP-01 (o suficiente para os testes)."""
    if "ids" in flt and event["id"] not in flt["ids"]:
        return False
    if "kinds" in flt and event["kind"] not in flt["kinds"]:
        return False
    if "authors" in flt and event["pubkey"] not in flt["authors"]:
        return False
    if "since" in flt and event["created_at"] < flt["since"]:
        return False
    if "until" in flt and event["created_at"] > flt["until"]:
        return False
    for key, values in flt.items():
        if key.startswith("#"):
            name = key[1:]
            if not any(
                tag and tag[0] == name and len(tag) > 1 and tag[1] in values
                for tag in event["tags"]
            ):
                return False
    return True


class FakeRelay:
    """Relay em memória. `fail_connects` conexões recusadas antes de aceitar;
    `drop_after` derruba a 1ª conexão depois de N eventos enviados."""

    def __init__(
        self, events: Iterable[Event] = (), *, fail_connects: int = 0, drop_after: int | None = None
    ) -> None:
        self.events = list(events)
        self.fail_connects = fail_connects
        self.drop_after = drop_after
        self.connections = 0
        self.requests: list[list[Any]] = []

    def connect(self, url: str) -> "_FakeSocket":
        self.connections += 1
        if self.fail_connects > 0:
            self.fail_connects -= 1
            raise OSError(f"conexão recusada: {url}")
        drop = self.drop_after
        self.drop_after = None
        return _FakeSocket(self, drop)


class _FakeSocket:
    def __init__(self, relay: FakeRelay, drop_after: int | None) -> None:
        self.relay = relay
        self.drop_after = drop_after
        self.outbox: list[Any] = []
        self.sent_events = 0

    async def __aenter__(self) -> "_FakeSocket":
        return self

    async def __aexit__(self, *exc: object) -> bool:
        return False

    async def send(self, data: str) -> None:
        message = json.loads(data)
        if message[0] != "REQ":
            return
        self.relay.requests.append(message)
        sub, filters = message[1], message[2:]
        for event in self.relay.events:
            if any(matches(event, f) for f in filters):
                self.outbox.append(["EVENT", sub, event])
        self.outbox.append(["EOSE", sub])

    async def recv(self) -> str:
        if self.drop_after is not None and self.sent_events >= self.drop_after:
            raise websockets.exceptions.ConnectionClosedError(None, None)
        message = self.outbox.pop(0)
        if message[0] == "EVENT":
            self.sent_events += 1
        return json.dumps(message)


class MultiRelay:
    """Despacha cada URL para um FakeRelay diferente."""

    def __init__(self, relays: dict[str, FakeRelay]) -> None:
        self.relays = relays

    def connect(self, url: str) -> _FakeSocket:
        return self.relays[url].connect(url)
