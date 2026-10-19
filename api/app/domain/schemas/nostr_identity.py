"""Schemas Pydantic v2 da identidade NOSTR (S2-02, RF-03).

O corpo aceita SOMENTE a chave pública (`extra="forbid"`): qualquer outro
campo — `nsec`, `private_key`... — é 422 (RNF-01, ADR-0006).
"""

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.nostr import npub_to_hex

# Vetor público da NIP-19.
_EXAMPLE_NPUB = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"


class NostrIdentityIn(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={"examples": [{"npub": _EXAMPLE_NPUB}]},
    )

    npub: str = Field(description="Chave pública NOSTR no formato NIP-19 (`npub1...`)")

    @field_validator("npub")
    @classmethod
    def _valid_npub(cls, value: str) -> str:
        npub_to_hex(value)  # ValueError vira 422 no campo `npub`
        return value
