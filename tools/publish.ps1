<#
.SYNOPSIS
  Maintainer tool: publish the archive's files to GitHub releases or archive.org.

.DESCRIPTION
  The binaries are not in git. They live in three places with the same content:

  GitHub releases (-Target GitHub)
    One release per 'tag' in catalog.csv (swarm, modules, drivers, extras), with flat asset
    names (the 'asset' column). Creates missing releases and uploads only missing or
    changed assets; a file that several rows share is uploaded once.
    Needs the GitHub CLI: winget install GitHub.cli, then gh auth login. The repository must
    be public, or anonymous downloads fail.

  archive.org (-Target ArchiveOrg)
    The item from $Mirrors.ArchiveOrg in install.ps1 (default roccat-swarm-archive), with
    the folder tree as here (the 'path' column), plus install.ps1, catalog.csv and README.md.
    Re-running skips files that are already there. Needs the internetarchive tool:
    pip install internetarchive, then ia configure (your archive.org account).

  MEGA (by hand)
    1. Upload swarm, modules, drivers, addons, sdk, other, catalog.csv, install.ps1 and
       README.md to one MEGA folder, keeping the tree.
    2. Share the folder: right-click > Share > Share link, with the decryption key
       (https://mega.nz/folder/<id>#<key>).
    3. Put the link in $Mirrors.Mega at the top of install.ps1 and in the README's mirror
       table, and commit.

  Test a mirror afterwards: download through it only, into an empty folder. Every file is
  checked against its SHA-256:
    install.ps1 -Source ArchiveOrg -NoFallback -Swarm latest -AllModules -DownloadOnly -OutDir $env:TEMP\mirror-test

.EXAMPLE
  tools\publish.ps1 -WhatIf                 # GitHub: show what would be uploaded
  tools\publish.ps1                         # GitHub
  tools\publish.ps1 -Target ArchiveOrg
#>
param(
  [ValidateSet('GitHub', 'ArchiveOrg')][string]$Target = 'GitHub',
  [string]$Root = (Split-Path $PSScriptRoot -Parent),
  [string]$Gh = 'gh',            # path to gh.exe if it is not on PATH
  [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
Set-Location $Root
$installer = [IO.File]::ReadAllText((Join-Path $Root 'install.ps1'))

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build-catalog.ps1') -Check
if ($LASTEXITCODE -ne 0) { throw 'catalog.csv is out of date: run tools\build-catalog.ps1 first' }
$rows = Import-Csv (Join-Path $Root 'catalog.csv')

if ($Target -eq 'ArchiveOrg') {
  if (-not (Get-Command ia -ErrorAction SilentlyContinue)) { throw 'needs the internetarchive tool: pip install internetarchive, then ia configure' }
  $item = ([regex]::Match($installer, "ArchiveOrg = '([^']+)'").Groups[1].Value -split '/')[-1]
  # Paths relative to the root, so the item keeps the folder tree.
  $files = @($rows.path | Sort-Object -Unique) + @('install.ps1', 'catalog.csv', 'README.md')
  $meta = @('--metadata=mediatype:software', '--metadata=title:ROCCAT Swarm Archive',
    '--metadata=description:ROCCAT Swarm (v1) installers, device modules, pre-Swarm drivers and add-ons, with an installer script (install.ps1). Index: catalog.csv.',
    '--metadata=subject:ROCCAT;Swarm;Turtle Beach;drivers')
  Write-Host "archive.org item '$item': $($files.Count) files"
  if ($WhatIf) { $files | ForEach-Object { Write-Host "would upload $_" }; exit 0 }
  & ia upload $item @files @meta --checksum --retries 10
  if ($LASTEXITCODE -ne 0) { throw 'ia upload failed' }
  Write-Host "Done. Test: install.ps1 -Source ArchiveOrg -NoFallback -Swarm latest -AllModules -DownloadOnly -OutDir <empty folder>"
  exit 0
}

if (-not (Get-Command $Gh -ErrorAction SilentlyContinue)) { throw 'needs the GitHub CLI: winget install GitHub.cli, then gh auth login (or pass -Gh <path to gh.exe>)' }
$repo = [regex]::Match($installer, "\`$Repo = '([^']+)'").Groups[1].Value
$titles = @{
  swarm   = @('ROCCAT Swarm installers', 'Every archived ROCCAT Swarm (v1) installer build. Use install.ps1; catalog.csv lists every file.')
  modules = @('ROCCAT Swarm device modules', 'The device modules that Swarm downloads for each device. catalog.csv maps USB PIDs to files.')
  drivers = @('Standalone drivers (pre-Swarm devices)', 'Windows drivers for ROCCAT devices that Swarm never supported.')
  extras  = @('Add-ons, SDK and other files', 'Talk FX, the Power-Grid SDK, Swarm II and other archived files.')
}
$staging = Join-Path $env:TEMP 'roccat-release-assets'

foreach ($group in ($rows | Group-Object tag)) {
  $tag = $group.Name
  $existing = @{}
  # PowerShell 5.1 turns a native command's stderr into an error under 'Stop'.
  $ErrorActionPreference = 'Continue'
  $json = & $Gh release view $tag --repo $repo --json assets 2>$null
  $found = $LASTEXITCODE -eq 0
  $ErrorActionPreference = 'Stop'
  if ($found) {
    ($json | ConvertFrom-Json).assets | ForEach-Object { $existing[$_.name] = [long]$_.size }
  } elseif ($WhatIf) {
    Write-Host "would create release '$tag'"
  } else {
    Write-Host "creating release '$tag'"
    & $Gh release create $tag --repo $repo --title $titles[$tag][0] --notes $titles[$tag][1]
    if ($LASTEXITCODE -ne 0) { throw "cannot create release '$tag'" }
  }
  foreach ($asset in ($group.Group | Group-Object asset)) {
    $r = $asset.Group[0]
    if ($existing.ContainsKey($asset.Name) -and $existing[$asset.Name] -eq [long]$r.size) { continue }
    $file = Join-Path $Root ($r.path -replace '/', '\')
    if ((Split-Path $file -Leaf) -ne $asset.Name) {
      # gh names an asset after its file: stage a copy under the asset name.
      New-Item -ItemType Directory -Force $staging | Out-Null
      $staged = Join-Path $staging $asset.Name
      Copy-Item -LiteralPath $file -Destination $staged -Force
      $file = $staged
    }
    $mb = '{0:N1} MB' -f ([long]$r.size / 1MB)
    if ($WhatIf) { Write-Host "would upload $tag/$($asset.Name) ($mb)"; continue }
    Write-Host "uploading $tag/$($asset.Name) ($mb)"
    & $Gh release upload $tag $file --repo $repo --clobber
    if ($LASTEXITCODE -ne 0) { throw "upload failed: $tag/$($asset.Name)" }
  }
}
if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
Write-Host 'Done. Test: install.ps1 -Source GitHub -NoFallback -Swarm latest -AllModules -DownloadOnly -OutDir <empty folder>'
