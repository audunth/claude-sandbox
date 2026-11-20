FROM docker.io/library/debian:trixie-slim

ARG HOST_UID=1000
ARG HOST_GID=1000

# perl, curl and xz-utils are needed by the TinyTeX installer
RUN apt-get update && \
    apt-get install -y --no-install-recommends bash ca-certificates curl git perl python3 python3-venv xz-utils && \
    rm -rf /var/lib/apt/lists/*

# Create group and user matching host UID/GID
RUN groupadd --gid ${HOST_GID} appuser && \
    useradd --uid ${HOST_UID} --gid ${HOST_GID} --create-home --shell /bin/bash appuser

RUN mkdir -p /home/appuser/.claude && chown appuser:appuser /home/appuser/.claude

USER appuser

# Claude Code, uv and TinyTeX's links all go in ~/.local/bin, which is not on
# the default PATH. Set it here so the RUN steps below find tlmgr too. The
# folder must exist before TinyTeX is installed, or TinyTeX links into ~/bin.
ENV PATH="/home/appuser/.local/bin:$PATH"
RUN mkdir -p /home/appuser/.local/bin

# The piped installs run in bash with pipefail, so a failed download fails the
# build. A SHELL instruction would do this for every step, but podman builds
# OCI images, which cannot store SHELL, so buildah warns at every step after it.
# TinyTeX before Claude, so Claude updates reuse the TinyTeX layer
RUN bash -o pipefail -c 'curl -fsSL https://tinytex.yihui.org/install-bin-unix.sh | sh'
RUN tlmgr install revtex pgf textcase

# The container is removed on exit, so Claude Code's own updates would be lost
# and downloaded again every session. Upgrade by rebuilding instead: the script
# passes a new UPGRADE_STAMP on --build, so podman reruns the steps below rather
# than reuse their cached layers.
ENV DISABLE_AUTOUPDATER=1
ARG UPGRADE_STAMP
RUN bash -o pipefail -c 'curl -fsSL https://claude.ai/install.sh | bash'
RUN bash -o pipefail -c 'curl -fsSL https://astral.sh/uv/install.sh | sh'

WORKDIR /app

CMD ["/bin/bash"]
