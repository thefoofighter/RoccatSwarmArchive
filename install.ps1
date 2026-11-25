<#
.SYNOPSIS
  ROCCAT Swarm Archive installer: ROCCAT Swarm (v1), device modules, pre-Swarm drivers and
  add-ons, from GitHub, archive.org, MEGA, Turtle Beach's own servers or a local folder.

.DESCRIPTION
  Start it without parameters to get the menu.

  * Every file is checked against the SHA-256 in catalog.csv before use.
  * If a source fails or sends a different file, the script tries the next source
    (the one you chose first, then GitHub, archive.org, MEGA, Turtle Beach).
  * Files next to this script are used first and are not downloaded again. A folder made
    with "Download only" therefore works on a PC with no internet: copy it over and run
    install.ps1 from it.
  * Modules that are already installed at the same or a newer version are skipped
    (-Force reinstalls them).
  * The script asks for administrator rights only when it has work that needs them.

.EXAMPLE
  .\install.ps1                                       # menu
  .\install.ps1 -Auto                                 # Swarm (if missing) + modules for the connected devices
  .\install.ps1 -List                                 # status only; changes nothing
  .\install.ps1 -Modules kone-aimo-remastered,3098    # modules by name or USB PID
  .\install.ps1 -Swarm 1.9482 -Silent                 # a Swarm version (NSIS builds can run silently)
  .\install.ps1 -Driver kave-xtd-5-1-digital          # a pre-Swarm driver
  .\install.ps1 -Swarm latest -AllModules -DownloadOnly -OutDir E:\roccat   # for an offline PC
  .\install.ps1 -Source ArchiveOrg -Auto              # prefer archive.org
#>
[CmdletBinding()]
param(
  [ValidateSet('GitHub', 'ArchiveOrg', 'Mega', 'TurtleBeach', 'Local')][string]$Source = 'GitHub',
  [string]$LocalDir,            # folder with the archive's files (for -Source Local)
  [switch]$Auto,                # Swarm if missing + modules for the connected devices
  [string[]]$Modules,           # module names (catalog id) or USB PIDs
  [switch]$AllModules,
  [string]$Swarm,               # Swarm version, e.g. 1.9482, or "latest"
  [string[]]$Driver,            # pre-Swarm driver names (catalog id)
  [string[]]$Addon,             # add-on names (catalog id), e.g. talk-fx
  [switch]$Everything,          # with -DownloadOnly: every file in the catalog
  [switch]$DownloadOnly,        # download and verify only; install nothing
  [string]$OutDir,              # target folder for -DownloadOnly
  [switch]$List,
  [switch]$Force,               # reinstall modules that are already installed
  [switch]$Silent,              # run NSIS Swarm installers (1.9475 and later) silently
  [switch]$NoRestart,           # do not start Swarm after a module install
  [switch]$NoFallback,          # use only the chosen source
  [string]$SwarmDir,            # Swarm folder, if not found automatically
  [switch]$KeepOpen             # internal: keep the elevated window open at the end
)

# --- mirrors: edit these when a mirror moves ---------------------------------------------------
$Repo = 'thefoofighter/RoccatSwarmArchive'
$Mirrors = @{
  GitHub     = "https://github.com/$Repo/releases/download"        # + /<tag>/<asset>
  GitHubRaw  = "https://raw.githubusercontent.com/$Repo/main"      # catalog.csv, install.ps1
  ArchiveOrg = 'https://archive.org/download/roccat-swarm-archive'  # + /<path>
  Mega       = ''                                                   # https://mega.nz/folder/<id>#<key>
}

# --- started with "irm <url> | iex"? ------------------------------------------------------------
# Then there is no script file. Save the script to TEMP and run it as a file in this window:
# a file can ask for administrator rights, and its errors cannot close this PowerShell window.
# Nothing in this block may throw: the trap below covers the whole script.
if (-not $PSCommandPath) {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $bootFile = Join-Path $env:TEMP 'RoccatSwarmArchive-install.ps1'
    $bootSaved = $false
    foreach ($bootUrl in "$($Mirrors.GitHubRaw)/install.ps1", "$($Mirrors.ArchiveOrg)/install.ps1") {
      try {
        $bootClient = New-Object Net.WebClient
        $bootClient.Headers['User-Agent'] = 'RoccatSwarmArchive-installer/1.0'
        $bootClient.DownloadFile($bootUrl, $bootFile)
        $bootSaved = $true
        break
      } catch { Write-Host "Cannot download $bootUrl ($($_.Exception.Message))" -ForegroundColor DarkYellow }
    }
    if ($bootSaved) {
      $bootArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bootFile)
      foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) { if ($kv.Value.IsPresent) { $bootArgs += "-$($kv.Key)" }; continue }
        $value = @($kv.Value) -join ','
        if ('LocalDir', 'OutDir', 'SwarmDir' -contains $kv.Key) {
          $value = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $value))
        }
        $bootArgs += "-$($kv.Key)"
        $bootArgs += $value
      }
      & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @bootArgs
    } else {
      Write-Host 'Cannot download install.ps1 from any mirror. Download it by hand and run it.' -ForegroundColor Red
    }
  } catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  }
  return
}

$ErrorActionPreference = 'Stop'

