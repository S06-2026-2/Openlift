"""Regras do perfil da rede social (ADR-0012): nome de usuário único,
busca por nome e o diretório NIP-05.

O perfil só existe para quem já registrou a identidade NOSTR (o `npub`): o
nome verificado aponta para essa chave pública. A chave privada nunca passa
por aqui (ADR-0006).
"""

from urllib.parse import urlparse

from sqlalchemy import Select, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import ApiError
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.profile import Profile
from app.domain.models.user import User
from app.domain.schemas.profile import USERNAME_PATTERN, ProfileIn, ProfileOut

MAX_SEARCH_RESULTS = 20


def nip05_domain() -> str:
    """Domínio do NIP-05: o host público da API (PUBLIC_BASE_URL)."""
    return urlparse(get_settings().public_base_url).netloc


def _to_out(profile: Profile, identity: NostrIdentity) -> ProfileOut:
    return ProfileOut(
        username=profile.username,
        display_name=profile.display_name,
        bio=profile.bio,
        avatar_url=profile.avatar_url,
        npub=identity.npub,
        pubkey=identity.pubkey_hex,
        nip05=f"{profile.username}@{nip05_domain()}",
    )


def _with_identity() -> Select[tuple[Profile, NostrIdentity]]:
    return select(Profile, NostrIdentity).join(
        NostrIdentity, NostrIdentity.user_id == Profile.user_id
    )


def _not_found() -> ApiError:
    return ApiError(404, "Perfil não encontrado.", "profile_not_found")


def _username_taken() -> ApiError:
    return ApiError(409, "Esse nome de usuário já está em uso.", "username_taken")


def get_own(db: Session, user: User) -> ProfileOut:
    row = db.execute(_with_identity().where(Profile.user_id == user.id)).first()
    if row is None:
        raise _not_found()
    return _to_out(*row)


def save_own(db: Session, user: User, payload: ProfileIn) -> ProfileOut:
    """Cria o perfil ou atualiza o existente (inclusive trocar de nome)."""
    identity = db.scalar(select(NostrIdentity).where(NostrIdentity.user_id == user.id))
    if identity is None:
        raise ApiError(
            409,
            "Sua identidade na rede ainda não foi registrada. Saia e entre de novo.",
            "nostr_identity_required",
        )
    owner = db.scalar(select(Profile.user_id).where(Profile.username == payload.username))
    if owner is not None and owner != user.id:
        raise _username_taken()

    profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
    if profile is None:
        profile = Profile(user_id=user.id, username=payload.username)
        db.add(profile)
    profile.username = payload.username
    profile.display_name = payload.display_name
    profile.bio = payload.bio
    profile.avatar_url = payload.avatar_url
    try:
        db.commit()
    except IntegrityError as exc:  # corrida: o mesmo nome escolhido ao mesmo tempo
        db.rollback()
        raise _username_taken() from exc
    db.refresh(profile)
    return _to_out(profile, identity)


def is_available(db: Session, user: User, username: str) -> bool:
    owner = db.scalar(select(Profile.user_id).where(Profile.username == username))
    return owner is None or owner == user.id


def search(db: Session, query: str, limit: int = MAX_SEARCH_RESULTS) -> list[ProfileOut]:
    """Nome de usuário que começa com `query`, ou nome de exibição que contém."""
    term = query.strip().lstrip("@").lower()
    if not term:
        return []
    rows = db.execute(
        _with_identity()
        .where(
            or_(
                Profile.username.startswith(term, autoescape=True),
                func.lower(Profile.display_name).contains(term, autoescape=True),
            )
        )
        .order_by(Profile.username)
        .limit(limit)
    ).all()
    return [_to_out(*row) for row in rows]


def by_pubkeys(db: Session, pubkeys: list[str]) -> list[ProfileOut]:
    if not pubkeys:
        return []
    rows = db.execute(_with_identity().where(NostrIdentity.pubkey_hex.in_(pubkeys))).all()
    return [_to_out(*row) for row in rows]


def by_username(db: Session, username: str) -> ProfileOut:
    name = username.strip().lstrip("@").lower()
    row = db.execute(_with_identity().where(Profile.username == name)).first()
    if row is None:
        raise _not_found()
    return _to_out(*row)


def nip05_names(db: Session, name: str | None) -> dict[str, str]:
    """`names` do /.well-known/nostr.json. Sem `name`, nada (não lista todos)."""
    if name is None:
        return {}
    username = name.strip().lower()
    if not USERNAME_PATTERN.match(username):
        return {}
    pubkey = db.scalar(
        select(NostrIdentity.pubkey_hex)
        .join(Profile, Profile.user_id == NostrIdentity.user_id)
        .where(Profile.username == username)
    )
    return {} if pubkey is None else {username: pubkey}
