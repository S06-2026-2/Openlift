"""Schema do corpo de erro padrão (documentação no OpenAPI)."""

from pydantic import BaseModel, ConfigDict


class ErrorOut(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {"detail": "Este e-mail já está cadastrado.", "code": "email_already_registered"}
            ]
        }
    )

    detail: str
    code: str
