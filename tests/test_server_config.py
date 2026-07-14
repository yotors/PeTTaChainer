from pettachainer.server.config import Settings


def test_settings_accept_comma_separated_environment_values(monkeypatch):
    monkeypatch.setenv(
        "PETTACHAINER_API_KEYS",
        "owner-a:12345678901234567890123456789012,owner-b:abcdefghijklmnopqrstuvwxyz123456",
    )
    monkeypatch.setenv("PETTACHAINER_ALLOWED_HOSTS", "api.example.com,localhost")

    settings = Settings(_env_file=None)

    assert settings.api_keys[0].startswith("owner-a:")
    assert settings.allowed_hosts == ["api.example.com", "localhost"]


def test_database_url_builder_preserves_reserved_password_characters():
    password = "p@ss:word/with%reserved|characters"
    settings = Settings(
        _env_file=None,
        database_host="postgres",
        database_password=password,
    )

    assert settings.sqlalchemy_url.host == "postgres"
    assert settings.sqlalchemy_url.password == password
