#!/usr/bin/env bash
# claude-sandbox: run Claude Code in a podman microVM sandbox for the current project.
set -euo pipefail

# Should not run as root
if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run claude-sandbox as root." >&2
  exit 1
fi

# Should own the current folder
[ -O "$here" ] || { echo "You do not own $here." >&2; exit 1; }

TEMPLATE_DIR="${CLAUDE_SANDBOX_TEMPLATES:-$HOME/AI}"
DEST_DIR=".claude-sandbox"
COMPOSE="$DEST_DIR/podman-compose.yaml"
FILES=(Containerfile podman-compose.yaml)
BUILD=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--build]

  (no options)  run the existing sandbox image
  --build       copy the templates into $DEST_DIR, build the image, then run
EOF
}

for arg in "$@"; do
  case "$arg" in
    --build)   BUILD=1 ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# The compose file mounts the current folder read-write, so only allow
# real subfolders of our own $HOME (not $HOME itself, its parents, or other homes).
home="$(cd "$HOME" && pwd -P)"
here="$(pwd -P)"
case "$here/" in
  "$home"/?*/) ;;  # strictly below $HOME: OK
  *)
    echo "Refusing to run in $here: cd into a project folder under $home first." >&2
    exit 1
    ;;
esac

export HOST_UID="$(id -u)" HOST_GID="$(id -g)"
# Mounted at the same path inside the container (see podman-compose.yaml).
export PROJECT_DIR="$(pwd -P)"

if [ "$BUILD" -eq 1 ]; then
  for f in "${FILES[@]}"; do
    if [ ! -f "$TEMPLATE_DIR/$f" ]; then
      echo "Missing template: $TEMPLATE_DIR/$f" >&2
      exit 1
    fi
  done

  mkdir -p "$DEST_DIR"
  for f in "${FILES[@]}"; do
    cp "$TEMPLATE_DIR/$f" "$DEST_DIR/$f"
  done

  podman-compose -f "$COMPOSE" build
elif [ ! -f "$COMPOSE" ]; then
  echo "No sandbox in this folder yet. Run: $(basename "$0") --build" >&2
  exit 1
fi

# Claude's login and settings volume, shared by all projects. The compose file
# marks it external so that `down -v` in one project cannot delete it, which
# also means podman-compose will not create it.
podman volume exists claude-config || podman volume create claude-config >/dev/null

# --rm removes the container when Claude exits, so no cleanup step is needed.
exec podman-compose -f "$COMPOSE" run --rm claude
