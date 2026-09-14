"""Endpoints de autenticação e registro da identidade NOSTR.

POST /auth/register        — cria usuário (e-mail + senha)
POST /auth/login           — autentica e retorna access/refresh token
POST /auth/refresh         — renova o access token
POST /me/nostr-identity    — registra o npub gerado localmente pelo app
"""

# TODO(Sprint 2): register(payload: schemas.auth.RegisterRequest) -> schemas.user.UserOut
# TODO(Sprint 2): login(payload: schemas.auth.LoginRequest) -> schemas.auth.TokenPair
# TODO(Sprint 4): refresh(payload: schemas.auth.RefreshRequest) -> schemas.auth.TokenPair
# TODO(Sprint 2): register_nostr_identity(payload: schemas.auth.NostrIdentityIn, user=Depends(get_current_user))
