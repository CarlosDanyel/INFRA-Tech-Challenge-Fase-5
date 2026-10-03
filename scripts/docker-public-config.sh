#!/usr/bin/env bash
if [ -z "${DOCKER_CONFIG:-}" ]; then
  FIAPX_DOCKER_CONFIG="$(mktemp -d)"
  mkdir -p "$FIAPX_DOCKER_CONFIG/cli-plugins"
  printf '{}\n' > "$FIAPX_DOCKER_CONFIG/config.json"
  if [ -d "$HOME/.docker/cli-plugins" ]; then
    for plugin in "$HOME"/.docker/cli-plugins/*; do
      if [ -e "$plugin" ]; then ln -s "$plugin" "$FIAPX_DOCKER_CONFIG/cli-plugins/$(basename "$plugin")"; fi
    done
  fi
  export DOCKER_CONFIG="$FIAPX_DOCKER_CONFIG"
  trap 'rm -rf "$FIAPX_DOCKER_CONFIG"' EXIT
fi
