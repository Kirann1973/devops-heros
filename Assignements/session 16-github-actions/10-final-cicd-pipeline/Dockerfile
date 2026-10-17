# Session 16 calculator image - Kiran N | Roll No: 10446
FROM python:3.12-slim

LABEL org.opencontainers.image.title="session16-calculator" \
      org.opencontainers.image.description="Session 16 CI/CD demo - Kiran N, Roll No 10446" \
      org.opencontainers.image.source="https://github.com/Kirann1973/devops-heros"

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PORT=8000 \
    PYTHONUNBUFFERED=1

WORKDIR /srv
COPY app/ app/

# run as a normal user, not root
USER nobody
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"

CMD ["python", "-m", "app.web"]
