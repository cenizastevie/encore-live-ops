FROM hashicorp/terraform:1.9 AS terraform
FROM ghcr.io/terraform-linters/tflint:v0.53.0 AS tflint

FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=terraform /bin/terraform /usr/local/bin/terraform
COPY --from=tflint /usr/local/bin/tflint /usr/local/bin/tflint

RUN pip install --no-cache-dir pre-commit checkov ruff mypy pytest

# Non-root user; pre-commit's cache lives in a path we can mount a volume over.
RUN useradd --create-home hooks \
    && mkdir -p /home/hooks/.cache/pre-commit \
    && chown -R hooks:hooks /home/hooks
USER hooks
ENV PRE_COMMIT_HOME=/home/hooks/.cache/pre-commit

# The repo is bind-mounted from the host, owned by a different user.
RUN git config --global --add safe.directory '*' \
    && git config --global core.autocrlf true \
    && git config --global core.fileMode false

WORKDIR /repo
ENTRYPOINT ["pre-commit"]
