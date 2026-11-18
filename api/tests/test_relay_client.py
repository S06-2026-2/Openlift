"""BE-08 — cliente de relay com verificação de assinatura (RF-50, RF-51, RNF-02).

Sem rede: o relay é simulado (tests/nostr_helpers.FakeRelay). Os eventos dos
testes são assinados com chaves descartáveis geradas na hora; os exemplos do
mini-NIP (docs/nips/examples), assinados por uma implementação independente,
conferem a verificação quando o repositório inteiro está disponível (CI).
"""

import asyncio
import json
import logging
from pathlib import Path

import pytest
from nostr_helpers import (
    FakeRelay,
    MultiRelay,
    make_event,
    make_reaction,
    pubkey_of,
    secret_for,
    sign,
    tampered,
)

from app.core import schnorr
from app.core.config import Settings
from app.core.nostr import compute_event_id, event_problem, is_valid_event
from app.infra.nostr.relay_client import RelayClient

EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "nips" / "examples"
RELAY = "wss://relay.teste"


async def _no_sleep(_: float) -> None:
    return None


def _client(relay: FakeRelay | MultiRelay, urls: list[str] | None = None, **kwargs) -> RelayClient:
    return RelayClient(
        urls or [RELAY], connect=relay.connect, sleep=_no_sleep, timeout=1.0, **kwargs
    )


def _workout() -> dict:
    return make_event("autor", kind=1301, tags=[["d", "x"], ["alt", "Registro de treino"]])


# ---------------------------------------------------------------------------
# Verificação (NIP-01 + BIP-340)
# ---------------------------------------------------------------------------


@pytest.mark.skipif(not EXAMPLES.is_dir(), reason="docs/ fora do alcance (container só com api/)")
def test_exemplos_do_mini_nip_assinados_por_terceiro_sao_validos() -> None:
    workout = json.loads((EXAMPLES / "workout-record.json").read_text(encoding="utf-8"))
    templates = json.loads((EXAMPLES / "exercise-templates.json").read_text(encoding="utf-8"))
    assert event_problem(workout) is None
    assert all(is_valid_event(t) for t in templates)


def test_assinatura_gerada_no_teste_verifica() -> None:
    secret = secret_for("vetor")
    message = bytes(range(32))
    signature = sign(message, secret)
    assert schnorr.verify(message, bytes.fromhex(pubkey_of(secret)), signature)
    assert not schnorr.verify(bytes(32), bytes.fromhex(pubkey_of(secret)), signature)


@pytest.mark.parametrize(
    "message,pubkey,signature",
    [
        (b"curto", bytes(32), bytes(64)),
        (bytes(32), b"curto", bytes(64)),
        (bytes(32), bytes(32), b"curto"),
        (bytes(32), b"\xff" * 32, bytes(64)),  # x fora do corpo
        (bytes(32), bytes.fromhex("5" * 64), b"\xff" * 64),  # r e s fora do intervalo
    ],
)
def test_entrada_invalida_nao_lanca(message: bytes, pubkey: bytes, signature: bytes) -> None:
    assert schnorr.verify(message, pubkey, signature) is False


def test_evento_valido_passa() -> None:
    event = _workout()
    assert compute_event_id(event) == event["id"]
    assert event_problem(event) is None


def test_sig_adulterada_e_descartada() -> None:
    event = _workout()
    other = make_event("outro", kind=1301)
    assert event_problem(tampered(event, sig=other["sig"])) == "assinatura inválida"


def test_id_que_nao_bate_e_descartado() -> None:
    event = _workout()
    assert event_problem(tampered(event, content="adulterado")) == "id não confere com o conteúdo"


def test_id_recalculado_com_sig_antiga_e_descartado() -> None:
    changed = tampered(_workout(), content="adulterado")
    changed["id"] = compute_event_id(changed)
    assert event_problem(changed) == "assinatura inválida"


