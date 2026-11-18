"""Schemas Pydantic v2 de curtidas e ranking."""

from pydantic import BaseModel, ConfigDict, Field

# TODO(BE-15): class RankingEntryOut

_EXAMPLE_EVENT_ID = "2763ff3b0e19519634b11700b323eb26fe82d5a53f1fe5da307c9b76eb847e93"


class LikeCountOut(BaseModel):
    """Likes de um treino publicado, lidos do cache `likes` (BE-09)."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"event_id": _EXAMPLE_EVENT_ID, "count": 3, "liked_by_me": True}]
        }
    )

    event_id: str = Field(description="`id` do evento `kind 1301` (hex de 64 caracteres)")
    count: int = Field(ge=0, description="Pessoas diferentes que curtiram (RN-06)")
    liked_by_me: bool = Field(
        description="Se a identidade NOSTR do usuário logado curtiu. `false` sem identidade"
    )
