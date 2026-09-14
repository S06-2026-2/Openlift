"""Autenticação: hash de senha (passlib) e emissão/validação de JWT (PyJWT).

Importante: este módulo NUNCA lida com chaves NOSTR (nsec) — apenas com a
sessão tradicional (e-mail/senha) do OpenLift. A chave NOSTR é gerada e
assinada no dispositivo do usuário (ver app/features/auth no Flutter).
"""

# TODO(Sprint 2): hash_password(password) / verify_password(password, hash)
# TODO(Sprint 2): create_access_token(user_id) / create_refresh_token(user_id)
# TODO(Sprint 2): decode_token(token) -> payload | raises InvalidTokenError