@pytest.mark.parametrize(
    "change",
    [
        {"id": "XYZ"},
        {"pubkey": "npub1naoehhex"},
        {"sig": "00"},
        {"created_at": 1.5},
        {"created_at": True},
        {"kind": "1301"},
        {"tags": [["e", 1]]},
        {"tags": "e"},
        {"content": None},
        {"extra": "campo"},
    ],
)
def test_estrutura_invalida_e_descartada(change: dict) -> None:
    assert event_problem(tampered(_workout(), **change)) is not None


def test_evento_que_nao_e_objeto_e_descartado() -> None:
    assert event_problem(["EVENT"]) is not None
    assert event_problem(None) is not None


# ---------------------------------------------------------------------------
# Cliente
# ---------------------------------------------------------------------------


def test_fetch_devolve_so_eventos_que_casam_com_o_filtro() -> None:
    workout = _workout()
    like = make_reaction("fã", workout)
    relay = FakeRelay([workout, like])
    events = asyncio.run(_client(relay).fetch([{"kinds": [7], "#e": [workout["id"]]}]))
    assert events == [like]
    assert relay.requests[0][0] == "REQ" and relay.requests[0][2] == {
        "kinds": [7],
        "#e": [workout["id"]],
    }


def test_todo_evento_e_verificado_antes_de_sair(caplog: pytest.LogCaptureFixture) -> None:
    """RNF-02: nada inválido passa; o descarte é logado com o event_id (RNF-14)."""
    valid = make_reaction("fã", _workout())
    bad_sig = tampered(make_reaction("outro fã", _workout()), sig=valid["sig"])
    bad_id = tampered(make_reaction("mais um", _workout()), content="-")
    relay = FakeRelay([valid, bad_sig, bad_id])

    with caplog.at_level(logging.WARNING, logger="openlift.nostr"):
        events = asyncio.run(_client(relay).fetch([{"kinds": [7]}]))

    assert events == [valid]
    discarded = [r for r in caplog.records if r.message.startswith("Evento NOSTR descartado")]
    assert {r.event_id for r in discarded} == {bad_sig["id"], bad_id["id"]}  # type: ignore[attr-defined]
    assert {r.reason for r in discarded} == {  # type: ignore[attr-defined]
        "assinatura inválida",
        "id não confere com o conteúdo",
    }


def test_mesmo_evento_em_dois_relays_aparece_uma_vez() -> None:
    like = make_reaction("fã", _workout())
    relays = MultiRelay({"wss://a": FakeRelay([like]), "wss://b": FakeRelay([like])})
    events = asyncio.run(_client(relays, ["wss://a", "wss://b"]).fetch([{"kinds": [7]}]))
    assert events == [like]


def test_evento_valido_nao_e_trocado_por_copia_adulterada_de_outro_relay() -> None:
    like = make_reaction("fã", _workout())
    forged = tampered(like, sig=make_event("x", kind=7)["sig"])
    relays = MultiRelay({"wss://a": FakeRelay([forged]), "wss://b": FakeRelay([like])})
    events = asyncio.run(_client(relays, ["wss://a", "wss://b"]).fetch([{"kinds": [7]}]))
    assert events == [like]


def test_ordena_do_mais_antigo_para_o_mais_novo() -> None:
    workout = _workout()
    late = make_reaction("a", workout, created_at=2_000)
    early = make_reaction("b", workout, created_at=1_000)
    events = asyncio.run(_client(FakeRelay([late, early])).fetch([{"kinds": [7]}]))
    assert events == [early, late]


def test_relay_recusando_conexao_reconecta_com_backoff() -> None:
    like = make_reaction("fã", _workout())
    relay = FakeRelay([like], fail_connects=2)
    delays: list[float] = []

    async def record(delay: float) -> None:
        delays.append(delay)

    client = RelayClient([RELAY], connect=relay.connect, sleep=record, backoff_base=0.5)
    assert asyncio.run(client.fetch([{"kinds": [7]}])) == [like]
    assert relay.connections == 3
    assert delays == [0.5, 1.0]


