#!/usr/bin/env bash
# claude-sandbox: run Claude Code in a podman microVM sandbox for the current project.
set -euo pipefail

# Should not run as root
if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run claude-sandbox as root." >&2
  exit 1
fi

# The Containerfile and compose file are used in place, from outside the
# project, so nothing is written to the project and the agent cannot edit them.
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SANDBOX_DIR="${CLAUDE_SANDBOX_DIR:-$SCRIPT_DIR}"
COMPOSE="$SANDBOX_DIR/podman-compose.yaml"
BUILD=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--build]

  (no options)  run the sandbox image
  --build       build (or rebuild) the image from $SANDBOX_DIR, then run
EOF
}

for arg in "$@"; do
  case "$arg" in
    --build)   BUILD=1 ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -f "$COMPOSE" ]; then
  echo "Missing $COMPOSE (set CLAUDE_SANDBOX_DIR to the folder holding it)." >&2
  exit 1
fi

# The compose file mounts the current folder read-write, so only allow
# real subfolders of our own $HOME (not $HOME itself, its parents, or other homes).
home="$(cd "$HOME" && pwd -P)"
here="$(pwd -P)"

# Should own the current folder
[ -O "$here" ] || { echo "You do not own $here." >&2; exit 1; }

case "$here/" in
  "$home"/?*/) ;;  # strictly below $HOME: OK
  *)
    echo "Refusing to run in $here: cd into a project folder under $home first." >&2
    exit 1
    ;;
esac

export HOST_UID="$(id -u)" HOST_GID="$(id -g)"
# Mounted at the same path inside the container (see podman-compose.yaml).
export PROJECT_DIR="$here"

if [ "$BUILD" -eq 1 ]; then
  podman-compose -f "$COMPOSE" build
fi

# Claude's login and settings volume, shared by all projects. The compose file
# marks it external so that `down -v` in one project cannot delete it, which
# also means podman-compose will not create it.
podman volume exists claude-config || podman volume create claude-config >/dev/null

# --rm removes the container when Claude exits, so no cleanup step is needed.
# podman-compose builds the image here if it does not exist yet.
exec podman-compose -f "$COMPOSE" run --rm claude
