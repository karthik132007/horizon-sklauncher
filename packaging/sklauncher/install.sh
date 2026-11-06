#!/bin/sh
# Install the extracted bundle for this user, without root or game/profile files.
set -eu
bundle_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
install_dir="${HORIZON_INSTALL_DIR:-$HOME/.local/opt/horizon-sklauncher}"
mkdir -p "$install_dir"
install_dir=$(CDPATH='' cd -- "$install_dir" && pwd)
if [ "$bundle_dir" != "$install_dir" ]; then
    for name in horizon-launcher horizon-sklauncher install.sh; do
        install -m 755 "$bundle_dir/$name" "$install_dir/$name"
    done
    for name in horizon.png README.md LICENSE THIRD_PARTY_NOTICES.md BUILD-INFO.txt; do
        install -m 644 "$bundle_dir/$name" "$install_dir/$name"
    done
fi
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
desktop_dir="${HORIZON_SHORTCUT_DESKTOP:-$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "$HOME")}"
mkdir -p "$applications_dir" "$desktop_dir"
entry="$applications_dir/horizon-sklauncher.desktop"
cat > "$entry" <<EOF
[Desktop Entry]
Type=Application
Name=Horizon (SKlauncher)
Comment=Horizon with local offline profiles and SKlauncher import
Exec="$install_dir/horizon-sklauncher"
TryExec=$install_dir/horizon-sklauncher
Icon=$install_dir/horizon.png
Terminal=false
Categories=Game;
StartupWMClass=horizon-launcher
EOF
chmod 755 "$entry"
cp "$entry" "$desktop_dir/Horizon-SKlauncher.desktop"
chmod 755 "$desktop_dir/Horizon-SKlauncher.desktop"
if command -v gio >/dev/null 2>&1; then
    gio set "$desktop_dir/Horizon-SKlauncher.desktop" metadata::trusted true 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir"
fi
printf 'Installed Horizon (SKlauncher). Open it from your applications menu or Desktop.\n'
