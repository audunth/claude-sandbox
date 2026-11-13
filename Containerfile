FROM docker.io/library/debian:trixie-slim

ARG HOST_UID=1000
ARG HOST_GID=1000

# perl, curl and xz-utils are needed by the TinyTeX installer
RUN apt-get update && \
    apt-get install -y --no-install-recommends bash ca-certificates curl git perl python3 python3-venv xz-utils && \
    rm -rf /var/lib/apt/lists/*

# uv, for projects with pyproject.toml, requirements.txt or uv.lock
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Create group and user matching host UID/GID
RUN groupadd --gid ${HOST_GID} appuser && \
    useradd --uid ${HOST_UID} --gid ${HOST_GID} --create-home --shell /bin/bash appuser

RUN mkdir -p /home/appuser/.claude && chown appuser:appuser /home/appuser/.claude

USER appuser
RUN tlmgr install revtex pgf textcase
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN curl -fsSL https://tinytex.yihui.org/install-bin-unix.sh | sh
RUN curl -fsSL https://astral.sh/uv/install.sh | sh

WORKDIR /app

# Claude Code installs to ~/.local/bin, which is not on the default PATH
ENV PATH="/home/appuser/.local/bin:$PATH"
CMD ["/bin/bash"]
