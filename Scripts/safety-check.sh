#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_SOURCE="$ROOT_DIR/Sources/main.swift"

restart_block="$(awk '
  /private func restartCodexApp\(\)/ { in_restart = 1 }
  in_restart && /^    private func / && !/private func restartCodexApp\(\)/ { exit }
  in_restart { print }
' "$MAIN_SOURCE")"

if grep -Eq '/bin/kill|-KILL|SIGKILL|ensureComputerUsePluginConfigured|ensureComputerUsePluginConfigured\(' <<< "$restart_block"; then
  echo "Unsafe restart behavior remains in restartCodexApp." >&2
  exit 1
fi

if ! grep -q 'application.terminate()' <<< "$restart_block"; then
  echo "restartCodexApp no longer requests graceful application termination." >&2
  exit 1
fi

if grep -q 'runCodexAuth(force ? \["list", "--debug"\]' "$MAIN_SOURCE"; then
  echo "refreshAccounts still requests the unsupported codex-auth --debug flag." >&2
  exit 1
fi

if ! grep -q 'var result = self.runCodexAuth(\["list", "--json"\])' "$MAIN_SOURCE"; then
  echo "refreshAccounts no longer uses the structured live codex-auth list path." >&2
  exit 1
fi

printf '%s\n' 'Safety checks passed'
