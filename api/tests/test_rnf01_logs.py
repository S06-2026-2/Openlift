"""RNF-01 — a chave privada NOSTR nunca aparece em log do backend.

Roda o fluxo completo de identidade (cadastro → login → tentativa de enviar
chave privada → registro do npub → GET /me) com todos os loggers em DEBUG,
inclusive o do SQLAlchemy, que registra os parâmetros de cada query. Depois
procura nos logs:

- `nsec1` (chave privada em bech32, NIP-19);
- qualquer hex de 64 caracteres que não seja um valor sabidamente público
  (a pubkey do npub registrado).

A chave privada de teste é derivada em tempo de execução, então nenhum
segredo (nem com cara de segredo) fica versionado (ADR-0006, gitleaks).
"""

import hashlib
import logging
import re

import pytest
from fastapi.testclient import TestClient

from app.core.nostr import _CHARSET, _convert_bits, _hrp_expand, _polymod

# Vetor público da NIP-19 (o mesmo de test_nostr_identity.py).
NPUB = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"
PUBKEY_HEX = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"

# Hex de 64 caracteres que PODE aparecer em log: só dado público.
PUBLIC_HEX = {PUBKEY_HEX}

NSEC_PATTERN = re.compile(r"nsec1[02-9ac-hj-np-z]+")
HEX64_PATTERN = re.compile(r"(?<![0-9a-fA-F])[0-9a-fA-F]{64}(?![0-9a-fA-F])")

EMAIL = "rnf01@openlift.dev"
PASSWORD = "senha-forte-123"  # gitleaks:allow (senha de teste, usuário descartável)


def _secret_hex() -> str:
    """Chave privada descartável, gerada na hora (nunca versionada)."""
    return hashlib.sha256(b"openlift-rnf01-chave-descartavel").hexdigest()


def _to_nsec(secret_hex: str) -> str:
    """Codifica em bech32 com hrp `nsec`. Só existe no teste: o backend não
    tem, de propósito, nada que produza nsec (app/core/nostr.py)."""
    data = _convert_bits(list(bytes.fromhex(secret_hex)), 8, 5, pad=True)
    polymod = _polymod(_hrp_expand("nsec") + data + [0] * 6) ^ 1
    checksum = [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
    return "nsec1" + "".join(_CHARSET[d] for d in data + checksum)


def find_leaks(text: str) -> list[str]:
    """Trechos do texto que parecem chave privada (RNF-01)."""
    leaks = NSEC_PATTERN.findall(text)
    leaks += [m for m in HEX64_PATTERN.findall(text) if m.lower() not in PUBLIC_HEX]
    return leaks


# ---------------------------------------------------------------------------
# O detector funciona (senão o teste principal passaria sem provar nada)
# ---------------------------------------------------------------------------


def test_detector_acha_nsec_e_hex_de_64() -> None:
    secret = _secret_hex()
    assert find_leaks(f"payload={{'nsec': '{_to_nsec(secret)}'}}") == [_to_nsec(secret)]
    assert find_leaks(f"chave {secret} vazou") == [secret]
    assert find_leaks(f"chave {secret.upper()} vazou") == [secret.upper()]


def test_detector_ignora_dado_publico() -> None:
    assert find_leaks(f"pubkey_hex={PUBKEY_HEX} npub={NPUB}") == []
    # Hex mais longo que 64 (ex.: assinatura de 128) não é confundido com chave.
    assert find_leaks("sig=" + "ab" * 64) == []


def test_nsec_gerado_tem_formato_nip19() -> None:
    nsec = _to_nsec(_secret_hex())
    assert len(nsec) == 63
    assert NSEC_PATTERN.fullmatch(nsec)


def test_detector_pega_log_real_capturado(caplog: pytest.LogCaptureFixture) -> None:
    """Garante que o caplog enxerga os loggers da API."""
    caplog.set_level(logging.DEBUG)
    logging.getLogger("openlift.api").warning("vazou %s", _secret_hex())
    assert find_leaks(caplog.text) == [_secret_hex()]


# ---------------------------------------------------------------------------
# Fluxo completo
# ---------------------------------------------------------------------------


def test_fluxo_de_identidade_nao_vaza_chave_privada_nos_logs(
    client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    caplog.set_level(logging.DEBUG)
    caplog.set_level(logging.DEBUG, logger="sqlalchemy.engine")
    secret_hex = _secret_hex()
    nsec = _to_nsec(secret_hex)

    response = client.post("/api/v1/auth/register", json={"email": EMAIL, "password": PASSWORD})
    assert response.status_code == 201

    response = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD})
    assert response.status_code == 200
    headers = {"Authorization": f"Bearer {response.json()['access_token']}"}

    url = "/api/v1/me/nostr-identity"
    # Cliente com bug tentando mandar a chave privada, em bech32 e em hex.
    for field, value in [("nsec", nsec), ("private_key", secret_hex), ("npub", nsec)]:
        body = {"npub": NPUB, field: value} if field != "npub" else {"npub": value}
        response = client.post(url, json=body, headers=headers)
        assert response.status_code == 422, field
        assert value not in response.text

    response = client.post(url, json={"npub": NPUB}, headers=headers)
    assert response.status_code == 200
    assert response.json()["npub"] == NPUB

    response = client.get("/api/v1/me", headers=headers)
    assert response.status_code == 200

    # O SQLAlchemy registrou as queries: prova de que houve log para varrer.
    assert any(r.name.startswith("sqlalchemy.engine") for r in caplog.records)
    assert find_leaks(caplog.text) == []
    assert nsec not in caplog.text
    assert secret_hex not in caplog.text
