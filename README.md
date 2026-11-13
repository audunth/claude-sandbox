# claude-sandbox

Based on https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/ and https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/. Also contains tinytex to compile documents.

For now, these are just the files. Will be updated with a proper installable shell script to copy and run.

## Usage

Copy Containerfile, entrypoint.sh and podman-compose.yaml to an .agent-sandbox directory in your project. 

Build with

HOST_UID=$(id -u) HOST_GID=$(id -g) podman-compose -f .agent-sandbox/podman-compose.yaml build

Run with 

HOST_UID=$(id -u) HOST_GID=$(id -g) podman-compose -f .agent-sandbox/podman-compose.yaml run --rm claude    


## Not installed yet (consider if needed)

- uv
- pandoc (using just .tex for now)
- any compilers (rust, c++, julia)


## Inspiration

https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/

https://github.com/msehnout/agent-sandbox

https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/
