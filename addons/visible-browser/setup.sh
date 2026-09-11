#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ -e .env ]]; then
  echo '.env already exists; leaving it unchanged.'
else
  umask 077
  printf 'BROWSER_TOOLS_API_KEY=%s\nOPEN_WEBUI_NETWORK=%s\nVISIBLE_BROWSER_PROFILE_VOLUME=%s\n' "$(openssl rand -hex 32)" "${OPEN_WEBUI_NETWORK:-open-webui_default}" "${VISIBLE_BROWSER_PROFILE_VOLUME:-open-webui_visible-browser-profile}" > .env
  echo 'Created .env with a random API key. Keep it private.'
fi
docker compose config --quiet
echo 'Compose configuration validated. No services have been started.'
