$ErrorActionPreference = 'Stop'
$bundle = $PSScriptRoot
$target = if ($env:HORIZON_INSTALL_DIR) { $env:HORIZON_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\Horizon-SKlauncher' }
New-Item -ItemType Directory -Force -Path $target | Out-Null
$target = (Resolve-Path -LiteralPath $target).Path
if (-not [string]::Equals($bundle, $target, [StringComparison]::OrdinalIgnoreCase)) {
    foreach ($name in @('horizon-launcher.exe', 'Horizon-SKlauncher.cmd', 'Install.cmd', 'install.ps1', 'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'BUILD-INFO.txt')) {
        Copy-Item -LiteralPath (Join-Path $bundle $name) -Destination (Join-Path $target $name) -Force
    }
}
$desktop = if ($env:HORIZON_SHORTCUT_DESKTOP) { $env:HORIZON_SHORTCUT_DESKTOP } else { [Environment]::GetFolderPath('Desktop') }
$menu = if ($env:HORIZON_SHORTCUT_MENU) { $env:HORIZON_SHORTCUT_MENU } else { [Environment]::GetFolderPath('Programs') }
$shell = New-Object -ComObject WScript.Shell
foreach ($folder in @($desktop, $menu)) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $link = $shell.CreateShortcut((Join-Path $folder 'Horizon (SKlauncher).lnk'))
    $link.TargetPath = Join-Path $target 'Horizon-SKlauncher.cmd'
    $link.WorkingDirectory = $target
    $link.IconLocation = (Join-Path $target 'horizon-launcher.exe') + ',0'
    $link.WindowStyle = 7
    $link.Save()
}
Write-Host 'Installed Horizon (SKlauncher) for your Windows account. Open it from Start or Desktop.'
