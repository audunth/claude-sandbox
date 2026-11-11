FROM alpine:latest

ARG HOST_UID=1000
ARG HOST_GID=1000

# Create group and user matching host UID/GID
RUN addgroup --gid ${HOST_GID} appuser && \
    adduser --uid ${HOST_UID} --ingroup appuser --disabled-password appuser

RUN mkdir -p /venv && chown appuser:appuser /venv
RUN mkdir -p /home/appuser/.claude && chown appuser:appuser /home/appuser/.claude

USER appuser

# Rarely-changing tooling. Kept above the dnf layer so editing the RPM list
# below does not invalidate (and re-run) these installs.
#RUN curl -fsSL https://astral.sh/uv/install.sh | sh && \
#    curl -fsSL https://claude.ai/install.sh | bash
#USER root

# Frequently-changing RPMs. Kept last so adding a package only rebuilds from here down.
#RUN dnf install wget git make vim free libpq-devel python3-devel gcc pandoc perl-File-Find -y && \
#    dnf clean all

COPY --chown=appuser entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER appuser
#RUN wget -qO- "https://tinytex.yihui.org/install-bin-unix.sh" | sh
WORKDIR /app

# This is needed because entrypoint does not have .local/bin in the PATH
ENV PATH="/home/appuser/.local/bin:$PATH"
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
