#!/usr/bin/env bash
set -euo pipefail

# Private home and D-Bus session: never use or lock the caller's desktop keyring.
fixture_home=$(mktemp -d)
trap 'rm -rf -- "$fixture_home"' EXIT
export XDG_DATA_HOME="$fixture_home/data"
export XDG_CONFIG_HOME="$fixture_home/config"
export XDG_CACHE_HOME="$fixture_home/cache"
export XDG_RUNTIME_DIR="$fixture_home/runtime"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
dbus-run-session -- bash -euo pipefail -c '
  head -c 32 /dev/urandom | base64 | gnome-keyring-daemon --unlock --components=secrets >/dev/null
  export CREDOS_TEST_NATIVE=1
  dotnet test src/CredOS.Core.Testing -c Release --no-build --no-restore --filter "TestCategory=Native"
  # Lock only this disposable collection after all lifecycle tests have finished.
  export CREDOS_TEST_ISOLATED_SECRET_SERVICE=1
  dotnet test src/CredOS.Core.Testing -c Release -f net10.0 --no-build --no-restore --filter "FullyQualifiedName~LockedCollection"
'
export DBUS_SESSION_BUS_ADDRESS="unix:path=$fixture_home/missing-session"
export CREDOS_TEST_MISSING_SESSION=1
dotnet test src/CredOS.Core.Testing -c Release -f net10.0 --no-build --no-restore --filter "FullyQualifiedName~MissingSession"
