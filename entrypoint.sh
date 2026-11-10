#!/bin/bash
set -e

echo "Sandbox started as user: $(id -un) in directory: $(pwd)"

if [ "$(id -un)" != "appuser" ]; then
  #runuser -u appuser -- uv sync
  echo "Running ${@} as appuser"
  exec runuser -u appuser -- "$@"
fi

#uv sync
exec "$@"
