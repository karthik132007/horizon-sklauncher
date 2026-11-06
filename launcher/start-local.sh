#!/bin/sh
# Keep this personal fork and all writable game data separate from other launchers.
set -eu
launcher_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fork_root=$(dirname -- "$launcher_dir")
export HORIZON_LAUNCHER_HOME="${HORIZON_LAUNCHER_HOME:-$fork_root/.local/personal/launcher}"
export HORIZON_HOME="${HORIZON_HOME:-$fork_root/.local/personal/game}"
export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
export HORIZON_TELEMETRY_URL=off
mkdir -p "$HORIZON_HOME"
cd "$HORIZON_HOME"
exec "$launcher_dir/target/release/horizon-launcher" "$@"
