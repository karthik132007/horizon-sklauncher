param([Parameter(Mandatory = $true)][string]$Archive)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:RUNNER_TEMP ('horizon smoke ' + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $root | Out-Null
$env:HORIZON_LAUNCHER_HOME = Join-Path $root 'launcher'
$env:HORIZON_HOME = Join-Path $root 'game'
$env:HORIZON_LAUNCHER_NO_SELF_UPDATE = '1'
$env:HORIZON_NO_AUDIO = '1'
$env:HORIZON_NO_KEYCHAIN = '1'
$env:HORIZON_TELEMETRY_URL = 'off'
$env:HORIZON_SKLAUNCHER_DIR = Join-Path $root 'source'
$env:HORIZON_INSTALL_DIR = Join-Path $root 'installed app with spaces'
$env:HORIZON_SHORTCUT_DESKTOP = Join-Path $root 'Desktop'
$env:HORIZON_SHORTCUT_MENU = Join-Path $root 'Start Menu'
Expand-Archive -LiteralPath $Archive -DestinationPath $root
$bundle = Join-Path $root 'horizon-sklauncher-windows-x86_64'
$version = & (Join-Path $bundle 'Horizon-SKlauncher.cmd') --version
if ($LASTEXITCODE -ne 0 -or "$version" -notmatch 'horizon-launcher') { throw "Portable wrapper failed: $version" }
New-Item -ItemType Directory -Force -Path $env:HORIZON_SKLAUNCHER_DIR | Out-Null
$accounts = '{"accounts":[{"type":"offline","username":"SkLocal_1","accessToken":"mock-never-copy"},{"type":"microsoft","username":"NotImported"}]}'
[IO.File]::WriteAllText((Join-Path $env:HORIZON_SKLAUNCHER_DIR 'accounts.json'), $accounts)
& (Join-Path $bundle 'Horizon-SKlauncher.cmd') account import-sklauncher
if ($LASTEXITCODE -ne 0) { throw 'Offline fixture import failed.' }
$result = & (Join-Path $bundle 'Horizon-SKlauncher.cmd') account --json
if ($LASTEXITCODE -ne 0) { throw 'Account status failed.' }
$status = $result | ConvertFrom-Json
if ($status.accounts.Count -ne 0 -or $status.owner -ne $false -or $status.offline.Count -ne 1 -or $status.offline[0].name -ne 'SkLocal_1' -or $status.offline[0].selected -ne $true) { throw 'Authentication modes were not kept separate.' }
$saved = [IO.File]::ReadAllText((Join-Path $env:HORIZON_LAUNCHER_HOME 'accounts.json'))
if ($saved.Contains('mock-never-copy') -or $saved.Contains('NotImported')) { throw 'Unexpected data copied from account fixture.' }
if ([IO.File]::ReadAllText((Join-Path $env:HORIZON_SKLAUNCHER_DIR 'accounts.json')) -ne $accounts) { throw 'Source account metadata changed.' }
& (Join-Path $bundle 'install.ps1')
$installed = Join-Path $env:HORIZON_INSTALL_DIR 'Horizon-SKlauncher.cmd'
$output = & $installed --version
if ($LASTEXITCODE -ne 0 -or "$output" -notmatch 'horizon-launcher') { throw 'Installed launcher failed in a path with spaces.' }
$shell = New-Object -ComObject WScript.Shell
foreach ($folder in @($env:HORIZON_SHORTCUT_DESKTOP, $env:HORIZON_SHORTCUT_MENU)) {
    $path = Join-Path $folder 'Horizon (SKlauncher).lnk'
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing shortcut: $path" }
    if ($shell.CreateShortcut($path).TargetPath -ne $installed) { throw "Wrong shortcut target: $path" }
}
$settings = Get-Content -Raw -LiteralPath (Join-Path $env:HORIZON_LAUNCHER_HOME 'settings.json') | ConvertFrom-Json
if ($settings.desktop_entry -ne $false) { throw 'The raw binary would register its own desktop shortcut.' }
Write-Host 'Windows portable wrapper, offline import, secret filtering, source isolation, install path with spaces, and Desktop/Start shortcuts passed.'
