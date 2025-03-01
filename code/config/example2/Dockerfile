FROM python:3.13-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ADD . /app
WORKDIR /app

RUN ["uv", "sync", "--frozen"]

CMD ["uv", "run", "main.py"]
