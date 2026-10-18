"""Exemplo da skill validar-evento-nostr: confere a parte genérica de um evento.

Uso:
    python validar_evento.py evento.json

Confere estrutura (NIP-01), recalcula o id, verifica a assinatura Schnorr se a
biblioteca `coincurve` estiver instalada (`pip install coincurve`) e exige a
tag `alt` (NIP-31). A conformidade do kind 1301 com o mini-NIP (docs/nips/)
NÃO é checada aqui: depende das tags que o NOSTR-01 vai definir.
"""

import hashlib
import json
import re
import sys
from typing import Any

HEX64 = re.compile(r"^[0-9a-f]{64}$")
HEX128 = re.compile(r"^[0-9a-f]{128}$")
FIELDS = {"id", "pubkey", "created_at", "kind", "tags", "content", "sig"}
WORKOUT_KIND = 1301


def compute_id(event: dict[str, Any]) -> str:
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


def check_structure(event: dict[str, Any]) -> list[str]:
    problems = []
    if set(event) != FIELDS:
        problems.append(f"campos esperados {sorted(FIELDS)}, recebidos {sorted(event)}")
        return problems
    if not HEX64.match(str(event["id"])):
        problems.append("id não é hex de 64 caracteres minúsculos")
    if not HEX64.match(str(event["pubkey"])):
        problems.append("pubkey não é hex de 64 caracteres (use a chave x-only, não o npub)")
    if not HEX128.match(str(event["sig"])):
        problems.append("sig não é hex de 128 caracteres")
    if not isinstance(event["created_at"], int) or event["created_at"] > 10**11:
        problems.append("created_at precisa ser inteiro em segundos Unix (não milissegundos)")
    if not isinstance(event["kind"], int):
        problems.append("kind precisa ser inteiro")
    tags = event["tags"]
    if not isinstance(tags, list) or not all(
        isinstance(tag, list) and all(isinstance(v, str) for v in tag) for tag in tags
    ):
        problems.append("tags precisa ser lista de listas de strings")
    if not isinstance(event["content"], str):
        problems.append("content precisa ser string")
    return problems


def check_signature(event: dict[str, Any]) -> str:
    try:
        from coincurve import PublicKeyXOnly  # type: ignore[import-not-found]
    except ImportError:
        return "⚠️ não verificada (instale coincurve para verificar)"
    key = PublicKeyXOnly(bytes.fromhex(event["pubkey"]))
    valid = key.verify(bytes.fromhex(event["sig"]), bytes.fromhex(event["id"]))
    return "✅" if valid else "❌ assinatura inválida: descartar o evento"


def main(path: str) -> int:
    # utf-8-sig aceita arquivo salvo com BOM (comum no Windows/PowerShell).
    with open(path, encoding="utf-8-sig") as file:
        event = json.load(file)

    rows: list[tuple[str, str]] = []
    problems = check_structure(event)
    rows.append(("Estrutura NIP-01", "✅" if not problems else "❌ " + "; ".join(problems)))
    if problems:
        print_report(event, rows)
        return 1

    id_ok = compute_id(event) == event["id"]
    rows.append(("id confere", "✅" if id_ok else "❌ id diferente do recalculado"))
    rows.append(("Assinatura", check_signature(event) if id_ok else "❌ não verificada: id errado"))

    has_alt = any(
        tag and tag[0] == "alt" and len(tag) > 1 and tag[1].strip() for tag in event["tags"]
    )
    rows.append(("Tag alt (NIP-31)", "✅" if has_alt else "❌ falta a tag alt"))

    if event["kind"] == 1:
        rows.append(("kind", "❌ treino como kind 1 está descartado (ADR-003)"))
    elif event["kind"] == WORKOUT_KIND:
        rows.append(("kind 1301 + mini-NIP", "⚠️ conferir as tags contra docs/nips/"))

    print_report(event, rows)
    return 0 if all(not result.startswith("❌") for _, result in rows) else 1


def print_report(event: dict[str, Any], rows: list[tuple[str, str]]) -> None:
    print(f"## Validação do evento {str(event.get('id', '?'))[:8]}\n")
    print("| Verificação | Resultado |\n|---|---|")
    for check, result in rows:
        print(f"| {check} | {result} |")


if __name__ == "__main__":
    # O console do Windows não usa UTF-8 por padrão (quebra nos ✅/❌).
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
