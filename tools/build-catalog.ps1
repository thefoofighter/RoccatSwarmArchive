<#
.SYNOPSIS
  Maintainer tool: check catalog.csv against the files and fill in what can be computed.

.DESCRIPTION
  catalog.csv is the archive's index; install.ps1 reads it. You maintain these columns by
  hand: kind, id, name, version, pids, date, installer, path, official_url, note.
  This tool computes the rest:

    size, sha256   from the file at 'path'
    module_dirs    modules only: "ALIAS:version" for each data\<ALIAS>\version.ini inside
    tag            from kind (swarm -> swarm, module -> modules, driver -> drivers, else extras)
    asset          the GitHub release asset name, from the file name, if empty

  To add a file: put it in the folder for its function (swarm\<version>\, modules\<device>\,
  drivers\<device>\, addons\, sdk\, other\), keep the vendor's file name, add a row, and run
  this tool. Then publish it (tools\publish.ps1). Rows may share one file.

  The tool fails when a binary in those folders has no row, a row points to a missing
  file, an id repeats within a kind, or two different files get the same release asset.

.PARAMETER Check
  Change nothing. Exit 1 if catalog.csv is out of date.
#>
param(
  [string]$Root = (Split-Path $PSScriptRoot -Parent),
  [switch]$Check
)
$ErrorActionPreference = 'Stop'
Set-Location $Root

$ContentDirs = 'swarm', 'modules', 'drivers', 'addons', 'sdk', 'other'
$BinaryExt = '.zip', '.7z', '.rar', '.pkg', '.exe', '.msi'
$TagOf = @{ swarm = 'swarm'; module = 'modules'; driver = 'drivers'; addon = 'extras'; extra = 'extras' }
$KindOrder = @{ swarm = 0; module = 1; driver = 2; addon = 3; extra = 4 }

$sevenZip = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
  "${env:ProgramFiles(x86)}\ROCCAT\ROCCAT Swarm\7-Zip\7za.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1

function Get-ModuleDirs([string]$Archive) {
  if (-not $sevenZip) { throw 'needs 7-Zip (7z.exe) to read module archives' }
  $inis = & $sevenZip l -ba $Archive | ForEach-Object { ($_.Trim() -split '\s+')[-1] } |
    Where-Object { $_ -match '^data\\[^\\]+\\version\.ini$' }
  $out = foreach ($ini in $inis) {
    $text = (& $sevenZip e -so $Archive $ini) -join "`n"
    if ($text -notmatch '(?m)^\s*version\s*=\s*(\d+)') { throw "no version= in $ini of $Archive" }
    '{0}:{1}' -f ($ini -split '\\')[1], $Matches[1]
  }
  if (-not $out) { throw "no data\<ALIAS>\version.ini in $Archive" }
  ($out | Sort-Object) -join ';'
}

$catalogPath = Join-Path $Root 'catalog.csv'
$before = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($catalogPath))
$rows = @(Import-Csv $catalogPath)
$problems = New-Object System.Collections.Generic.List[string]
$hashes = @{}     # path -> @{ Size; Sha }

foreach ($r in $rows) {
  foreach ($col in 'kind', 'id', 'name', 'path') {
    if (-not $r.$col) { $problems.Add("row '$($r.id)': empty '$col'") }
  }
  if (-not $TagOf.ContainsKey($r.kind)) { $problems.Add("row '$($r.id)': unknown kind '$($r.kind)'"); continue }
  $file = Join-Path $Root ($r.path -replace '/', '\')
  if (-not (Test-Path -LiteralPath $file)) { $problems.Add("row '$($r.id)': no file at $($r.path)"); continue }
  if (-not $hashes.ContainsKey($r.path)) {
    $item = Get-Item -LiteralPath $file
    $hashes[$r.path] = @{ Size = [string]$item.Length; Sha = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() }
  }
  $r.size = $hashes[$r.path].Size
  $r.sha256 = $hashes[$r.path].Sha
  $r.tag = $TagOf[$r.kind]
  if (-not $r.asset) { $r.asset = (Split-Path $file -Leaf) -replace '[^A-Za-z0-9._-]', '.' }
  if ($r.asset -match '[^A-Za-z0-9._-]') { $problems.Add("row '$($r.id)': asset '$($r.asset)' has characters GitHub would change") }
  if ($r.kind -eq 'module') { $r.module_dirs = Get-ModuleDirs $file }
}

$listed = @{}
$rows | ForEach-Object { $listed[$_.path] = $true }
Get-ChildItem $ContentDirs -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $BinaryExt -contains $_.Extension.ToLower() } | ForEach-Object {
  $rel = $_.FullName.Substring($Root.Length + 1) -replace '\\', '/'
  if (-not $listed[$rel]) { $problems.Add("no catalog row for $rel") }
}
$rows | Group-Object kind, id | Where-Object { $_.Count -gt 1 } | ForEach-Object { $problems.Add("id used twice: $($_.Name)") }
$rows | Group-Object tag, asset | Where-Object { @($_.Group.sha256 | Sort-Object -Unique).Count -gt 1 } |
  ForEach-Object { $problems.Add("two different files share release asset $($_.Name)") }

if ($problems.Count) {
  $problems | ForEach-Object { Write-Host "PROBLEM: $_" -ForegroundColor Red }
  exit 1
}

$sorted = $rows | Sort-Object { $KindOrder[$_.kind] },
  @{ e = { if ($_.kind -eq 'swarm') { -[double]$_.version } else { 0 } } }, id
$csvText = (($sorted | ConvertTo-Csv -NoTypeInformation) -join "`r`n") + "`r`n"
# git may change line endings on checkout: compare without them.
$stale = ($csvText -replace "`r", '') -cne ($before -replace "`r", '')
if ($Check) {
  if ($stale) { Write-Host 'catalog.csv is out of date: run tools\build-catalog.ps1' -ForegroundColor Red; exit 1 }
  Write-Host 'catalog.csv is up to date.'
  exit 0
}
[IO.File]::WriteAllText($catalogPath, $csvText, (New-Object Text.UTF8Encoding($false)))
$mb = [math]::Round((($hashes.Values | ForEach-Object { [long]$_.Size } | Measure-Object -Sum).Sum) / 1MB)
Write-Host ("catalog.csv: {0} rows, {1} files, {2} MB{3}" -f $rows.Count, $hashes.Count, $mb, $(if ($stale) { ' - updated' } else { ' - no change' }))
