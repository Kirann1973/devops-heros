# Session 17 DevSecOps image - Kiran N | Roll No: 10446
FROM python:3.12-slim

LABEL org.opencontainers.image.title="session17-devsecops" \
      org.opencontainers.image.description="Session 17 DevSecOps pipeline - Kiran N, Roll No 10446" \
      org.opencontainers.image.source="https://github.com/Kirann1973/devops-heros"

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /srv

# patch OS packages, then install the pinned Python dependencies
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app/ app/

# run as a fixed non-root user (Kubernetes runAsNonRoot checks the numeric id)
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
USER 10001

EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--worker-tmp-dir", "/dev/shm", "--access-logfile", "-", "app.app:app"]
