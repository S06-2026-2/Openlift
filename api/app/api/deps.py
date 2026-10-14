"""Dependências compartilhadas dos endpoints (FastAPI `Depends`).

- get_db: sessão do banco por requisição;
- get_current_user: `Authorization: Bearer <access token>` → User (401 se
  ausente, expirado, adulterado, de tipo errado ou de usuário inexistente).

No Swagger (/docs), o botão "Authorize" aceita o access token do login.

TODO(Sprint 4): get_current_user_optional (endpoints públicos com contexto opcional)
"""

from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import ExpiredSignatureError, InvalidTokenError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import decode_token
from app.domain.models.user import User
from app.services.auth_service import get_user_by_subject

__all__ = ["CurrentUser", "DbSession", "get_current_user", "get_db"]

_bearer = HTTPBearer(auto_error=False, description="Access token obtido em /auth/login")
_WWW_AUTHENTICATE = {"WWW-Authenticate": "Bearer"}


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise ApiError(401, "Autenticação necessária.", "not_authenticated", _WWW_AUTHENTICATE)
    try:
        payload = decode_token(credentials.credentials, expected_type="access")
    except ExpiredSignatureError as exc:
        raise ApiError(
            401, "Sua sessão expirou. Entre novamente.", "token_expired", _WWW_AUTHENTICATE
        ) from exc
    except InvalidTokenError as exc:
        raise ApiError(401, "Token inválido.", "invalid_token", _WWW_AUTHENTICATE) from exc

    user = get_user_by_subject(db, payload.get("sub"))
    if user is None:
        raise ApiError(401, "Token inválido.", "invalid_token", _WWW_AUTHENTICATE)
    return user


DbSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]
