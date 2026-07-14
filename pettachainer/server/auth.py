import secrets
from dataclasses import dataclass

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings, get_settings


bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Principal:
    owner_id: str


def authenticate(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    settings: Settings = Depends(get_settings),
) -> Principal:
    if settings.environment == "test" and not settings.api_keys:
        return Principal(owner_id="test-owner")
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing bearer token")
    for configured_entry in settings.api_keys:
        owner_id, _separator, configured_key = configured_entry.partition(":")
        if secrets.compare_digest(credentials.credentials, configured_key):
            return Principal(owner_id=owner_id)
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid bearer token")
