#!/bin/sh
# Create a launcher-only release. Never archive a user's launcher or game data directory.
set -eu
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(dirname -- "$(dirname -- "$script_dir")")
binary="${HORIZON_RELEASE_BINARY:-$repo_root/launcher/target/release/horizon-launcher}"
out_dir="${HORIZON_RELEASE_OUTPUT:-$repo_root/dist/sklauncher}"
[ -x "$binary" ] || { printf 'Build the release launcher first.\n' >&2; exit 1; }
mkdir -p "$out_dir"
out_dir=$(CDPATH='' cd -- "$out_dir" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
name=horizon-sklauncher-linux-x86_64
bundle="$stage/$name"
mkdir -p "$bundle"
install -m 755 "$binary" "$bundle/horizon-launcher"
for script in horizon-sklauncher install.sh; do
    install -m 755 "$script_dir/$script" "$bundle/$script"
done
install -m 644 "$script_dir/README.md" "$bundle/README.md"
install -m 644 "$repo_root/LICENSE" "$repo_root/THIRD_PARTY_NOTICES.md" "$bundle/"
install -m 644 "$repo_root/packaging/icons/hicolor/256x256/apps/horizon.png" "$bundle/horizon.png"
{
    printf 'Horizon SKlauncher edition\n'
    printf 'Source: https://github.com/karthik132007/horizon-sklauncher\n'
    printf 'Commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'Platform: Linux x86-64 (initial build tested on Arch Linux)\n'
    printf 'Built: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    "$binary" --version
    printf 'Minimum required glibc symbol version: '
    objdump -T "$binary" | sed -n 's/.*(GLIBC_\([0-9.]*\)).*/\1/p' | sort -Vu | tail -n 1
} > "$bundle/BUILD-INFO.txt"
tar -czf "$out_dir/$name.tar.gz" -C "$stage" "$name"
(cd "$out_dir" && sha256sum "$name.tar.gz" > SHA256SUMS)
printf 'Created %s/%s.tar.gz\n' "$out_dir" "$name"
