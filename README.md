<div align="center">

# ROCCAT Swarm Archive

**Keep ROCCAT Swarm working.**<br>
Every Swarm installer, all 55 device modules and the pre-Swarm drivers,<br>
with a one-line installer that needs no update server.

[![Windows 7 | 10 | 11](https://img.shields.io/badge/Windows-7%20%7C%2010%20%7C%2011-0078d4)](#requirements)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391fe)](#requirements)
[![Swarm builds](https://img.shields.io/badge/Swarm-24%20builds-c8102e)](#whats-in-the-archive)
[![Device modules](https://img.shields.io/badge/device%20modules-55-c8102e)](#supported-devices)
[![SHA-256 verified](https://img.shields.io/badge/files-SHA--256%20verified-2ea44f)](catalog.csv)

[Quick start](#quick-start) •
[Install by hand](#install-by-hand) •
[Downloads](https://github.com/thefoofighter/RoccatSwarmArchive/releases) •
[Supported devices](#supported-devices) •
[Troubleshooting](#troubleshooting)

</div>

---

> [!TIP]
> **Prefer to install by hand?** Every file is a direct download in the
> [Releases](https://github.com/thefoofighter/RoccatSwarmArchive/releases):
> [Swarm installers](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/swarm) ·
> [device modules](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/modules) ·
> [drivers](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/drivers) ·
> [add-ons and extras](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/extras).
> The steps are in [Install by hand](#install-by-hand).

## About

ROCCAT Swarm (v1) is the configuration software for ROCCAT mice, keyboards and headsets.
Turtle Beach no longer develops it. Swarm downloads a **device module** the first time you
connect a device, and without that module the device has no configuration page.

Swarm builds up to 1.9478 can no longer download modules: their update server is gone.
The last build, 1.9482, uses a Turtle Beach server that still answers, but nothing
promises that it stays online. This archive keeps all the files, so Swarm keeps working
with no update server at all.

## Features

- **One command.** It installs Swarm if it is missing, finds your ROCCAT devices, and
  installs only the modules they need.
- **No double work.** It skips modules that are already installed at the same or a newer
  version.
- **Verified files.** It checks every file against its SHA-256 before it uses it.
- **Four sources.** GitHub, archive.org, MEGA and Turtle Beach's own servers. When one
  source fails, the script uses the next one.
- **Offline installs.** Download the files once on any PC, then install on a PC with no
  internet.
- **Complete.** 24 Swarm builds (2015 to 2026), 55 device modules with their firmware, and
  drivers for 26 older devices that Swarm never supported.

## Quick start

> **Requirements:** Windows 10 or 11 and an account with administrator rights.
> Windows 7: see [Windows 7](#windows-7).

Open PowerShell (Start menu, type `powershell`, press Enter) and run:

```powershell
irm https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1 | iex
```

1. Click **Yes** in the Windows administrator prompt.
2. Select **1 Quick setup**.
3. If Swarm is not installed, its installer opens. Click through it and keep the default
   folder.

That is all. Swarm starts with a full configuration page for each connected device.

> [!TIP]
> **You connect a new device later?** Run the command again and select **1**. The script
> installs only the module for the new device.

<details>
<summary><b>Read the script before you run it</b></summary>
<br>

Download [`install.ps1`](https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1)
and read it. Then right-click it and select **Run with PowerShell**, or run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

</details>

## Using the installer

### Menu

| Option                        | What it does                                                                 |
| ----------------------------- | ---------------------------------------------------------------------------- |
| 1 Quick setup                 | Swarm (if missing) + the modules for the connected devices                   |
| 2 Install device modules      | Pick modules from a list, also for devices that are not connected            |
| 3 Install a Swarm version     | Any of the 24 archived builds. 1.9482 is the one to use                      |
| 4 Install a standalone driver | Drivers for devices that Swarm never supported, for example the Kave XTD 5.1 |
| 5 Install an add-on           | ROCCAT Talk FX                                                               |
| 6 Download only               | Save the files to a folder for a PC with no internet                         |
| 7 Change the download source  | GitHub, archive.org, MEGA, Turtle Beach's servers, or a local folder         |

### Command-line options

Add options to the one-line command like this:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1))) -Auto
```

| You want to                                                     | Option                                          |
| --------------------------------------------------------------- | ----------------------------------------------- |
| See what is installed and what the script finds (no changes)    | `-List`                                         |
| Run the quick setup with no menu                                | `-Auto`                                         |
| Install named modules (`id` from `catalog.csv`, or a USB PID)   | `-Modules kone-aimo-remastered,3098`            |
| Install every module                                            | `-AllModules`                                   |
| Install a Swarm build (`latest` = 1.9482) with no installer window | `-Swarm latest -Silent`                      |
| Install a standalone driver                                     | `-Driver kave-xtd-5-1-digital`                  |
| Prefer a source                                                 | `-Source ArchiveOrg` (or `Mega`, `TurtleBeach`) |
| Use only that source                                            | add `-NoFallback`                               |
| Reinstall modules that are already installed                    | add `-Force`                                    |

<details>
<summary><b>More options</b></summary>
<br>

| Option                             | What it does                                     |
| ---------------------------------- | ------------------------------------------------ |
| `-SwarmDir <folder>`               | Swarm is not in the default folder               |
| `-NoRestart`                       | Do not start Swarm after a module install        |
| `-Source Local -LocalDir <folder>` | Use a copy of the archive on disk                |
| `-DownloadOnly -OutDir <folder>`   | Download and check the files; install nothing    |
| `-Everything`                      | With `-DownloadOnly`: every file in the archive  |

With a downloaded copy of the script, use
`powershell -ExecutionPolicy Bypass -File install.ps1 <options>`.

</details>

### PCs with no internet

1. On a PC with internet, run the script and select **6 Download only**. Option 1 there
   saves Swarm 1.9482 and all 55 modules (about 400 MB).
2. Copy the folder to the other PC, for example on a USB drive. It holds the files,
   `catalog.csv` and `install.ps1`.
3. On the other PC, run `install.ps1` from that folder. The script uses the files next to
   it and downloads nothing.

### Windows 7

<a id="requirements"></a>

The script needs **Windows PowerShell 5.1**. Windows 10 and 11 have it. Windows 7 comes with
version 2.0, and the script then stops and tells you what to install.

<details>
<summary><b>Set up Windows 7 SP1</b></summary>
<br>

1. Install [.NET Framework 4.8](https://go.microsoft.com/fwlink/?linkid=2088631).
2. Install [Windows Management Framework 5.1](https://www.microsoft.com/download/details.aspx?id=54616)
   (`Win7AndW2K8R2-KB3191566-x64.zip`, or `-x86` for 32-bit Windows). Restart.
3. Windows 7 does not switch on TLS 1.2 by itself. Use this command instead of the `irm`
   one:

   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1'))
   ```

You can also skip the script: download the files on another PC (**6 Download only**),
copy them over, and [install by hand](#install-by-hand).

</details>

> [!NOTE]
> Swarm 1.9482 should run on Windows 7 SP1. It is built with Qt 5 and a bundled
> Visual C++ 2013 runtime, and it calls no Windows 8 or later functions. Nobody has tested
> it on Windows 7 yet. Older Swarm builds officially supported Windows 7.

## Install by hand

The manual install puts the same files in the same place as the script.

**1. Install Swarm.** Download
[`ROCCAT-Swarm_1.9482.zip`](https://github.com/thefoofighter/RoccatSwarmArchive/releases/download/swarm/ROCCAT-Swarm_1.9482.zip),
unzip it and run `ROCCAT Swarm_v19482.exe`. Keep the default folder,
`C:\Program Files (x86)\ROCCAT\ROCCAT Swarm\`. Swarm can start and show "no device" or
"downloading": that is normal. Close Swarm before the next step.

**2. Find the module for your device.** Find your device in [`catalog.csv`](catalog.csv)
(rows with `kind` = `module`). The `pids` column holds its USB product IDs, and `asset` is
the file name in the [modules release](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/modules).
To find your device's PID, connect it and run:

```powershell
Get-PnpDevice -PresentOnly | Where-Object InstanceId -match 'VID_1E7D' | Select-Object -ExpandProperty InstanceId -Unique
```

The `PID_XXXX` part is the PID. PIDs that start with `A2`, `50` or `00B` show the
firmware-update mode: disconnect the device, connect it again, and run the command again.
Optional: compare `Get-FileHash <file>` with the `sha256` column.

**3. Stop Swarm.** Right-click the Swarm icon in the notification area and select **Exit**.
Or end `ROCCAT_Swarm.exe`, `ROCCAT_Swarm_Monitor.exe` and `ROCCAT_dev_service.exe` in Task
Manager.

**4. Extract the module into the Swarm folder.** Open PowerShell **as administrator** in
the folder with the module file, and use the 7-Zip copy that comes with Swarm:

```powershell
& 'C:\Program Files (x86)\ROCCAT\ROCCAT Swarm\7-Zip\7za.exe' x -y '-oC:\Program Files (x86)\ROCCAT\ROCCAT Swarm' 'kone-aimo-remastered_207-1.0009-1.0009-8052-v1.7z'
```

Or right-click the `.7z` file in File Explorer, select **7-Zip > Extract files...**, and
set the Swarm folder itself as the target. The files must land like this:

```text
C:\Program Files (x86)\ROCCAT\ROCCAT Swarm\
  ROCCAT_Swarm.exe
  data\
    KONE_AIMO_16K\        <- from kone-aimo-remastered_....7z
      KONE_AIMO.dll       (the device plugin)
      firmware\           (firmware image + firmware_upgrade.ini)
      version.ini         <- when this file is here, the module is in the right place
```

The `module_dirs` column of `catalog.csv` shows the folder that each module creates.
Repeat this step for each device. A module for a device that is not connected does nothing
until you connect the device.

**5. Start Swarm.** Your device appears with its full configuration page.

<details>
<summary><b>Standalone drivers (devices that Swarm never supported)</b></summary>
<br>

Download the driver from the [drivers release](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/drivers),
unzip it, and run its `Setup.exe`. Example: the Kave XTD 5.1 Digital uses
`kave-xtd-5-1-digital_63-2.19-1.00-6127-v1.zip`, which holds
`ROCCAT_KaveXTD_DRV2.19\Setup.exe`. The Arvo, Pyra and Valo drivers are `.rar` files: open
them with [7-Zip](https://www.7-zip.org).

</details>

## Supported devices

**Swarm device modules (55).** Each module adds one device, or a device family, to Swarm.

| Type                     | Devices |
| ------------------------ | ------- |
| Mice (26)                | Burst Core · Burst Pro · Burst Pro Air · Kain 100 AIMO · Kain 120 AIMO · Kain 200 AIMO · Kiro · Kone AIMO · Kone AIMO Remastered · Kone Air · Kone EMP · Kone Pro · Kone Pro Air · Kone Pure Owl-Eye · Kone Pure SE · Kone Pure SEL · Kone Pure Ultra · Kone Pure Ultra iCafe · Kone XP · Kone XP Air · Kova · Kova AIMO · Leadr · Nyth · Pure Air · Pure SEL |
| Keyboards (22)           | Horde · Horde AIMO · Isku+ · Isku+ Force FX · Magma · Magma Mini · Pyro · Ryos MK FX · Skeltr · Sova · Suora · Suora FX · Vulcan 80 · Vulcan 100 AIMO · Vulcan 120/121/122 AIMO · Vulcan II · Vulcan II Max · Vulcan II Mini · Vulcan II Mini Air · Vulcan Pro · Vulcan TKL AIMO · Vulcan TKL Pro |
| Headsets and audio (6)   | Elo 7.1 Air · Elo 7.1 USB · Khan AIMO · Syn Max Air · Syn Pro Air · Torch (microphone) |
| Mousepads (1)            | Sense AIMO / XXL |

**Standalone drivers (26 devices).** For older devices that Swarm never supported.

| Type                     | Devices |
| ------------------------ | ------- |
| Mice (15)                | Kone (original) · Kone[+] · Kone Pure · Kone Pure Color · Kone Pure Military · Kone Pure Optical · Kone Pure Optical Black/White Edition · Kone XTD · Kone XTD Optical · Kova[+] · Lua · Pyra Wired · Pyra Wireless · Savu · Tyon |
| Keyboards (8)            | Arvo · Isku · Isku FX · Ryos MK · Ryos MK Glow · Ryos MK Pro · Ryos TKL Pro · Valo |
| Audio (3)                | Kave XTD 5.1 Digital · Kulo 7.1 USB · Juke (USB sound card) |

The archive also holds the Kone XTD driver for macOS, the only Mac driver known to exist.

## Which Swarm build?

Use **1.9482**, the last build. Builds up to 1.9478 point at ROCCAT's update server, which
is gone, so they cannot download anything. 1.9479 and later use Turtle Beach's server.
The offline module install was tested with 1.9482 only. The older builds are here for
preservation.

## Troubleshooting

| Problem                                                              | What to do                                                                                                                          |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| "running scripts is disabled on this system"                         | Use the `irm` command, or start a downloaded copy with `powershell -ExecutionPolicy Bypass -File install.ps1`.                       |
| "Could not create SSL/TLS secure channel" (Windows 7, old Windows 10) | Use the [Windows 7](#windows-7) command: it switches on TLS 1.2 first.                                                              |
| "Could not establish trust relationship" (Windows 7)                 | The root certificates are out of date. Run Windows Update, or download the files on another PC (**6 Download only**).               |
| A download fails                                                     | The script tries the next source. To force one: `-Source ArchiveOrg -NoFallback`.                                                   |
| "SHA-256 does not match"                                             | The source sent a damaged or different file. The script deletes it and tries the next source.                                       |
| "Access denied" when you extract by hand                             | Use PowerShell or 7-Zip as administrator, or use the script.                                                                        |
| The device does not appear after a restart                           | Make sure `...\ROCCAT Swarm\data\<DEVICE>\version.ini` exists. Look in `%APPDATA%\ROCCAT\SWARM\log\monitor\` for the device PID.    |
| You do not know which of two modules is yours (Vulcan 100 or 120)    | Install both. Only the matching module activates.                                                                                   |

> [!WARNING]
> Each module carries the firmware images for its device, and Swarm can offer a firmware
> update. Update only on purpose: a failed flash can make the device unusable. Do not
> disconnect the device during an update.

## What's in the archive

The git repository holds only `install.ps1`, `catalog.csv`, this README and two maintainer
tools. The files themselves are release assets and mirror copies.

| Release   | Contents                                                                                   |
| --------- | ------------------------------------------------------------------------------------------ |
| `swarm`   | ROCCAT Swarm installers: 24 builds from 1.30 (2015) to 1.9482 (2026)                       |
| `modules` | The 55 device modules from Swarm's update server (plugin DLL, firmware, keyboard layouts)  |
| `drivers` | Windows drivers for 26 pre-Swarm devices, and the macOS driver for the Kone XTD            |
| `extras`  | Talk FX 2.6, the Power-Grid SDK 1.1, Swarm II, Swarm's self-update package, `aim_roccat`  |

[`catalog.csv`](catalog.csv) lists every file: its device, version, USB PIDs, SHA-256,
release asset, mirror path and vendor URL. GitHub shows it as a searchable table.

### Mirrors

| Mirror          | Where                                                                         |
| --------------- | ----------------------------------------------------------------------------- |
| GitHub releases | <https://github.com/thefoofighter/RoccatSwarmArchive/releases>                |
| archive.org     | <https://archive.org/details/roccat-swarm-archive>                            |
| MEGA            | <https://mega.nz/folder/3UxDgSKK#wNGE-jPvBYINz8F4goA0IQ>                      |
| Turtle Beach    | The vendor's own servers, while they stay online (most files)                 |

On archive.org and MEGA the files sit in the folders `swarm/<version>/`,
`modules/<device>/`, `drivers/<device>/`, `addons/`, `sdk/` and `other/` (the `path`
column of `catalog.csv`). Both also hold `install.ps1`, in case GitHub is not available.

<details>
<summary><b>Where the files came from</b></summary>
<br>

The files were captured from 19 to 21 November 2026 from:

- Turtle Beach's support CDN and Swarm's auto-update service;
- ROCCAT's legacy CDN, which is still online;
- Wayback Machine copies of `media.roccat.org`: Swarm 1.30 to 1.9388, the Mac driver, the
  Power-Grid SDK and the `aim_roccat` map.

Two installers are community uploads from archive.org: Swarm 1.9477, and Swarm 1.9349
from the 2019 `roccat-swarm-files` item (its exe is signed by ROCCAT GmbH). Every archive
passes `7z t`, and every size matches the server's. The `official_url` column holds the
vendor URL where the vendor still serves the identical file; the script can download from
there with `-Source TurtleBeach`.

The modules do not include Swarm's add-on modules (Talk FX module, AlienFX, Swarm Connect,
Waves driver). The update server no longer hands them out, and no copy was found.

</details>

<details>
<summary><b>For maintainers</b></summary>
<br>

- `tools/build-catalog.ps1` checks `catalog.csv` against the files and fills in sizes,
  hashes and module folders.
- `tools/publish.ps1` uploads to GitHub releases or archive.org. Its help
  (`Get-Help tools\publish.ps1 -Full`) also gives the MEGA steps.

</details>

## Legal

> [!NOTE]
> This is an unofficial preservation project. It is not affiliated with Turtle Beach or
> ROCCAT. ROCCAT, Swarm and the product names are trademarks of their owners.

Swarm, the modules, the firmware images and the drivers are the copyright of Turtle Beach
(ROCCAT). The product is discontinued, and the vendor no longer offers most of these files.
The archive holds unmodified copies of the vendor's downloads. If you hold the rights and
want a file removed, open an issue.

This archive is part of ElderHive, a project to build a free, open-source replacement for
Swarm.