# A trap covers the whole script, so everything it calls must be defined before any other code.
function Exit-Script([int]$Code = 0) {
  if ($KeepOpen) { Read-Host 'Press Enter to close' | Out-Null }
  exit $Code
}
trap {
  Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Exit-Script 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$SourceNames = [ordered]@{
  GitHub = 'GitHub'; ArchiveOrg = 'archive.org'; Mega = 'MEGA'
  TurtleBeach = 'Turtle Beach (official servers)'; Local = 'local folder'
}

$UserAgent = 'RoccatSwarmArchive-installer/1.0'
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$CacheDir = Join-Path $env:LOCALAPPDATA 'RoccatSwarmArchive\downloads'
$WorkDir = Join-Path $env:TEMP 'RoccatSwarmArchive'
$Interactive = -not ($Auto -or $Modules -or $AllModules -or $Swarm -or $Driver -or $Addon -or $Everything -or $List)

function Split-List($Values) {
  @($Values | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
$Modules = Split-List $Modules
$Driver = Split-List $Driver
$Addon = Split-List $Addon

# Absolute paths, so an elevated relaunch (which starts in System32) sees the same folders.
function Get-FullPath([string]$Path) {
  if (-not $Path) { return $Path }
  # Combine keeps $Path as is when it is already absolute.
  [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)).TrimEnd('\')
}
if ($LocalDir) { $LocalDir = Get-FullPath $LocalDir }
if ($OutDir) { $OutDir = Get-FullPath $OutDir }
if ($SwarmDir) { $SwarmDir = Get-FullPath $SwarmDir }

function Write-Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Write-Note([string]$Text) { Write-Host "   $Text" -ForegroundColor DarkYellow }

function Confirm-Step([string]$Question, [bool]$Default = $true) {
  if (-not $Interactive) { return ($Default -or [bool]$Force) }
  $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
  $a = (Read-Host "$Question $suffix").Trim().ToLower()
  if (-not $a) { return $Default }
  return ($a -eq 'y' -or $a -eq 'yes')
}

function Test-Admin {
  $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- downloads ----------------------------------------------------------------------------------
function Get-WebError($ErrorRecord) {
  $ex = $ErrorRecord.Exception
  while ($ex -and -not ($ex -is [Net.WebException])) { $ex = $ex.InnerException }
  if ($ex -and $ex.Response) { return "HTTP $([int]$ex.Response.StatusCode)" }
  if ($ex) { return [string]$ex.Status }
  return $ErrorRecord.Exception.Message
}

function Copy-Stream($In, [string]$Dest, [long]$Total, [string]$Label, $Transform) {
  $part = "$Dest.part"
  $out = [IO.File]::Create($part)
  $buf = New-Object byte[] (1MB)
  $done = 0L
  $clock = [Diagnostics.Stopwatch]::StartNew()
  $shown = -1000
  try {
    while (($n = $In.Read($buf, 0, $buf.Length)) -gt 0) {
      if ($Transform) { $Transform.Transform($buf, 0, $n) }
      $out.Write($buf, 0, $n)
      $done += $n
      if ($clock.ElapsedMilliseconds - $shown -ge 300) {
        $shown = $clock.ElapsedMilliseconds
        $speed = $done / 1MB / [math]::Max($clock.Elapsed.TotalSeconds, 0.001)
        $pct = if ($Total -gt 0) { [int][math]::Min(100, 100 * $done / $Total) } else { 0 }
        Write-Progress -Activity "Downloading $Label" -PercentComplete $pct `
          -Status ("{0:N1} of {1:N1} MB, {2:N1} MB/s" -f ($done / 1MB), ($Total / 1MB), $speed)
      }
    }
  } finally {
    $out.Dispose()
    $In.Dispose()
    Write-Progress -Activity "Downloading $Label" -Completed
  }
  if ($Total -gt 0 -and $done -ne $Total) {
    Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
    throw "download stopped after $done of $Total bytes"
  }
  Move-Item -LiteralPath $part -Destination $Dest -Force
}

function Save-Url([string]$Url, [string]$Dest, $Row, [switch]$FollowTextLink, $Transform) {
  $label = Split-Path $Dest -Leaf
  for ($hop = 0; $hop -lt 3; $hop++) {
    $req = [Net.HttpWebRequest]::Create($Url)
    $req.UserAgent = $UserAgent
    $req.Timeout = 30000
    $req.ReadWriteTimeout = 120000
    try { $resp = $req.GetResponse() } catch { throw "$(Get-WebError $_) for $Url" }
    try {
      $type = [string]$resp.ContentType
      # Turtle Beach's module endpoint answers with a one-line text body: the real file URL.
      if ($FollowTextLink -and $type -like 'text/*' -and $resp.ContentLength -lt 4096) {
        $reader = New-Object IO.StreamReader($resp.GetResponseStream())
        $body = $reader.ReadToEnd().Trim()
        if ($body -match '^https?://\S+$') { $Url = $body; continue }
        throw "the server sent a web page, not the file ($Url)"
      }
      if ($type -like 'text/html*') { throw "the server sent a web page, not the file ($Url)" }
      $total = if ($resp.ContentLength -gt 0) { $resp.ContentLength } elseif ($Row) { [long]$Row.size } else { 0 }
      Copy-Stream $resp.GetResponseStream() $Dest $total $label $Transform
      return
    } finally {
      $resp.Close()
    }
  }
  throw "too many link hops for $Url"
}

function ConvertTo-UrlPath([string]$Path) {
  (($Path -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

# --- MEGA (public folder link; files are AES-128-CTR encrypted, the key is in the link) ----------
$script:MegaFolder = $null
$script:MegaSeq = Get-Random -Minimum 100000 -Maximum 999999

function Initialize-AesCtr {
  if ('RoccatAesCtr' -as [type]) { return }
  Add-Type -TypeDefinition @'
using System;
using System.Security.Cryptography;
// AES-128-CTR with a 128-bit big-endian counter (MEGA: 8-byte nonce + 8-byte block index).
public sealed class RoccatAesCtr : IDisposable {
    private readonly Aes aes;
    private readonly ICryptoTransform enc;
    private readonly byte[] counter = new byte[16];
    private byte[] blocks = new byte[0];
    private byte[] stream = new byte[0];
    private int pos = 0, len = 0;
    public RoccatAesCtr(byte[] key, byte[] initialCounter) {
        if (key == null || key.Length != 16) throw new ArgumentException("key must be 16 bytes");
        if (initialCounter == null || initialCounter.Length != 16) throw new ArgumentException("counter must be 16 bytes");
        aes = Aes.Create();
        aes.Mode = CipherMode.ECB;
        aes.Padding = PaddingMode.None;
        aes.Key = key;
        enc = aes.CreateEncryptor();
        Buffer.BlockCopy(initialCounter, 0, counter, 0, 16);
    }
    public void Transform(byte[] buf, int offset, int count) {
        int i = offset, end = offset + count;
        while (i < end) {
            if (pos == len) Refill(end - i);
            int n = Math.Min(end - i, len - pos);
            for (int j = 0; j < n; j++) buf[i + j] ^= stream[pos + j];
            i += n; pos += n;
        }
    }
    private void Refill(int need) {
        int count = Math.Max(1, (need + 15) / 16), size = count * 16;
        if (blocks.Length < size) { blocks = new byte[size]; stream = new byte[size]; }
        for (int b = 0; b < count; b++) {
            Buffer.BlockCopy(counter, 0, blocks, b * 16, 16);
            for (int k = 15; k >= 0; k--) { if (++counter[k] != 0) break; }
        }
        enc.TransformBlock(blocks, 0, size, stream, 0);
        pos = 0; len = size;
    }
    public void Dispose() { enc.Dispose(); aes.Dispose(); }
}
'@
}

function ConvertFrom-Base64Url([string]$Text) {
  $s = $Text.Replace('-', '+').Replace('_', '/').Replace(',', '')
  switch ($s.Length % 4) { 2 { $s += '==' } 3 { $s += '=' } }
  , [Convert]::FromBase64String($s)
}

function Invoke-AesDecrypt([byte[]]$Key, [byte[]]$Data, [Security.Cryptography.CipherMode]$Mode) {
  $aes = [Security.Cryptography.Aes]::Create()
  try {
    $aes.Mode = $Mode
    $aes.Padding = [Security.Cryptography.PaddingMode]::None
    $aes.Key = $Key
    $aes.IV = New-Object byte[] 16
    $d = $aes.CreateDecryptor()
    try { , $d.TransformFinalBlock($Data, 0, $Data.Length) } finally { $d.Dispose() }
  } finally { $aes.Dispose() }
}

function Invoke-MegaApi([hashtable]$Request, [string]$Folder) {
  $url = "https://g.api.mega.co.nz/cs?id=$($script:MegaSeq)"
  $script:MegaSeq++
  if ($Folder) { $url += "&n=$Folder" }
  $body = ConvertTo-Json -InputObject @($Request) -Compress
  for ($try = 0; $try -lt 6; $try++) {
    $raw = (Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType 'application/json' `
        -UserAgent $UserAgent -UseBasicParsing).Content
    if ($raw -is [byte[]]) { $raw = [Text.Encoding]::UTF8.GetString($raw) }
    $raw = $raw.Trim()
    $code = $null
    if ($raw -match '^\[?(-\d+)\]?$') { $code = [int]$Matches[1] }
    else {
      $result = (ConvertFrom-Json $raw)[0]
      if ($result -is [int] -or $result -is [long]) { $code = [int]$result }
      elseif ($null -ne $result.e -and [int]$result.e -lt 0) { $code = [int]$result.e }
      else { return $result }
    }
    if ($code -eq -3 -or $code -eq -4) { Start-Sleep -Seconds ([int][math]::Pow(2, $try)); continue }
    $why = @{ '-2' = 'bad request'; '-9' = 'not found'; '-11' = 'access denied'; '-16' = 'blocked (taken down)'
              '-17' = 'transfer quota used up, try later'; '-18' = 'temporarily unavailable' }["$code"]
    throw "MEGA error $code$(if ($why) { " ($why)" })"
  }
  throw 'MEGA is busy; try again later'
}

function Read-MegaAttributes([string]$Attr, [byte[]]$Key) {
  try {
    $data = ConvertFrom-Base64Url $Attr
    if ($data.Length -eq 0 -or $data.Length % 16) { return $null }
    $plain = [Text.Encoding]::UTF8.GetString((Invoke-AesDecrypt $Key $data 'CBC'))
    if (-not $plain.StartsWith('MEGA{')) { return $null }
    return ConvertFrom-Json ($plain.Substring(4).TrimEnd([char]0))
  } catch { return $null }
}

function Get-MegaFolder {
  if ($script:MegaFolder) { return $script:MegaFolder }
  if (-not $Mirrors.Mega) { throw 'no MEGA folder link is set in this script' }
  if ($Mirrors.Mega -notmatch 'mega(?:\.co)?\.nz/(?:folder/|#F!)([A-Za-z0-9_-]+)[#!]([A-Za-z0-9_,-]+)') {
    throw "not a MEGA folder link: $($Mirrors.Mega)"
  }
  $handle = $Matches[1]
  $shareKey = ConvertFrom-Base64Url $Matches[2]
  if ($shareKey.Length -ne 16) { throw 'the MEGA folder key is not 16 bytes' }
  $resp = Invoke-MegaApi @{ a = 'f'; c = 1; ca = 1; r = 1 } $handle
  $nodes = @{}
  foreach ($n in $resp.f) {
    if (-not $n.k) { continue }
    foreach ($entry in ([string]$n.k -split '/')) {
      $kv = $entry -split ':', 2
      if ($kv.Count -ne 2) { continue }
      try { $enc = ConvertFrom-Base64Url $kv[1] } catch { continue }
      if ($enc.Length -ne 16 -and $enc.Length -ne 32) { continue }
      $raw = Invoke-AesDecrypt $shareKey $enc 'ECB'
      $fileKey = $null
      if ([int]$n.t -eq 0) {
        if ($raw.Length -ne 32) { continue }
        # File key: AES key = first half XOR second half; CTR nonce = bytes 16..23.
        $key = New-Object byte[] 16
        for ($i = 0; $i -lt 16; $i++) { $key[$i] = $raw[$i] -bxor $raw[$i + 16] }
        $iv = New-Object byte[] 16
        [Array]::Copy($raw, 16, $iv, 0, 8)
        $fileKey = @{ Key = $key; Iv = $iv }
        $attrKey = $key
      } else {
        $attrKey = $raw
      }
      $attrs = Read-MegaAttributes $n.a $attrKey
      if (-not $attrs) { continue }
      $nodes[[string]$n.h] = [pscustomobject]@{ Handle = [string]$n.h; Parent = [string]$n.p; Type = [int]$n.t
        Name = [string]$attrs.n; Size = [long]$n.s; FileKey = $fileKey; Path = '' }
      break
    }
  }
  foreach ($node in $nodes.Values) {
    $parts = @()
    $cur = $node
    for ($depth = 0; $cur -and $depth -lt 64; $depth++) {
      $parts = @($cur.Name) + $parts
      $cur = if ($cur.Parent -and $nodes.ContainsKey($cur.Parent)) { $nodes[$cur.Parent] } else { $null }
    }
    $node.Path = $parts -join '/'
  }
  $script:MegaFolder = [pscustomobject]@{ Handle = $handle; Files = @($nodes.Values | Where-Object { $_.Type -eq 0 }) }
  return $script:MegaFolder
}

function Save-MegaFile([string]$Path, [string]$Dest, $Row) {
  Initialize-AesCtr
  $folder = Get-MegaFolder
  # The folder may be the archive root or a folder above it: match the path's end.
  $hit = $folder.Files | Where-Object { $_.Path -eq $Path -or $_.Path.EndsWith("/$Path") } | Select-Object -First 1
  if (-not $hit) {
    $name = ($Path -split '/')[-1]
    $byName = @($folder.Files | Where-Object { $_.Name -eq $name -and (-not $Row -or $_.Size -eq [long]$Row.size) })
    if ($byName.Count -eq 1) { $hit = $byName[0] }
  }
  if (-not $hit) { throw "not in the MEGA folder: $Path" }
  $g = Invoke-MegaApi @{ a = 'g'; g = 1; n = $hit.Handle; ssl = 2 } $folder.Handle
  if (-not $g.g) { throw 'MEGA sent no download link' }
  $ctr = New-Object RoccatAesCtr -ArgumentList $hit.FileKey.Key, $hit.FileKey.Iv
  try { Save-Url ([string]$g.g) $Dest $Row -Transform $ctr } finally { $ctr.Dispose() }
}

# --- sources and the catalog --------------------------------------------------------------------
function Get-SourceOrder {
  $online = @('GitHub', 'ArchiveOrg', 'Mega', 'TurtleBeach') | Where-Object { $_ -ne 'Mega' -or $Mirrors.Mega }
  if ($script:Source -eq 'Local') {
    if ($NoFallback) { return @() }
    return @($online)
  }
  if ($NoFallback) { return @($script:Source) }
  return @($script:Source) + @($online | Where-Object { $_ -ne $script:Source })
}

function Import-Catalog {
  $files = @(Join-Path $ScriptDir 'catalog.csv')
  if ($LocalDir) { $files += Join-Path $LocalDir 'catalog.csv' }
  foreach ($f in $files) {
    if (Test-Path -LiteralPath $f) { return @{ Rows = @(Import-Csv -LiteralPath $f); From = $f } }
  }
  New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
  $dest = Join-Path $CacheDir 'catalog.csv'
  # The catalog is only an index: any mirror will do, even with -NoFallback.
  $order = @($script:Source) + @('GitHub', 'ArchiveOrg', 'Mega') | Where-Object { $_ -ne 'Mega' -or $Mirrors.Mega } | Select-Object -Unique
  foreach ($src in $order) {
    try {
      if ($src -eq 'GitHub') { Save-Url "$($Mirrors.GitHubRaw)/catalog.csv" $dest $null }
      elseif ($src -eq 'ArchiveOrg') { Save-Url "$($Mirrors.ArchiveOrg)/catalog.csv" $dest $null }
      elseif ($src -eq 'Mega') { Save-MegaFile 'catalog.csv' $dest $null }
      else { continue }
      return @{ Rows = @(Import-Csv -LiteralPath $dest); From = $SourceNames[$src] }
    } catch {
      Write-Note "catalog from $($SourceNames[$src]) failed: $($_.Exception.Message)"
    }
  }
  if (Test-Path -LiteralPath $dest) {
    Write-Note 'using the catalog saved by an earlier run'
    return @{ Rows = @(Import-Csv -LiteralPath $dest); From = $dest }
  }
  throw 'cannot load catalog.csv from any source. Check the internet connection, or run this script from a folder that holds catalog.csv.'
}

function Test-FileHash([string]$Path, $Row) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  if ((Get-Item -LiteralPath $Path).Length -ne [long]$Row.size) { return $false }
  return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $Row.sha256.ToUpper())
}

function Get-ArchiveFile($Row, [string]$DestRoot) {
  # Returns the path of a verified copy of $Row. Downloads keep the archive's folder layout.
  $rel = $Row.path -replace '/', '\'
  $dest = Join-Path $DestRoot $rel
  $local = @($ScriptDir, $LocalDir, $OutDir, $CacheDir) | Where-Object { $_ } | ForEach-Object { Join-Path $_ $rel }
  foreach ($c in ($local | Select-Object -Unique)) {
    if (Test-FileHash $c $Row) {
      if ($c -ne $dest -and $DestRoot -ne $CacheDir) {
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -LiteralPath $c -Destination $dest -Force
        Write-Host "   copied $(Split-Path $dest -Leaf) from $(Split-Path $c) (SHA-256 OK)"
        return $dest
      }
      Write-Host "   using local $(Split-Path $c -Leaf) (SHA-256 OK)"
      return $c
    }
  }
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  $errors = @()
  foreach ($src in (Get-SourceOrder)) {
    try {
      if ($src -eq 'GitHub') { Save-Url "$($Mirrors.GitHub)/$($Row.tag)/$($Row.asset)" $dest $Row }
      elseif ($src -eq 'ArchiveOrg') { Save-Url "$($Mirrors.ArchiveOrg)/$(ConvertTo-UrlPath $Row.path)" $dest $Row }
      elseif ($src -eq 'Mega') { Save-MegaFile $Row.path $dest $Row }
      elseif ($src -eq 'TurtleBeach') {
        if (-not $Row.official_url) { continue }
        Save-Url $Row.official_url $dest $Row -FollowTextLink
      }
      if (Test-FileHash $dest $Row) {
        Write-Host "   got $(Split-Path $dest -Leaf) from $($SourceNames[$src]) (SHA-256 OK)"
        return $dest
      }
      Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
      $errors += "$($SourceNames[$src]): SHA-256 does not match"
    } catch {
      $errors += "$($SourceNames[$src]): $($_.Exception.Message)"
    }
  }
  if (-not $errors) { $errors = @('no source is allowed (-Source Local -NoFallback) and the file is not in the local folder') }
  throw "cannot get $($Row.path). $($errors -join '; ')"
}

# --- Swarm, devices, modules --------------------------------------------------------------------
function Get-SwarmEntry {
  $keys = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  Get-ItemProperty $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match '^ROCCAT SWARM' -and $_.DisplayName -notmatch '\bII\b' } | Select-Object -First 1
}

function Get-InstalledSwarmDir($Entry) {
  # The registered install folder (ignores -SwarmDir).
  if ($Entry -and $Entry.InstallLocation -and (Test-Path (Join-Path $Entry.InstallLocation 'ROCCAT_Swarm.exe'))) {
    return $Entry.InstallLocation.TrimEnd('\')
  }
  $d = Join-Path ${env:ProgramFiles(x86)} 'ROCCAT\ROCCAT Swarm'
  if (Test-Path (Join-Path $d 'ROCCAT_Swarm.exe')) { return $d }
  return $null
}

function Get-SwarmInfo {
  $entry = Get-SwarmEntry
  if ($SwarmDir) {
    if (-not (Test-Path (Join-Path $SwarmDir 'ROCCAT_Swarm.exe'))) { throw "no ROCCAT_Swarm.exe in -SwarmDir '$SwarmDir'" }
    $dir = $SwarmDir
  } else {
    $dir = Get-InstalledSwarmDir $entry
  }
  $ver = $null
  if ($entry -and $entry.DisplayVersion -and -not $SwarmDir) {
    $v = [string]$entry.DisplayVersion          # NSIS builds: "19482" = 1.9482
    if ($v -match '^(\d)(\d{4})$') { $ver = "$($Matches[1]).$($Matches[2])" }
    elseif ($v -match '^(\d+\.\d+)') { $ver = $Matches[1] }
  }
  $kind = $null
  if ($entry) { $kind = if ([string]$entry.UninstallString -match 'uninst\.exe') { 'nsis' } else { 'installshield' } }
  [pscustomobject]@{ Dir = $dir; Version = $ver; Installer = $kind }
}

function Get-RoccatPids {
  $ids = @()
  try {
    $ids = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | ForEach-Object { $_.InstanceId })
  } catch {
    $ids = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | ForEach-Object { $_.DeviceID })
  }
  @($ids | Where-Object { $_ -match 'VID_1E7D&PID_([0-9A-F]{4})' } |
    ForEach-Object { ($_ -replace '.*VID_1E7D&PID_([0-9A-F]{4}).*', '$1').ToUpper() } | Sort-Object -Unique)
}

function Get-IniVersion([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $m = Select-String -LiteralPath $Path -Pattern '^\s*version\s*=\s*(\d+)' | Select-Object -First 1
  if ($m) { return [int]$m.Matches[0].Groups[1].Value }
  return $null
}

function Get-ModuleState($Row, $Info) {
  # installed / outdated / partial / missing, from data\<ALIAS>\version.ini in the Swarm folder.
  if (-not $Info.Dir) { return 'missing' }
  $states = @(foreach ($pair in ($Row.module_dirs -split ';')) {
    $alias, $want = $pair -split ':', 2
    $have = Get-IniVersion (Join-Path $Info.Dir "data\$alias\version.ini")
    if ($null -eq $have) { 'missing' } elseif ($have -lt [int]$want) { 'outdated' } else { 'installed' }
  })
  if ($states -contains 'missing') {
    if (($states | Where-Object { $_ -ne 'missing' }).Count) { return 'partial' }
    return 'missing'
  }
  if ($states -contains 'outdated') { return 'outdated' }
  return 'installed'
}

function Find-SevenZip([string]$Dir) {
  $c = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")
  if ($Dir) { $c += Join-Path $Dir '7-Zip\7za.exe' }      # Swarm ships 7-Zip 9.38 (no RAR)
  $c | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Stop-Swarm {
  'ROCCAT_Swarm', 'ROCCAT_Swarm_Monitor', 'ROCCAT_dev_service', 'uac_agent' |
    ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 2
}

function Test-SwarmRunningFrom([string]$Dir) {
  if (-not $Dir) { return $false }
  $installed = Get-InstalledSwarmDir (Get-SwarmEntry)
  foreach ($p in @(Get-Process ROCCAT_Swarm, ROCCAT_Swarm_Monitor -ErrorAction SilentlyContinue)) {
    $path = $null
    try { $path = $p.Path } catch { }
    # An elevated Swarm hides its path from a normal user: assume the registered install folder.
    if (-not $path) { $path = if ($installed) { Join-Path $installed 'x' } else { '' } }
    if ($path.StartsWith($Dir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

function Test-Writable([string]$Dir) {
  try {
    $probe = Join-Path $Dir ('.write-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType File -Path $probe -ErrorAction Stop | Out-Null
    Remove-Item -LiteralPath $probe -Force
    return $true
  } catch { return $false }
}

function Expand-ArchiveFile([string]$File, [string]$Dest, [string]$SwarmFolder) {
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  if ($File -like '*.zip') { Expand-Archive -LiteralPath $File -DestinationPath $Dest -Force; return }
  $7z = Find-SevenZip $SwarmFolder
  if ($7z) {
    & $7z x -y "-o$Dest" $File | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
  }
  $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
  if (Test-Path $tar) {
    & $tar -xf $File -C $Dest
    if ($LASTEXITCODE -eq 0) { return }
  }
  throw "cannot unpack $(Split-Path $File -Leaf). Install 7-Zip (https://www.7-zip.org) and try again, or unpack it yourself."
}

function Find-Setup([string]$Dir) {
  $all = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Include *.exe, *.msi)
  if (-not $all) { return $null }
  $depth = { ($_.FullName.Substring($Dir.Length) -split '\\').Count }
  $min = ($all | ForEach-Object $depth | Measure-Object -Minimum).Minimum
  $top = @($all | Where-Object { (& $depth) -eq $min })
  $setup = $top | Where-Object { $_.Name -match '^setup\.(exe|msi)$' } | Select-Object -First 1
  if ($setup) { return $setup.FullName }
  ($top | Sort-Object Length -Descending | Select-Object -First 1).FullName
}

function Start-Installer([string]$Exe, [string[]]$Arguments) {
  Write-Host "   starting $(Split-Path $Exe -Leaf)$(if ($Arguments) { ' ' + ($Arguments -join ' ') } else { ' (follow its window)' })"
  $p = if ($Arguments) { Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory (Split-Path $Exe) -Wait -PassThru }
       else { Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -Wait -PassThru }
  return $p.ExitCode
}

# --- catalog lookups ------------------------------------------------------------------------------
function Get-Rows([string]$Kind) { @($script:Catalog | Where-Object { $_.kind -eq $Kind }) }

function Get-LatestSwarm { Get-Rows 'swarm' | Sort-Object { [double]$_.version } -Descending | Select-Object -First 1 }

function Resolve-Swarm([string]$Name) {
  if ($Name -eq 'latest') { return Get-LatestSwarm }
  $v = $Name -replace '^swarm-', ''
  $row = Get-Rows 'swarm' | Where-Object { $_.version -eq $v } | Select-Object -First 1
  if (-not $row) { throw "no Swarm $v in the catalog. Known: $((Get-Rows 'swarm').version -join ', ')" }
  $row
}

function Resolve-Items([string]$Kind, [string[]]$Names) {
  $rows = Get-Rows $Kind
  foreach ($n in $Names) {
    $hit = @($rows | Where-Object { $_.id -eq $n })
    if (-not $hit -and $Kind -eq 'module' -and $n -match '^[0-9A-Fa-f]{4}$') {
      $hit = @($rows | Where-Object { ($_.pids -split '\s+') -contains $n.ToUpper() })
    }
    if (-not $hit) { $hit = @($rows | Where-Object { $_.name -eq $n }) }
    if (-not $hit) { throw "unknown $Kind '$n'. Run with -List, or see catalog.csv for the names." }
    $hit[0]
  }
}

function Get-DeviceModules([string[]]$Pids) {
  # -> @{ Rows = module rows for the PIDs; Notes = PIDs with no module }
  $rows = @()
  $notes = @()
  foreach ($p in $Pids) {
    $m = Get-Rows 'module' | Where-Object { ($_.pids -split '\s+') -contains $p } | Select-Object -First 1
    if ($m) { if (-not ($rows | Where-Object { $_.id -eq $m.id })) { $rows += $m } }
    elseif ($p -match '^(A2|50|00B)') { $notes += "PID ${p}: firmware-update mode. Unplug the device and plug it in again." }
    else { $notes += "PID ${p}: no Swarm module. Older devices use a standalone driver (menu 4, or -Driver)." }
  }
  @{ Rows = $rows; Notes = $notes }
}

# --- actions --------------------------------------------------------------------------------------
function Install-SwarmBuild($Row) {
  $info = Get-SwarmInfo
  if ($info.Dir -and $info.Version -eq $Row.version -and -not $Force) {
    Write-Host "   Swarm $($Row.version) is already installed."
    return
  }
  if ($info.Dir) {
    Write-Note "Swarm $(if ($info.Version) { $info.Version } else { '(unknown version)' }) is installed in $($info.Dir)."
    if ($info.Installer -and $info.Installer -ne $Row.installer) {
      Write-Note 'It uses a different installer type. Uninstall it first (Settings > Apps > ROCCAT SWARM).'
    }
    if (-not (Confirm-Step "Install Swarm $($Row.version) over it?" $false)) { Write-Host '   skipped'; return }
  }
  $file = Get-ArchiveFile $Row $CacheDir
  $tmp = Join-Path $WorkDir "swarm-$($Row.version)"
  Expand-ArchiveFile $file $tmp $null
  $exe = Find-Setup $tmp
  if (-not $exe) { throw "no installer inside $(Split-Path $file -Leaf)" }
  Stop-Swarm
  $silentArgs = if ($Silent -and $Row.installer -eq 'nsis') { @('/S') } else { $null }
  if ($Silent -and -not $silentArgs) { Write-Note "Swarm $($Row.version) uses InstallShield: no silent mode, follow its window." }
  $code = Start-Installer $exe $silentArgs
  if ($code -ne 0) { throw "the Swarm installer ended with code $code (cancelled or failed)" }
  if (-not (Get-SwarmInfo).Dir) { throw 'Swarm is still not found after the installer finished. Pass -SwarmDir.' }
  Write-Host "   Swarm $($Row.version) installed." -ForegroundColor Green
}

function Install-ModuleSet($Rows) {
  $info = Get-SwarmInfo
  if (-not $info.Dir) {
    $latest = Get-LatestSwarm
    Write-Note "Swarm is not installed. Installing Swarm $($latest.version) first."
    Install-SwarmBuild $latest
    $info = Get-SwarmInfo
  }
  $todo = @()
  foreach ($r in $Rows) {
    $state = Get-ModuleState $r $info
    $go = $Force -or $state -ne 'installed'
    Write-Host ("   {0,-30} {1,-10} {2}" -f $r.name, $state, $(if ($go) { 'INSTALL' } else { 'skip' }))
    if ($go) { $todo += $r }
  }
  if (-not $todo) { Write-Host '   Nothing to do: every selected module is installed (-Force reinstalls).'; return }

  $files = @(foreach ($r in $todo) { @{ Row = $r; File = (Get-ArchiveFile $r $CacheDir) } })
  $7z = Find-SevenZip $info.Dir
  if (-not $7z) { throw 'no 7-Zip found (Swarm ships one in its 7-Zip folder). Install 7-Zip from https://www.7-zip.org.' }
  $wasRunning = Test-SwarmRunningFrom $info.Dir
  if ($wasRunning) { Stop-Swarm }
  $failed = @()
  foreach ($f in $files) {
    & $7z x -y "-o$($info.Dir)" $f.File | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed += "$($f.Row.name) (7-Zip exit code $LASTEXITCODE)"; continue }
    if ((Get-ModuleState $f.Row $info) -ne 'installed') { $failed += "$($f.Row.name) (version.ini check failed)"; continue }
    Write-Host "   installed $($f.Row.name) $($f.Row.version)" -ForegroundColor Green
  }
  if (($wasRunning -or -not $SwarmDir) -and -not $NoRestart) {
    Start-Process (Join-Path $info.Dir 'ROCCAT_Swarm.exe') | Out-Null
    Write-Host '   Swarm started.'
  }
  if ($failed) { throw "failed: $($failed -join '; ')" }
}

function Install-Standalone($Row) {
  # Pre-Swarm drivers and add-ons: unpack and start their own setup program.
  $file = Get-ArchiveFile $Row $CacheDir
  $tmp = Join-Path $WorkDir $Row.id
  Expand-ArchiveFile $file $tmp (Get-SwarmInfo).Dir
  $exe = Find-Setup $tmp
  if (-not $exe) {
    Write-Note "no setup program inside. The files are in $tmp"
    Start-Process explorer.exe $tmp
    return
  }
  $code = Start-Installer $exe $null
  Write-Host "   $($Row.name) setup finished (exit code $code)."
}

function Save-ForOffline($Rows, [string]$Dir) {
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  $mb = [math]::Round((($Rows | Measure-Object -Property size -Sum).Sum) / 1MB)
  Write-Host "   $(@($Rows).Count) file(s), $mb MB -> $Dir"
  foreach ($r in $Rows) { Get-ArchiveFile $r $Dir | Out-Null }
  $script:Catalog | Export-Csv -LiteralPath (Join-Path $Dir 'catalog.csv') -NoTypeInformation -Encoding UTF8
  if ($PSCommandPath -and ((Split-Path $PSCommandPath) -ne $Dir)) { Copy-Item -LiteralPath $PSCommandPath -Destination $Dir -Force }
  Write-Host "   Done. Copy '$Dir' to the other PC and run install.ps1 from it (no internet needed)." -ForegroundColor Green
}

# --- status and menu ------------------------------------------------------------------------------
function Show-Status {
  $info = Get-SwarmInfo
  $pids = Get-RoccatPids
  Write-Host ''
  Write-Host 'ROCCAT Swarm Archive installer' -ForegroundColor Cyan
  Write-Host ("Source:   {0}{1}" -f $SourceNames[$script:Source], $(if ($NoFallback) { ' only' } else { ' (falls back to the others)' }))
  if ($info.Dir) { Write-Host "Swarm:    $(if ($info.Version) { $info.Version } else { 'installed' }) in $($info.Dir)" }
  else { Write-Host 'Swarm:    not installed' -ForegroundColor Yellow }
  if (-not $pids) { Write-Host 'Devices:  no ROCCAT USB device found (VID 1E7D)' }
  $plan = Get-DeviceModules $pids
  foreach ($r in $plan.Rows) {
    Write-Host ("Device:   {0,-30} module {1} ({2})" -f $r.name, $r.version, (Get-ModuleState $r $info))
  }
  foreach ($n in $plan.Notes) { Write-Host "Device:   $n" }
}

function Select-Items($Rows, [scriptblock]$Label, [string]$What) {
  $shown = @($Rows)
  while ($true) {
    Write-Host ''
    for ($i = 0; $i -lt $shown.Count; $i++) { Write-Host ("{0,4}) {1}" -f ($i + 1), (& $Label $shown[$i])) }
    $in = (Read-Host "Pick $What (e.g. 1,3,5-7), type a word to filter, or press Enter to go back").Trim()
    if (-not $in) { return @() }
    if ($in -eq '*' -or $in -eq 'all') { return $shown }
    if ($in -match '^[\d,\s-]+$') {
      $idx = @()
      foreach ($part in ($in -split ',')) {
        $part = $part.Trim()
        if ($part -match '^(\d+)-(\d+)$') { $idx += [int]$Matches[1]..[int]$Matches[2] }
        elseif ($part -match '^\d+$') { $idx += [int]$part }
      }
      $idx = @($idx | Where-Object { $_ -ge 1 -and $_ -le $shown.Count } | Sort-Object -Unique)
      if ($idx) { return @($idx | ForEach-Object { $shown[$_ - 1] }) }
      Write-Host 'No valid number.'
      continue
    }
    $filtered = @($Rows | Where-Object { (& $Label $_) -like "*$in*" })
    if ($filtered) { $shown = $filtered } else { Write-Host "No match for '$in'."; $shown = @($Rows) }
  }
}

$script:ListInfo = $null    # Swarm info for one list display (Select-Modules sets it)
function Format-Module($r) {
  $info = if ($script:ListInfo) { $script:ListInfo } else { Get-SwarmInfo }
  "{0,-30} {1,-7} PID {2,-15} {3}" -f $r.name, $r.version, $r.pids, (Get-ModuleState $r $info)
}
function Select-Modules {
  $script:ListInfo = Get-SwarmInfo
  try { Select-Items (Get-Rows 'module') ${function:Format-Module} 'modules' } finally { $script:ListInfo = $null }
}
function Format-Swarm($r) {
  "Swarm {0,-7} {1,-14} {2,7:N0} MB  {3}" -f $r.version, $r.installer, ([long]$r.size / 1MB), $r.note
}
function Format-Other($r) {
  "{0,-40} {1,-7} {2}" -f $r.name, $r.version, $r.note
}

function Invoke-QuickSetup([switch]$Download, [string]$Dir) {
  $pids = Get-RoccatPids
  $plan = Get-DeviceModules $pids
  foreach ($n in $plan.Notes) { Write-Note $n }
  if (-not $plan.Rows) { Write-Host '   No connected device has a Swarm module.' }
  if ($Download) {
    Save-ForOffline (@(Get-LatestSwarm) + $plan.Rows) $Dir
    return
  }
  if (-not (Get-SwarmInfo).Dir) { Install-SwarmBuild (Get-LatestSwarm) }
  if ($plan.Rows) { Install-ModuleSet $plan.Rows }
}

function Read-Folder([string]$Default) {
  $in = (Read-Host "Folder [$Default]").Trim().Trim('"')
  if ($in) { Get-FullPath $in } else { $Default }
}

function Show-Menu {
  while ($true) {
    Show-Status
    Write-Host ''
    Write-Host '  1  Quick setup: Swarm (if missing) + modules for the connected devices'
    Write-Host '  2  Install device modules (pick from the list)'
    Write-Host '  3  Install a Swarm version'
    Write-Host '  4  Install a standalone driver (devices Swarm never supported, e.g. Kave XTD)'
    Write-Host '  5  Install an add-on (Talk FX)'
    Write-Host '  6  Download only, for a PC with no internet'
    Write-Host '  7  Change the download source'
    Write-Host '  Q  Quit'
    $choice = (Read-Host 'Choose').Trim().ToUpper()
    if ($choice -eq 'Q' -or $choice -eq 'QUIT') { return }
    try {
      if ($choice -eq '1') { Write-Step 'Quick setup'; Invoke-QuickSetup }
      elseif ($choice -eq '2') {
        $sel = Select-Modules
        if ($sel) { Write-Step 'Device modules'; Install-ModuleSet $sel }
      } elseif ($choice -eq '3') {
        Write-Note 'Swarm 1.9482 is the newest build and the one tested with these modules.'
        $sel = Select-Items (Get-Rows 'swarm') ${function:Format-Swarm} 'one Swarm version'
        if ($sel) {
          if ($sel[0].installer -eq 'nsis' -and -not $Silent) { $script:Silent = Confirm-Step 'Install silently (no installer window)?' $false }
          Write-Step "Swarm $($sel[0].version)"; Install-SwarmBuild $sel[0]
        }
      } elseif ($choice -eq '4' -or $choice -eq '5') {
        $kind = if ($choice -eq '4') { 'driver' } else { 'addon' }
        $sel = Select-Items (Get-Rows $kind) ${function:Format-Other} "one $kind"
        if ($sel) { Write-Step $sel[0].name; Install-Standalone $sel[0] }
      } elseif ($choice -eq '6') { Show-DownloadMenu }
      elseif ($choice -eq '7') { Show-SourceMenu }
      else { Write-Host 'Unknown choice.' }
    } catch {
      Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host 'Press Enter to go back to the menu' | Out-Null
  }
}

function Show-DownloadMenu {
  $modulesMb = [math]::Round(((Get-Rows 'module' | Measure-Object size -Sum).Sum + [long](Get-LatestSwarm).size) / 1MB)
  $allMb = [math]::Round((($script:Catalog | Measure-Object size -Sum).Sum) / 1MB)
  Write-Host ''
  Write-Host "  1  Swarm $((Get-LatestSwarm).version) + every device module ($modulesMb MB)"
  Write-Host '  2  Swarm + modules for the devices connected to THIS PC'
  Write-Host '  3  Pick modules'
  Write-Host '  4  Pick Swarm versions, drivers, add-ons or extras'
  Write-Host "  5  Everything in the archive ($allMb MB)"
  $c = (Read-Host 'Choose (Enter to go back)').Trim()
  if (-not $c) { return }
  $rows = @()
  if ($c -eq '1') { $rows = @(Get-LatestSwarm) + (Get-Rows 'module') }
  elseif ($c -eq '2') { $rows = @(Get-LatestSwarm) + (Get-DeviceModules (Get-RoccatPids)).Rows }
  elseif ($c -eq '3') { $rows = Select-Modules }
  elseif ($c -eq '4') {
    $other = @($script:Catalog | Where-Object { $_.kind -ne 'module' })
    $rows = Select-Items $other { param($r) "{0,-7} {1}" -f $r.kind, $(if ($r.kind -eq 'swarm') { Format-Swarm $r } else { Format-Other $r }) } 'files'
  } elseif ($c -eq '5') { $rows = $script:Catalog }
  if (-not $rows) { return }
  $default = Join-Path ([Environment]::GetFolderPath('Desktop')) 'RoccatSwarmArchive-offline'
  $dir = Read-Folder $(if ($OutDir) { $OutDir } else { $default })
  Write-Step 'Download only'
  Save-ForOffline $rows $dir
}

function Show-SourceMenu {
  $keys = @($SourceNames.Keys)
  Write-Host ''
  for ($i = 0; $i -lt $keys.Count; $i++) {
    $extra = if ($keys[$i] -eq 'Mega' -and -not $Mirrors.Mega) { ' (no link set in this script yet)' } else { '' }
    Write-Host ("  {0}  {1}{2}" -f ($i + 1), $SourceNames[$keys[$i]], $extra)
  }
  $c = (Read-Host 'Choose (Enter to keep the current one)').Trim()
  if ($c -notmatch '^\d+$' -or [int]$c -lt 1 -or [int]$c -gt $keys.Count) { return }
  $pick = $keys[[int]$c - 1]
  if ($pick -eq 'Mega' -and -not $Mirrors.Mega) { Write-Host 'MEGA is not set up yet. Edit $Mirrors.Mega at the top of install.ps1.'; return }
  if ($pick -eq 'Local') {
    $d = Read-Folder $(if ($LocalDir) { $LocalDir } else { $ScriptDir })
    if (-not (Test-Path -LiteralPath $d)) { Write-Host "No folder '$d'."; return }
    $script:LocalDir = $d
  }
  $script:Source = $pick
}

# --- main -----------------------------------------------------------------------------------------
if ($Source -eq 'Mega' -and -not $Mirrors.Mega) { throw 'MEGA is not set up yet: $Mirrors.Mega at the top of the script is empty.' }
if ($Source -eq 'Local' -and -not $LocalDir) { $LocalDir = $ScriptDir }
if ($Everything -and -not $DownloadOnly) { throw '-Everything works only with -DownloadOnly.' }
if ($DownloadOnly -and -not $OutDir) { $OutDir = Join-Path ([Environment]::GetFolderPath('Desktop')) 'RoccatSwarmArchive-offline' }

$loaded = Import-Catalog
$script:Catalog = $loaded.Rows

if ($List) {
  Show-Status
  Write-Host ''
  Write-Host ("Catalog:  {0} files from {1}" -f $script:Catalog.Count, $loaded.From)
  foreach ($g in ($script:Catalog | Group-Object kind)) { Write-Host ("          {0,3} {1}" -f $g.Count, $g.Name) }
  Exit-Script 0
}

# Work out what to do before asking for administrator rights.
$swarmRow = if ($Swarm) { Resolve-Swarm $Swarm } else { $null }
$moduleRows = @()
if ($AllModules) { $moduleRows = Get-Rows 'module' }
elseif ($Modules) { $moduleRows = @(Resolve-Items 'module' $Modules) }
$driverRows = @(if ($Driver) { Resolve-Items 'driver' $Driver })
$addonRows = @(if ($Addon) { Resolve-Items 'addon' $Addon })
$autoPlan = $null
if ($Auto) {
  $autoPlan = Get-DeviceModules (Get-RoccatPids)
  $moduleRows = @($moduleRows) + @($autoPlan.Rows | Where-Object { $moduleRows.id -notcontains $_.id })
}

$needAdmin = $false
if ($Interactive) { $needAdmin = $true }
elseif (-not $DownloadOnly) {
  $info = Get-SwarmInfo
  $todoModules = @($moduleRows | Where-Object { $Force -or (Get-ModuleState $_ $info) -ne 'installed' })
  $swarmNeeded = $swarmRow -or ((-not $info.Dir) -and ($todoModules -or $Auto))
  if ($swarmNeeded -or $driverRows -or $addonRows) { $needAdmin = $true }
  elseif ($todoModules) {
    $needAdmin = (-not (Test-Writable $info.Dir)) -or (Test-SwarmRunningFrom $info.Dir)
  }
}

if ($needAdmin -and -not (Test-Admin)) {
  if (-not $PSCommandPath) { throw 'start PowerShell as administrator, then run the command again.' }
  $quote = { param($s) '"' + ([string]$s -replace '"', '\"') + '"' }
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (& $quote $PSCommandPath))
  $pathParams = 'LocalDir', 'OutDir', 'SwarmDir'
  foreach ($kv in $PSBoundParameters.GetEnumerator()) {
    if ($pathParams -contains $kv.Key) { continue }
    $v = $kv.Value
    if ($v -is [switch]) { if ($v.IsPresent) { $argList += "-$($kv.Key)" } }
    elseif ($v -is [array]) { $argList += "-$($kv.Key)"; $argList += (& $quote ($v -join ',')) }
    else { $argList += "-$($kv.Key)"; $argList += (& $quote $v) }
  }
  foreach ($name in $pathParams) {      # the absolute versions: the elevated window starts in System32
    $val = Get-Variable -Name $name -ValueOnly
    if ($val) { $argList += "-$name"; $argList += (& $quote $val) }
  }
  if (-not $Interactive -and -not $KeepOpen) { $argList += '-KeepOpen' }
  Write-Host 'Asking for administrator rights (needed to install)...'
  try {
    $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList ($argList -join ' ')
  } catch {
    throw 'administrator rights were refused. Without them, only -List and -DownloadOnly work.'
  }
  exit $p.ExitCode
}

if ($Interactive) { Show-Menu; Exit-Script 0 }

if ($DownloadOnly) {
  $rows = if ($Everything) { $script:Catalog } else {
    @(@($swarmRow) + $moduleRows + $driverRows + $addonRows | Where-Object { $_ })
  }
  if ($Auto -and -not $swarmRow) { $rows = @(Get-LatestSwarm) + $rows }
  if ($autoPlan) { foreach ($n in $autoPlan.Notes) { Write-Note $n } }
  if (-not $rows) { throw 'nothing selected to download. Add -Auto, -Swarm, -Modules, -AllModules, -Driver, -Addon or -Everything.' }
  Write-Step 'Download only'
  Save-ForOffline $rows $OutDir
  Exit-Script 0
}

if ($autoPlan) { foreach ($n in $autoPlan.Notes) { Write-Note $n } }
if ($swarmRow) { Write-Step "Swarm $($swarmRow.version)"; Install-SwarmBuild $swarmRow }
elseif ($Auto -and -not (Get-SwarmInfo).Dir) { Write-Step 'Swarm'; Install-SwarmBuild (Get-LatestSwarm) }
if ($moduleRows) { Write-Step 'Device modules'; Install-ModuleSet $moduleRows }
elseif ($Auto) { Write-Host '   No connected device has a Swarm module.' }
foreach ($r in @($driverRows) + @($addonRows)) { Write-Step $r.name; Install-Standalone $r }
Exit-Script 0
