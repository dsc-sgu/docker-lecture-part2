FROM python:3.13-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ADD . /app
WORKDIR /app

RUN ["uv", "sync", "--frozen"]

ENTRYPOINT ["uv", "run", "uvicorn", "main:app"]
CMD ["--host", "0.0.0.0", "--port", "8000"]
