"""RNF-02 — vetores da skill `validar-evento-nostr` (válido e adulterados).

Roda o script de referência da skill contra os vetores versionados em
`.agents/skills/validar-evento-nostr/examples/vetores/`:

- `valido.json`: evento assinado do mini-NIP (cópia de docs/nips/examples);
- `adulterado-conteudo.json`: carga de uma série trocada e id antigo;
- `adulterado-assinatura.json`: mesma troca, com id recalculado e sig antiga.

A verificação Schnorr do script depende de `coincurve` (opcional). Sem ela,
o vetor de assinatura adulterada é pulado aqui. A verificação criptográfica
desses mesmos vetores roda sempre no app (test/core/nostr/
skill_vectors_test.dart).

Fora do CI (ex.: container da API, que só monta `api/`), a pasta da skill não
existe e o módulo inteiro é pulado.
"""

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pytest

REPO = Path(__file__).resolve().parents[2]
SKILL_EXAMPLES = REPO / ".agents" / "skills" / "validar-evento-nostr" / "examples"
VECTORS = SKILL_EXAMPLES / "vetores"

if not VECTORS.is_dir():
    pytest.skip("pasta da skill fora do alcance (sem o repo inteiro)", allow_module_level=True)


def _load_validator() -> ModuleType:
    script = SKILL_EXAMPLES / "validar_evento.py"
    spec = importlib.util.spec_from_file_location("validar_evento", script)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = _load_validator()


def _has_coincurve() -> bool:
    return importlib.util.find_spec("coincurve") is not None


def _vector(name: str) -> dict:
    return json.loads((VECTORS / name).read_text(encoding="utf-8"))


def test_vetor_valido_passa() -> None:
    assert validator.main(str(VECTORS / "valido.json")) == 0


def test_vetor_valido_e_o_exemplo_do_mini_nip() -> None:
    example = REPO / "docs" / "nips" / "examples" / "workout-record.json"
    assert _vector("valido.json") == json.loads(example.read_text(encoding="utf-8"))


def test_conteudo_adulterado_e_reprovado_pelo_id() -> None:
    event = _vector("adulterado-conteudo.json")
    assert validator.compute_id(event) != event["id"]
    assert validator.main(str(VECTORS / "adulterado-conteudo.json")) == 1


def test_assinatura_adulterada_tem_id_coerente() -> None:
    """O id confere; só a assinatura denuncia a adulteração."""
    event = _vector("adulterado-assinatura.json")
    assert validator.compute_id(event) == event["id"]
    assert event["sig"] == _vector("valido.json")["sig"]


@pytest.mark.skipif(not _has_coincurve(), reason="coincurve não instalada")
def test_assinatura_adulterada_e_reprovada() -> None:
    assert validator.main(str(VECTORS / "adulterado-assinatura.json")) == 1
