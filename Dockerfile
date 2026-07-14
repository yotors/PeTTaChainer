FROM swipl:10.1.11 AS builder

RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential python3-dev python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV VIRTUAL_ENV="/opt/venv" \
    PATH="/opt/venv/bin:$PATH" \
    UV_LINK_MODE=copy

WORKDIR /app
COPY PeTTa /app/PeTTa
COPY PeTTaChainer /app/PeTTaChainer
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    python -m pip install --upgrade pip uv \
    && uv sync --project /app/PeTTaChainer --python /opt/venv/bin/python --frozen --no-dev --active


FROM swipl:10.1.11

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin pettachainer
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app

USER 10001:10001
WORKDIR /app/PeTTaChainer
EXPOSE 8000

CMD ["sh", "-c", "alembic upgrade head && exec uvicorn pettachainer.server.app:app --host 0.0.0.0 --port 8000 --no-proxy-headers"]
