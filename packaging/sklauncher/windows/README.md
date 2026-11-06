# Horizon (SKlauncher) — Windows x64

Unofficial fork: https://github.com/karthik132007/horizon-sklauncher
Upstream: https://github.com/horizon-rust/horizon

## Start or install

1. Extract the entire ZIP to a folder you can write to.
2. Double-click `Horizon-SKlauncher.cmd` to start the portable launcher.
3. For Desktop and Start-menu shortcuts, double-click `Install.cmd`. No administrator
   account is required. Files are installed under `%LOCALAPPDATA%\Programs\Horizon-SKlauncher`.

Use the wrapper/shortcuts to keep self-updates and telemetry transmission disabled.
Keep the `.exe` and wrapper together. This community executable is not code-signed.

The launcher and game data are separate, under `%LOCALAPPDATA%\Horizon-SKlauncher`.
Uninstall by deleting the installed program folder and its two shortcuts; keep the
separate game/data folder unless you deliberately want to delete your instances.

## Accounts and profiles

Create a local/offline name in Settings → Account, or import SKlauncher profiles there.
Switch profiles in the top bar. Offline profiles do not receive Microsoft credentials
and cannot use Realms or authenticated online servers.

Automatic discovery checks the home-directory `.sklauncher`/`.minecraft` JSON layouts.
If your Windows installation stores its SKlauncher 4 `accounts.json` and `instances.json`
elsewhere, set `HORIZON_SKLAUNCHER_DIR` to that folder before starting. For example,
from Command Prompt (replace the path with your actual installation folder):

```bat
set "HORIZON_SKLAUNCHER_DIR=C:\path\to\SKlauncher-data"
Horizon-SKlauncher.cmd
```

Legacy SKlauncher binary account stores are unsupported; create a local name manually.
The Windows release checks the observed JSON format with disposable fixtures. A real
Windows SKlauncher installation and Minecraft game session have not been live-tested.

Installed jars, libraries and assets are read in place. Writable game content is copied
into Horizon's own instance to avoid changing SKlauncher's game folder. Missing game
files must be installed separately. This ZIP includes no Minecraft jars/assets, native
game client, Java runtime, accounts, worlds, mods, passwords or tokens.

Microsoft sign-in code remains available, but this build embeds no Microsoft client ID.
An approved `HORIZON_MSA_CLIENT_ID` is required for that mode; do not use another
launcher's ID or credentials. Details are in the repository's docs/microsoft-account.md.

## Requirements and verification

64-bit Windows 10/11 and a working graphics driver are required. This is an x64 build,
not a native ARM build. The C runtime is statically linked; release checks reject
non-system DLL dependencies. GPU/UI rendering and actual gameplay are not checked
by the command-line CI smoke test.

Check the ZIP with PowerShell `Get-FileHash .\horizon-sklauncher-windows-x86_64.zip -Algorithm SHA256`
and compare with `SHA256SUMS-windows.txt` from the same release.

MIT licensed. Copyright and third-party notices are included. Not affiliated with
upstream Horizon's maintainers, SKlauncher, Mojang or Microsoft.
