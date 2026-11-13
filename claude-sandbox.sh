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

command -v git >/dev/null || { echo "git is not installed." >&2; exit 1; }

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

# The project's .git is mounted read-only (see podman-compose.yaml), so the
# project must be the top of its own git repository. Look only at repositories
# below $HOME (a dotfiles repo in ~ does not count) and ignore any GIT_DIR or
# GIT_WORK_TREE from the environment.
unset GIT_DIR GIT_WORK_TREE
export GIT_CEILING_DIRECTORIES="$home"

# Inside .git (or a bare repository), the repository's internals would be
# mounted read-write.
if [[ "$here/" == */.git/* ]] || [ "$(git rev-parse --is-inside-git-dir 2>/dev/null)" = true ]; then
  echo "Refusing to run inside a git folder ($here): cd into the project folder." >&2
  exit 1
fi

if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  # In a subfolder, the repository's .git would not be mounted at all.
  if [ "$top" != "$here" ]; then
    echo "$here is inside the git repository $top. Run $(basename "$0") from $top instead." >&2
    exit 1
  fi
else
  # read fails at end of input, but still sets answer to what it got.
  read -r -p "No git repository in $here. Run git init? [y/N] " answer || true
  case "$answer" in
    [yY]|[yY][eE][sS]) git init -q ;;
    *)
      echo "Not starting: the sandbox needs a git repository to mount .git read-only." >&2
      exit 1
      ;;
  esac
fi

export HOST_UID="$(id -u)" HOST_GID="$(id -g)"
# Mounted at the same path inside the container (see podman-compose.yaml).
export PROJECT_DIR="$here"
# The container's own .venv for this project, named after the project's path.
export VENV_VOLUME="claude-sandbox-venv$(printf %s "$here" | tr -c 'A-Za-z0-9_.-' '-')"

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
