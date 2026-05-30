#!/usr/bin/env bash
#
# Pushes the five GitHub Actions secrets the release workflow needs, reading
# them straight from the local (gitignored) files this repo already contains.
# Run this ONCE after authenticating gh. Safe to re-run (it overwrites).
#
#   1. gh auth login        # one-time, opens a browser
#   2. ./scripts/setup_release_secrets.sh
#
# It never prints secret values. Requires: gh, base64.

set -euo pipefail

cd "$(dirname "$0")/.."

REPO="ShekhawatPriya/TG-Cloud-Drive"
KEYSTORE="android/app/upload-keystore.jks"
KEY_PROPS="android/key.properties"
ENV_FILE=".env.local"

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

# --- preconditions -----------------------------------------------------------
command -v gh >/dev/null  || { red "gh CLI not found. Install: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { red "Not logged in. Run: gh auth login"; exit 1; }

for f in "$KEYSTORE" "$KEY_PROPS" "$ENV_FILE"; do
  [ -f "$f" ] || { red "Missing required file: $f"; exit 1; }
done

# --- read values from key.properties ----------------------------------------
get_prop() { grep -E "^$1=" "$KEY_PROPS" | head -1 | cut -d'=' -f2-; }
STORE_PASSWORD="$(get_prop storePassword)"
KEY_ALIAS="$(get_prop keyAlias)"
KEY_PASSWORD="$(get_prop keyPassword)"

[ -n "$STORE_PASSWORD" ] || { red "storePassword missing in $KEY_PROPS"; exit 1; }
[ -n "$KEY_ALIAS" ]      || { red "keyAlias missing in $KEY_PROPS"; exit 1; }
[ -n "$KEY_PASSWORD" ]   || { red "keyPassword missing in $KEY_PROPS"; exit 1; }

# --- push secrets ------------------------------------------------------------
echo "Setting secrets on $REPO ..."

base64 < "$KEYSTORE" | gh secret set KEYSTORE_BASE64 --repo "$REPO"
printf '%s' "$STORE_PASSWORD" | gh secret set KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$KEY_ALIAS"      | gh secret set KEY_ALIAS         --repo "$REPO"
printf '%s' "$KEY_PASSWORD"   | gh secret set KEY_PASSWORD      --repo "$REPO"
gh secret set ENV_LOCAL --repo "$REPO" < "$ENV_FILE"

green "Done. 5 secrets set: KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD, ENV_LOCAL"
echo "Verify anytime with: gh secret list --repo $REPO"
