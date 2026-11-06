param([string]$Binary, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if (-not $Binary) { $Binary = Join-Path $repo 'launcher\target\release\horizon-launcher.exe' }
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo 'dist\sklauncher-windows' }
if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) { throw 'Build the Windows release executable first.' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$name = 'horizon-sklauncher-windows-x86_64'
$stage = Join-Path ([IO.Path]::GetTempPath()) ('horizon-package-' + [guid]::NewGuid())
$bundle = Join-Path $stage $name
try {
    New-Item -ItemType Directory -Force -Path $bundle | Out-Null
    Copy-Item -LiteralPath $Binary -Destination (Join-Path $bundle 'horizon-launcher.exe')
    foreach ($file in @('Horizon-SKlauncher.cmd', 'Install.cmd', 'install.ps1', 'README.md')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $bundle
    }
    foreach ($file in @('LICENSE', 'THIRD_PARTY_NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $bundle
    }
    $commit = & git -C $repo rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source commit.' }
    $info = @('Horizon SKlauncher edition', 'Source: https://github.com/karthik132007/horizon-sklauncher', "Commit: $commit", 'Platform: Windows x86-64; static C runtime', "Built: $([DateTime]::UtcNow.ToString('o'))")
    $info | Set-Content -LiteralPath (Join-Path $bundle 'BUILD-INFO.txt') -Encoding utf8
    $archive = Join-Path $OutputDirectory "$name.zip"
    Compress-Archive -LiteralPath $bundle -DestinationPath $archive -Force
    $digest = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$digest  $name.zip" | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS-windows.txt') -Encoding ascii
    Write-Host "Created $archive"
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
