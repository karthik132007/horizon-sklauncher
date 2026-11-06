#!/bin/sh
# Install this personal fork under a distinct name, leaving the existing Horizon entry alone.
set -eu
launcher_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fork_root=$(dirname -- "$launcher_dir")
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
desktop_dir=$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "$HOME")
mkdir -p "$applications_dir" "$desktop_dir"
entry="$applications_dir/horizon-sklauncher.desktop"
cat > "$entry" <<EOF
[Desktop Entry]
Type=Application
Name=Horizon (SKlauncher)
Comment=Personal Horizon launcher with local offline profiles
Exec="$launcher_dir/start-local.sh"
TryExec=$launcher_dir/start-local.sh
Path=$fork_root
Icon=$fork_root/packaging/icons/hicolor/256x256/apps/horizon.png
Terminal=false
Categories=Game;
StartupWMClass=horizon-launcher
EOF
chmod +x "$entry"
cp "$entry" "$desktop_dir/Horizon-SKlauncher.desktop"
chmod +x "$desktop_dir/Horizon-SKlauncher.desktop"
if command -v gio >/dev/null 2>&1; then
    gio set "$desktop_dir/Horizon-SKlauncher.desktop" metadata::trusted true 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir"
fi
printf 'Installed Horizon (SKlauncher) in the applications menu and %s\n' "$desktop_dir"
