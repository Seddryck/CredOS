#!/usr/bin/env bash
set -euo pipefail

# Use the runner's disposable keychain search list and restore it even on failure.
fixture_dir=$(mktemp -d)
keychain="$fixture_dir/credos.keychain-db"
previous_default=$(security default-keychain -d user | tr -d '"' | xargs)
previous_search=()
while IFS= read -r entry; do
  entry=$(printf '%s' "$entry" | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')
  previous_search+=("$entry")
done < <(security list-keychains -d user)
cleanup() {
  security default-keychain -d user -s "$previous_default"
  security list-keychains -d user -s "${previous_search[@]}"
  security delete-keychain "$keychain"
  rm -rf -- "$fixture_dir"
}
trap cleanup EXIT
# This random password protects only the disposable test keychain; never enable shell tracing.
fixture_password=$(openssl rand -hex 24)
security create-keychain -p "$fixture_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$fixture_password" "$keychain"
security list-keychains -d user -s "$keychain"
security default-keychain -d user -s "$keychain"
export CREDOS_TEST_NATIVE=1
dotnet test src/CredOS.Core.Testing -c Release --no-build --no-restore --filter "TestCategory=Native"