def test_relay_caindo_no_meio_da_leitura_reconecta_e_completa() -> None:
    """RF-50: a conexão cai depois do 1º evento; a nova tentativa traz tudo."""
    workout = _workout()
    likes = [make_reaction(f"fã {i}", workout, created_at=1_000 + i) for i in range(3)]
    relay = FakeRelay(likes, drop_after=1)
    assert asyncio.run(_client(relay).fetch([{"kinds": [7]}])) == likes
    assert relay.connections == 2


def test_relay_fora_do_ar_nao_derruba_os_outros(caplog: pytest.LogCaptureFixture) -> None:
    like = make_reaction("fã", _workout())
    relays = MultiRelay({"wss://fora": FakeRelay(fail_connects=99), "wss://ok": FakeRelay([like])})
    with caplog.at_level(logging.ERROR, logger="openlift.nostr"):
        events = asyncio.run(
            _client(relays, ["wss://fora", "wss://ok"], max_retries=2).fetch([{"kinds": [7]}])
        )
    assert events == [like]
    assert relays.relays["wss://fora"].connections == 3
    assert any(r.relay == "wss://fora" for r in caplog.records)  # type: ignore[attr-defined]


def test_sem_relays_ou_sem_filtros_nao_conecta() -> None:
    relay = FakeRelay([make_reaction("fã", _workout())])
    assert asyncio.run(RelayClient([], connect=relay.connect).fetch([{"kinds": [7]}])) == []
    assert asyncio.run(_client(relay).fetch([])) == []
    assert relay.connections == 0


def test_mensagens_estranhas_do_relay_sao_ignoradas() -> None:
    """Não JSON, JSON fora do protocolo, NOTICE e EVENT de outra assinatura."""
    like = make_reaction("fã", _workout())
    relay = FakeRelay([like])

    def connect(url: str):  # type: ignore[no-untyped-def]
        socket = relay.connect(url)
        recv = socket.recv
        noise = ["não é json", json.dumps({"objeto": 1}), json.dumps([]), json.dumps([1])]
        noise += [json.dumps(["NOTICE", "aviso"]), json.dumps(["EVENT", "outra", like])]

        async def noisy_recv() -> str:
            return noise.pop(0) if noise else await recv()

        socket.recv = noisy_recv  # type: ignore[method-assign]
        return socket

    client = RelayClient([RELAY], connect=connect, sleep=_no_sleep, timeout=1.0)
    assert asyncio.run(client.fetch([{"kinds": [7]}])) == [like]


def test_relay_que_encerra_a_assinatura_devolve_o_que_chegou() -> None:
    like = make_reaction("fã", _workout())

    class Closing(FakeRelay):
        def connect(self, url: str):  # type: ignore[no-untyped-def]
            socket = super().connect(url)
            original = socket.send

            async def send(data: str) -> None:
                await original(data)
                if socket.outbox and socket.outbox[-1][0] == "EOSE":
                    sub = socket.outbox[-1][1]
                    socket.outbox[-1] = ["CLOSED", sub, "rate-limited: devagar"]

            socket.send = send  # type: ignore[method-assign]
            return socket

    relay = Closing([like])
    assert asyncio.run(_client(relay).fetch([{"kinds": [7]}])) == [like]
    assert relay.connections == 1


def test_from_settings_le_relays_da_configuracao(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = Settings(
        database_url="sqlite:///:memory:",
        nostr_relays=" wss://a , ,wss://b,wss://a",
        nostr_relay_timeout_seconds=3,
        nostr_relay_max_retries=1,
    )
    monkeypatch.setattr("app.infra.nostr.relay_client.get_settings", lambda: settings)
    client = RelayClient.from_settings()
    assert client.relay_urls == ["wss://a", "wss://b"]
    assert client.timeout == 3
    assert client.max_retries == 1


def test_sem_nostr_relays_a_lista_e_vazia() -> None:
    assert Settings(database_url="sqlite:///:memory:", nostr_relays=None).nostr_relay_urls == []
