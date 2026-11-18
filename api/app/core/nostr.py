"""NOSTR no backend: `npub` (NIP-19) e verificação de evento (NIP-01).

- NIP-19: conversão entre a chave pública em hex e o `npub` (bech32, BIP-173).
- NIP-01: estrutura, `id` e assinatura de um evento lido do relay (BE-08,
  RF-51, RNF-02). Evento que não passa aqui não chega a nenhuma projeção.

O backend só lida com chave PÚBLICA (ADR-0006). Não existe aqui, de propósito,
nada que leia ou produza `nsec`, nem nada que assine evento.
"""

import hashlib
import json
import re
from typing import Any

from app.core import schnorr

_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
_GENERATOR = (0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3)
_NPUB_HRP = "npub"
_NPUB_LENGTH = 63  # "npub1" + 52 caracteres de dado + 6 de checksum

# Kinds do mini-NIP (docs/nips/openlift-workout-event.md §1), em constante única.
KIND_WORKOUT_RECORD = 1301
KIND_REACTION = 7  # NIP-25


def _polymod(values: list[int]) -> int:
    checksum = 1
    for value in values:
        top = checksum >> 25
        checksum = (checksum & 0x1FFFFFF) << 5 ^ value
        for i, generator in enumerate(_GENERATOR):
            if (top >> i) & 1:
                checksum ^= generator
    return checksum


def _hrp_expand(hrp: str) -> list[int]:
    return [ord(c) >> 5 for c in hrp] + [0] + [ord(c) & 31 for c in hrp]


def _convert_bits(data: list[int], from_bits: int, to_bits: int, pad: bool) -> list[int]:
    acc = bits = 0
    result: list[int] = []
    max_value = (1 << to_bits) - 1
    for value in data:
        acc = (acc << from_bits) | value
        bits += from_bits
        while bits >= to_bits:
            bits -= to_bits
            result.append((acc >> bits) & max_value)
    if pad:
        if bits:
            result.append((acc << (to_bits - bits)) & max_value)
    elif bits >= from_bits or (acc << (to_bits - bits)) & max_value:
        raise ValueError("npub com preenchimento inválido")
    return result


def npub_to_hex(npub: str) -> str:
    """`npub1...` → chave pública x-only em hex. Lança ValueError se inválido."""
    if len(npub) != _NPUB_LENGTH or npub != npub.lower():
        raise ValueError("npub deve ter 63 caracteres minúsculos")
    hrp, separator, data_part = npub.rpartition("1")
    if hrp != _NPUB_HRP or not separator:
        raise ValueError("npub deve começar com 'npub1'")
    if any(c not in _CHARSET for c in data_part):
        raise ValueError("npub com caractere fora do alfabeto bech32")
    data = [_CHARSET.index(c) for c in data_part]
    if _polymod(_hrp_expand(hrp) + data) != 1:
        raise ValueError("npub com checksum inválido")
    key = _convert_bits(data[:-6], 5, 8, pad=False)
    if len(key) != 32:
        raise ValueError("npub deve conter 32 bytes")
    return bytes(key).hex()


def hex_to_npub(pubkey_hex: str) -> str:
    """Chave pública x-only em hex (64 caracteres) → `npub1...`."""
    key = bytes.fromhex(pubkey_hex)
    if len(key) != 32:
        raise ValueError("chave pública deve ter 32 bytes")
    data = _convert_bits(list(key), 8, 5, pad=True)
    polymod = _polymod(_hrp_expand(_NPUB_HRP) + data + [0] * 6) ^ 1
    checksum = [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
    return _NPUB_HRP + "1" + "".join(_CHARSET[d] for d in data + checksum)


# ---------------------------------------------------------------------------
# NIP-01: evento
# ---------------------------------------------------------------------------

_HEX64 = re.compile(r"^[0-9a-f]{64}$")
_HEX128 = re.compile(r"^[0-9a-f]{128}$")
_EVENT_FIELDS = frozenset({"id", "pubkey", "created_at", "kind", "tags", "content", "sig"})


def compute_event_id(event: dict[str, Any]) -> str:
    """SHA-256 da serialização canônica da NIP-01, em hex minúsculo."""
    payload = [
        0,
        event["pubkey"],
        event["created_at"],
        event["kind"],
        event["tags"],
        event["content"],
    ]
    serialized = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def _structure_problem(event: Any) -> str | None:
    if not isinstance(event, dict) or set(event) != _EVENT_FIELDS:
        return "campos fora do formato da NIP-01"
    if not isinstance(event["id"], str) or not _HEX64.match(event["id"]):
        return "id não é hex de 64 caracteres"
    if not isinstance(event["pubkey"], str) or not _HEX64.match(event["pubkey"]):
        return "pubkey não é hex de 64 caracteres"
    if not isinstance(event["sig"], str) or not _HEX128.match(event["sig"]):
        return "sig não é hex de 128 caracteres"
    created_at = event["created_at"]
    if isinstance(created_at, bool) or not isinstance(created_at, int) or created_at < 0:
        return "created_at não é inteiro em segundos"
    if isinstance(event["kind"], bool) or not isinstance(event["kind"], int):
        return "kind não é inteiro"
    tags = event["tags"]
    if not isinstance(tags, list) or not all(
        isinstance(tag, list) and all(isinstance(value, str) for value in tag) for tag in tags
    ):
        return "tags não é lista de listas de strings"
    if not isinstance(event["content"], str):
        return "content não é string"
    return None


def event_problem(event: Any) -> str | None:
    """Motivo para descartar o evento, ou None se ele é válido (RF-51).

    Confere a estrutura, recalcula o `id` e verifica a assinatura Schnorr
    (BIP-340) do `id` pela `pubkey`. Nunca lança.
    """
    problem = _structure_problem(event)
    if problem:
        return problem
    if compute_event_id(event) != event["id"]:
        return "id não confere com o conteúdo"
    if not schnorr.verify(
        bytes.fromhex(event["id"]), bytes.fromhex(event["pubkey"]), bytes.fromhex(event["sig"])
    ):
        return "assinatura inválida"
    return None


def is_valid_event(event: Any) -> bool:
    return event_problem(event) is None
