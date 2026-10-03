#!/usr/bin/env bash
resolve_repository() {
  local parent="$1"
  local name="$2"
  if [ -d "$parent/$name" ]; then
    printf '%s\n' "$parent/$name"
    return 0
  fi
  if [ -d "$parent/$name " ]; then
    printf '%s\n' "$parent/$name "
    return 0
  fi
  printf 'Repository directory not found: %s\n' "$name" >&2
  return 1
}
