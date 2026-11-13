FROM docker.io/library/alpine:latest

ARG HOST_UID=1000
ARG HOST_GID=1000

RUN apk add --no-cache bash curl libgcc libstdc++ ripgrep perl-file-find-rule xz python3 git

# Create group and user matching host UID/GID
RUN addgroup --gid ${HOST_GID} appuser && \
    adduser --uid ${HOST_UID} --ingroup appuser --disabled-password appuser

RUN mkdir -p /venv && chown appuser:appuser /venv
RUN mkdir -p /home/appuser/.claude && chown appuser:appuser /home/appuser/.claude

USER appuser
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN curl -fsSL https://tinytex.yihui.org/install-bin-unix.sh | sh

#RUN tlmgr install revtext pgf textcase
WORKDIR /app

# Claude Code installs to ~/.local/bin, which is not on the default PATH
ENV PATH="/home/appuser/.local/bin:$PATH"
CMD ["/bin/sh"]
