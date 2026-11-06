# SKlauncher profile support

Branch: `feat/sklauncher-offline-profiles`.

## Run on Arch Linux

Install Rust and the platform libraries if missing:

```sh
sudo pacman -S --needed rust base-devel pkgconf wayland libxkbcommon \
  libxkbcommon-x11 libxcb libx11 fontconfig freetype2 vulkan-icd-loader alsa-lib systemd-libs
git clone https://github.com/karthik132007/horizon-sklauncher.git
cd horizon-sklauncher
cargo build --release --manifest-path launcher/Cargo.toml
./launcher/start-local.sh account import-sklauncher
./launcher/start-local.sh
./launcher/install-shortcut.sh   # optional: application menu and Desktop shortcut
```

The installed application-menu and Desktop shortcut is **Horizon (SKlauncher)**.
The wrapper disables launcher self-updates so upstream updates cannot replace this fork.
It keeps Horizon accounts, settings and game folders under `.local/personal/` in this
checkout, separate from the existing Horizon installation. Do not move/delete the
checkout while using its shortcut.

## Profiles and instances

The first GUI startup discovers valid local offline names. Settings → Account →
**Import from SKlauncher** imports installed Java instances, and the same operation is
available as `account import-sklauncher`. The top-bar account menu switches between
local names and Microsoft accounts. Settings supports adding a name manually;
`account offline NAME` does the same from a terminal.

Discovery checks `~/.sklauncher` and `~/.minecraft`; override a relocated installation
with `HORIZON_SKLAUNCHER_DIR=/absolute/path`. This fork supports the SKlauncher 4 JSON
layout observed locally: `accounts.json` (`type: offline`, `username`) and
`instances.json` (`name`, `versionId`, absolute `directory`). Typed deserialization
ignores all other account fields. Microsoft accounts in SKlauncher are never imported.
No token, password, cookie, or binary account store is imported or logged.
Legacy SKlauncher 3 binary accounts are unsupported; add a local name manually.

Offline UUIDs use Java's `UUID.nameUUIDFromBytes("OfflinePlayer:" + username)` (MD5,
version 3), preserving name case. Authenticated UUIDs are never reused for offline
identities. An offline profile receives no Microsoft session, Xbox ID or token;
Java launches use `legacy` user type with an empty access token. Online-mode servers
require a legitimate Microsoft login through Horizon. Source builds need an approved
`HORIZON_MSA_CLIENT_ID` (as upstream does); see `../docs/microsoft-account.md`.
Microsoft sign-in remains implemented and optional; it is not live-tested by this fork.

Installed version JSON files resolve the base version, loader libraries and Java
requirement. SKlauncher's bundled Mojang runtime of the required major is preferred,
then Horizon's normal runtime selection applies. Existing version JSON, jars,
libraries and assets are read in place without duplicate downloads. Natives and
legacy virtual assets are generated in Horizon's folders. Missing game files must
be installed in SKlauncher, or downloaded using Horizon's Microsoft account mode.

Saves, mods, config, resource packs, shader packs, screenshots, options and server lists
are copied to a new Horizon instance. This intentionally uses extra space for writable
game content: sharing it would let Minecraft overwrite SKlauncher data. No account
stores or launcher/browser state are copied. Subsequent imports are idempotent and
do not overwrite Horizon's copies. Changes in SKlauncher after import are not synced.
Dynamic latest-version profiles are skipped unless a cached local manifest resolves
them to an installed version. Fabric/Quilt/Forge/NeoForge use Horizon's existing Java
launch path; the native Rust Horizon client itself does not execute Java mods.

The observed SKlauncher settings do not specify custom memory/JVM overrides, so imported
instances retain Horizon's default memory (4096 MiB) and can be edited normally.
Unsupported profile layouts use manual creation. First-run data-collection questions
remain part of Horizon; the personal wrapper disables telemetry transmission.

## Checks

```sh
cargo fmt --manifest-path launcher/Cargo.toml --check
cargo clippy --manifest-path launcher/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path launcher/Cargo.toml --lib
cargo test --manifest-path launcher/Cargo.toml --bin horizon-launcher
cargo test --manifest-path launcher/Cargo.toml --test sklauncher_import --test owner_gate
```

The tests cover profile filtering/errors, UUID reference values, explicit selection,
offline/Microsoft mode separation, ownership checks for downloads, Java arguments,
legacy asset isolation, and a full import/play with a fixture Java executable. Test
runs use temporary launcher/game/config/data folders. A fixture executable validates
the command and folder contract; it does not establish real Minecraft compatibility.

## Changed files

| Files | Purpose |
| --- | --- |
| `src/sklauncher.rs`, `src/lib.rs` | Metadata-only discovery, import, Java offline UUIDs, installed version/runtime references |
| `src/account.rs`, `src/account/tests.rs` | Offline/Microsoft separation and account tests; download ownership remains strict |
| `src/backend.rs`, `src/instances.rs` | Read installed Java profiles without modifying their files; store import metadata |
| `src/java_launch.rs`, `src/java_launch/tests.rs` | Offline Java arguments, Maven library paths, writable legacy assets isolated from SKlauncher |
| `src/main.rs`, `src/owner_page.rs` | Dashboard startup, optional Microsoft sheet, background import completion |
| `src/switch_page.rs`, `src/glass_account.rs`, `src/glass_instance.rs` | Import button in both account layouts and installed-game messaging |
| `src/cli.rs`, `../docs/launcher-commands.md` | Import command and generated command reference |
| `tests/sklauncher_import.rs`, `tests/owner_gate.rs` | Full fixture import/play, unchanged source checks, authentication-mode separation |
| `start-local.sh`, `install-shortcut.sh`, `SKLAUNCHER.md` | Personal launch wrapper, application/Desktop shortcuts, setup and limitations |

## Verification on this machine (6 November 2026)

- Launcher library tests: **621 passed**, 7 intentionally ignored.
- Launcher binary tests: **105 passed**.
- Import and authentication integration tests: **4 passed**.
- Optimized release build succeeded (`cargo build --release --locked --offline`);
  launcher version/installed shortcut verified against the resulting executable.
- Formatting, `clippy --all-targets -D warnings`, public-tree check, desktop-entry
  validation and shell syntax checks passed.
- Repository Python suite: 696 tests, 1 skipped. Its only initial error was a blocked
  local test socket; rerunning the affected 24-test module with local sockets enabled
  passed (1 skipped).
- Visible dashboard startup: the imported profile shown as **Offline**, `SKlauncher · fabric`
  selected, no Microsoft gate.
- Real imported Fabric 26.3: all 111 mods discovered, the imported username applied, graphics
  initialized and resource atlases loaded. Realms/session errors are expected offline.
  This checks client startup; an online server or a saved world was not tested.
- Only the installed Fabric profile was live-tested; other loader combinations retain
  Horizon's existing launch implementation and were not exercised with real games.
- Existing native Horizon Nightly `nightly-2026-11-05-66f3981` copied into the personal
  installation and started offline through the modified launcher in a fresh game
  folder. Its five-frame offscreen smoke test exited successfully with Vulkan rendering.
- Read-only source handling checked with disposable fixtures and a live local installation.


The portable release disables launcher self-updates and telemetry transmission. Native
Horizon game builds are installed separately from upstream; the download does not include
a native client, game assets, Minecraft jars, accounts, mods, or worlds.
