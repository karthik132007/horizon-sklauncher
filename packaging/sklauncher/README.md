# Horizon (SKlauncher) for Linux x86-64

Unofficial fork: https://github.com/karthik132007/horizon-sklauncher
Upstream Horizon: https://github.com/horizon-rust/horizon

## Start

Extract the archive, open a terminal in the extracted folder, and run:

```sh
./horizon-sklauncher
```

For applications-menu and Desktop shortcuts, run `./install.sh`. This copies the
launcher to `~/.local/opt/horizon-sklauncher`; root is not required. The launcher
keeps data under `~/.local/share/horizon-sklauncher` (or `$XDG_DATA_HOME`). Keep
`horizon-launcher` beside the `horizon-sklauncher` wrapper; use the wrapper to start.
To uninstall, remove the install folder and its two shortcuts. Game/profile data
is separate; retain it unless you deliberately want to delete it.

## Profiles

SKlauncher 4 offline names are discovered from `~/.sklauncher/accounts.json`.
Use Settings → Account → Import from SKlauncher to import installed instances.
A relocated install can be selected with `HORIZON_SKLAUNCHER_DIR=/absolute/path`.
Manual creation of an offline name is available in Account settings. Switch profiles
from the top bar. The import does not read/copy tokens or modify SKlauncher settings.

Installed Java version jars, libraries and assets are reused read-only. Writable game
content is copied into Horizon's own instance, using additional disk space. Install
missing game versions/files in SKlauncher first. The legacy SKlauncher 3 binary
account format is unsupported; create a name manually instead. Dynamic latest-version
profiles are skipped unless a cached local manifest identifies an installed version.

No Minecraft game files, native game executable, profiles, worlds, tokens, mods or
Java runtime are included in this archive. The native Rust game can be installed from
Horizon upstream through the launcher; importing a Java instance uses installed Java
Minecraft and its mod loader. The native Rust client does not execute Java mod code.

Offline mode cannot authenticate to Realms or online-mode servers. Microsoft sign-in
code is retained, but this build has no Microsoft client ID embedded; an approved
`HORIZON_MSA_CLIENT_ID` is required for Microsoft mode. Never use another launcher's ID
or credentials. See the repository's docs/microsoft-account.md.

Self-updates and telemetry transmission are disabled by the wrapper. New fork versions
must be downloaded from this repository's Releases page.

## Requirements and compatibility

This initial binary was built and tested on Arch Linux x86-64 with Wayland/Hyprland.
It needs glibc 2.44+ and system graphics/window/font libraries. Other distributions
are not live-tested; build from source if the binary cannot start on yours. No Windows,
macOS or ARM binary is included. The Java instance also requires the appropriate Java
runtime (SKlauncher's bundled runtime is detected when available).

On Arch Linux, install missing platform libraries with:

```sh
sudo pacman -S --needed wayland libxkbcommon libxkbcommon-x11 libxcb libx11 \
  fontconfig freetype2 vulkan-icd-loader alsa-lib systemd-libs
```

Use the appropriate Vulkan/OpenGL driver for your GPU. If an error mentions a missing
shared library, install that library for your distribution or build from source.

Verify the archive against the accompanying `SHA256SUMS` before extracting:
`sha256sum -c SHA256SUMS` (place both release files in the same folder).

MIT licensed; copyright and third-party notices are included. Unofficial; not endorsed
by the upstream Horizon maintainers, SKlauncher, Mojang, or Microsoft.
