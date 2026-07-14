from functools import lru_cache
import re
from typing import Annotated

from pydantic import BeforeValidator, Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url


def _split_comma_separated(value):
    if isinstance(value, str):
        return [item.strip() for item in value.split(",") if item.strip()]
    return value


CommaSeparatedList = Annotated[list[str], BeforeValidator(_split_comma_separated)]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="PETTACHAINER_",
        env_file=".env",
        enable_decoding=False,
        extra="ignore",
    )

    environment: str = "production"
    database_url: str | None = None
    database_driver: str = "postgresql+psycopg"
    database_host: str = "localhost"
    database_port: int = Field(default=5432, ge=1, le=65535)
    database_name: str = "pettachainer"
    database_user: str = "pettachainer"
    database_password: str = "pettachainer"
    api_keys: CommaSeparatedList = Field(default_factory=list)
    allowed_hosts: CommaSeparatedList = Field(default_factory=lambda: ["localhost", "127.0.0.1"])

    worker_timeout_seconds: float = Field(default=15.0, ge=1.0, le=300.0)
    worker_memory_mb: int = Field(default=1024, ge=256, le=16384)
    worker_max_files: int = Field(default=64, ge=16, le=1024)
    max_concurrent_workers: int = Field(default=2, ge=1, le=64)
    max_statements_per_kb: int = Field(default=10_000, ge=1, le=1_000_000)
    max_statement_chars: int = Field(default=32_768, ge=128, le=1_000_000)
    max_query_chars: int = Field(default=16_384, ge=128, le=1_000_000)
    max_request_bytes: int = Field(default=2_097_152, ge=1024)
    max_kb_source_bytes: int = Field(default=16_777_216, ge=1024)
    max_results: int = Field(default=1000, ge=1, le=100_000)
    max_steps: int = Field(default=10_000, ge=1, le=1_000_000)
    max_derivations: int = Field(default=20_000, ge=100, le=1_000_000)

    @property
    def sqlalchemy_url(self) -> URL:
        if self.database_url:
            return make_url(self.database_url)
        return URL.create(
            drivername=self.database_driver,
            username=self.database_user,
            password=self.database_password,
            host=self.database_host,
            port=self.database_port,
            database=self.database_name,
        )

    def validate_for_server(self) -> None:
        if self.environment != "test":
            if not self.api_keys:
                raise ValueError("PETTACHAINER_API_KEYS must contain at least one API key")
            for entry in self.api_keys:
                owner, separator, secret = entry.partition(":")
                if not separator or not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", owner):
                    raise ValueError("API keys must use the format owner-id:secret")
                if len(secret) < 32:
                    raise ValueError("every API key secret must contain at least 32 characters")


@lru_cache
def get_settings() -> Settings:
    return Settings()
