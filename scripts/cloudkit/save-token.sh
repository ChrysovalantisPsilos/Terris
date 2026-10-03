#!/bin/bash
# Saves the CloudKit management token for `xcrun cktool` on a CI runner,
# from $CLOUDKIT_MANAGEMENT_TOKEN. Never prints the token.
set -euo pipefail
token=$(printf '%s' "${CLOUDKIT_MANAGEMENT_TOKEN:-}" | tr -d '[:space:]')
if [ -z "$token" ]; then echo "::error::CLOUDKIT_MANAGEMENT_TOKEN is empty"; exit 1; fi
# cktool reads the token from standard input when it isn't given; a file
# store avoids needing an unlocked login keychain on the runner.
if printf '%s\n' "$token" | xcrun cktool save-token --type management --method file >/dev/null 2>&1; then
  echo "CloudKit token saved."
  exit 0
fi
if printf '%s\n' "$token" | xcrun cktool save-token --type management >/dev/null 2>&1; then
  echo "CloudKit token saved (keychain)."
  exit 0
fi
echo "::error::cktool didn't accept the token. Its options:"
xcrun cktool save-token --help || true
exit 1
