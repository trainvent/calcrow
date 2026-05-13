#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE"
  echo "Copy .env.example to .env and fill in the values before building."
  exit 1
fi

flutter build web --release --base-href / --dart-define-from-file="$ENV_FILE" "$@"
