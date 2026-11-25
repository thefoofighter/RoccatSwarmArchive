# ROCCAT Swarm Archive

ROCCAT Swarm (v1) is abandoned. Swarm downloads a "module" for each device the first time
you connect it. Builds up to 1.9478 can no longer do this: their update server is gone.
The last build, 1.9482, uses a Turtle Beach server that still answers, but nothing
promises that it stays online. This archive keeps every official Swarm installer, all 55
device modules, the pre-Swarm drivers and the add-ons. It also gives you a script that
installs them, with no update server.

* **Script:** one PowerShell command. It installs Swarm if it is missing, finds your
  ROCCAT devices, and installs only the modules you need.
* **Manual:** download the files from the [releases](https://github.com/thefoofighter/RoccatSwarmArchive/releases).
  [`catalog.csv`](catalog.csv) lists every file, with its device, USB PIDs and SHA-256.
* **Mirrors:** GitHub releases, archive.org and MEGA hold the same files. The script
  checks every file against its SHA-256 and changes to the next mirror if one fails.

The offline install method was tested on Windows 10 x64 with Swarm 1.9482 and the Kone
AIMO Remastered, with the network blocked.

---

## Install with the script

You need Windows 10 or 11 and an account with administrator rights.

1. Open PowerShell (Start menu, type `powershell`, press Enter).

2. Paste this command and press Enter:

   ```powershell
   irm https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1 | iex
   ```

   You prefer to read the script first? Download
   [`install.ps1`](https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1),
   read it, then right-click it and select **Run with PowerShell**.

3. Click **Yes** in the Windows administrator prompt.

4. Select **1 Quick setup**. The script installs Swarm 1.9482 if it is missing, then the
   modules for the ROCCAT devices that are plugged in. The Swarm installer opens: click
   through it and keep the default folder.

The menu:

| Option                        | What it does                                                                 |
| ----------------------------- | ---------------------------------------------------------------------------- |
| 1 Quick setup                 | Swarm (if missing) + the modules for the connected devices                   |
| 2 Install device modules      | Pick modules from a list (also for devices that are not plugged in)          |
| 3 Install a Swarm version     | Any of the 23 archived builds. 1.9482 is the one to use                      |
| 4 Install a standalone driver | Drivers for devices that Swarm never supported, for example the Kave XTD 5.1 |
| 5 Install an add-on           | ROCCAT Talk FX                                                               |
| 6 Download only               | Save files to a folder for a PC with no internet                             |
| 7 Change the download source  | GitHub, archive.org, MEGA, Turtle Beach's own servers, or a local folder     |

**You connect a new device later?** Run the command again and select **1**. It skips the
modules that you already have and installs only the new one. Modules that are installed
at the same or a newer version are always skipped.

### Options (no menu)

Add options to the command like this:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/thefoofighter/RoccatSwarmArchive/main/install.ps1))) -Auto
```

With a downloaded copy, use `powershell -ExecutionPolicy Bypass -File install.ps1 -Auto`.

| You want to                                                       | Option                                         |
| ----------------------------------------------------------------- | ---------------------------------------------- |
| See what is installed and what the script finds (changes nothing) | `-List`                                        |
| Quick setup                                                       | `-Auto`                                        |
| Install named modules (`id` from `catalog.csv`, or a USB PID)     | `-Modules kone-aimo-remastered,3098`           |
| Install every module                                              | `-AllModules`                                  |
| Install a Swarm build (`latest` = 1.9482) with no installer window | `-Swarm latest -Silent`                        |
| Install a standalone driver                                       | `-Driver kave-xtd-5-1-digital`                 |
| Prefer a mirror                                                   | `-Source ArchiveOrg` (or `Mega`, `TurtleBeach`) |
| Use only that mirror                                              | add `-NoFallback`                              |
| Reinstall modules that are already installed                      | add `-Force`                                   |

Other options: `-SwarmDir <folder>` (Swarm is not in the default folder), `-NoRestart`
(do not start Swarm after a module install), `-Source Local -LocalDir <folder>` (use a
copy of the archive on disk).

### A PC with no internet

1. On a PC with internet, start the script and select **6 Download only**. Option 1
   there saves Swarm 1.9482 and all 55 modules (about 400 MB) to a folder.
2. Copy the folder to the other PC (USB drive). It holds the files, `catalog.csv` and
   `install.ps1`.
3. On the other PC, run `install.ps1` from that folder. The script uses the files next to
   it and downloads nothing.

---

## Install by hand

### 1. Install Swarm

1. Download [`ROCCAT-Swarm_1.9482.zip`](https://github.com/thefoofighter/RoccatSwarmArchive/releases/download/swarm/ROCCAT-Swarm_1.9482.zip).
2. Unzip it and run `ROCCAT Swarm_v19482.exe`. Keep the default folder:
   `C:\Program Files (x86)\ROCCAT\ROCCAT Swarm\`.
3. Swarm can start and show "no device" or "downloading". That is normal. Close it before
   the next step.

### 2. Find the module for your device

Find your device in [`catalog.csv`](catalog.csv) (rows with `kind` = `module`). The
`pids` column holds its USB product IDs, and `asset` is the file name in the
[modules release](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/modules).
If you do not know your device's PID, plug the device in and run this in PowerShell:

```powershell
Get-PnpDevice -PresentOnly | Where-Object InstanceId -match 'VID_1E7D' | Select-Object -ExpandProperty InstanceId -Unique
```

The `PID_XXXX` part of the output is the PID. Ignore PIDs that start with `A2`, `50` or
`00B`: they show the firmware-update mode. Replug the device and run the command again.

Download the module file (`.7z`). Optional: run `Get-FileHash <file>` and compare the
result with the `sha256` column.

### 3. Stop Swarm

Right-click the Swarm icon in the notification area and select **Exit**. Or open Task
Manager and end `ROCCAT_Swarm.exe`, `ROCCAT_Swarm_Monitor.exe` and `ROCCAT_dev_service.exe`.

### 4. Extract the module into the Swarm folder

Open PowerShell **as administrator** in the folder with the module file. Use the 7-Zip
copy that comes with Swarm (example for the Kone AIMO Remastered):

```powershell
& 'C:\Program Files (x86)\ROCCAT\ROCCAT Swarm\7-Zip\7za.exe' x -y '-oC:\Program Files (x86)\ROCCAT\ROCCAT Swarm' 'kone-aimo-remastered_207-1.0009-1.0009-8052-v1.7z'
```

You can also use 7-Zip's File Explorer menu: right-click the `.7z` file, select
**7-Zip > Extract files...**, and set the Swarm folder as the target. Extract into the
Swarm folder itself, not into a new subfolder. The files must land like this:

```text
C:\Program Files (x86)\ROCCAT\ROCCAT Swarm\
  ROCCAT_Swarm.exe
  data\
    KONE_AIMO_16K\        <- from kone-aimo-remastered_....7z
      KONE_AIMO.dll       (the device plugin)
      firmware\           (firmware image + firmware_upgrade.ini)
      version.ini         <- if this file is here, the module is in the right place
```

The `module_dirs` column of `catalog.csv` shows the folder each module creates. Repeat
this step for each device. A module for a device that is not connected does nothing until
you connect the device.

### 5. Start Swarm

Start Swarm. Your device appears with its full configuration page.

### Standalone drivers (devices that Swarm never supported)

Download the driver from the [drivers release](https://github.com/thefoofighter/RoccatSwarmArchive/releases/tag/drivers),
unzip it, and run its `Setup.exe`. Example: the Kave XTD 5.1 Digital uses
`kave-xtd-5-1-digital_63-2.19-1.00-6127-v1.zip`, which holds
`ROCCAT_KaveXTD_DRV2.19\Setup.exe`. The Arvo, Pyra and Valo drivers are `.rar` files:
open them with [7-Zip](https://www.7-zip.org).

---

## Which Swarm build?

Use **1.9482**, the last build. Builds up to 1.9478 point at ROCCAT's update server,
which is gone, so they cannot download anything. 1.9479 and later use Turtle Beach's
server. The offline module install was tested with 1.9482 only. Older builds are here for
preservation.

## Troubleshooting

| Problem                                                                       | What to do                                                                                                                                                   |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| "running scripts is disabled on this system"                                  | Use the `irm` command above, or start a downloaded copy with `powershell -ExecutionPolicy Bypass -File install.ps1`.                                          |
| "Could not create SSL/TLS secure channel" (old Windows 10)                    | Run `[Net.ServicePointManager]::SecurityProtocol = 'Tls12'` first, then the `irm` command.                                                                    |
| A download fails                                                              | The script tries the next mirror. To force one: `-Source ArchiveOrg -NoFallback`.                                                                            |
| "SHA-256 does not match"                                                      | The mirror sent a damaged or different file. The script deletes it and tries the next mirror.                                                                |
| "Access denied" when you extract by hand                                      | Use PowerShell or 7-Zip as administrator, or use the script.                                                                                                 |
| The device does not appear after a restart                                    | Make sure `...\ROCCAT Swarm\data\<DEVICE>\version.ini` exists. Look in `%APPDATA%\ROCCAT\SWARM\log\monitor\` for the device PID.                             |
| You do not know which of two modules is yours (for example Vulcan 100 or 120) | Install both. Only the matching module activates.                                                                                                            |
| Swarm offers a firmware update                                                | The firmware images ship inside each module. Update only on purpose: a failed flash can make the device unusable. Do not unplug the device during an update. |

## What is in this archive

| Release / folder | Contents                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------- |
| `swarm`          | ROCCAT Swarm installers, 23 builds from 1.30 (2015) to 1.9482 (2026)                      |
| `modules`        | The 55 device modules from Swarm's update server (plugin DLL, firmware, keyboard layouts) |
| `drivers`        | Windows drivers for 26 pre-Swarm devices, and the one known macOS driver (Kone XTD)       |
| `extras`         | Talk FX 2.6, the Power-Grid SDK 1.1, Swarm II, Swarm's self-update package, `aim_roccat`  |

On archive.org and MEGA the same files sit in the folders `swarm/<version>/`,
`modules/<device>/`, `drivers/<device>/`, `addons/`, `sdk/` and `other/` (the `path`
column of `catalog.csv`). The git repository holds only `install.ps1`, `catalog.csv`,
this README and two maintainer tools.

### Where the files came from

Captured 2026-11-19 to 2026-11-21, from Turtle Beach's support CDN, Swarm's auto-update
service, ROCCAT's legacy CDN (still online), and Wayback Machine copies of
`media.roccat.org` (Swarm 1.30 to 1.9388, the Mac driver, the Power-Grid SDK, `aim_roccat`).
One installer, Swarm 1.9477, is a community upload from archive.org. Every archive passes
`7z t`, and every size matches the server's. The `official_url` column holds the vendor
URL where the vendor still serves the identical file; the script can download from there
(`-Source TurtleBeach`). The modules contain no Swarm add-ons (Talk FX module, AlienFX,
Swarm Connect, Waves driver): the update server no longer hands them out.

## Mirrors

| Mirror          | Where                                                                         |
| --------------- | ----------------------------------------------------------------------------- |
| GitHub releases | <https://github.com/thefoofighter/RoccatSwarmArchive/releases>                |
| archive.org     | <https://archive.org/details/roccat-swarm-archive> (also holds `install.ps1`) |
| MEGA            | link to follow                                                                |
| Turtle Beach    | the vendor's own servers, while they stay online (most files)                 |

## Maintainers

`tools/build-catalog.ps1` checks `catalog.csv` against the files and fills in sizes,
hashes and module folders. `tools/publish.ps1` uploads to GitHub releases or archive.org;
its help (`Get-Help tools\publish.ps1 -Full`) also gives the MEGA steps.

## Legal

Swarm, the modules, the firmware images and the drivers are the copyright of Turtle Beach
(ROCCAT). The product is discontinued, and the vendor no longer offers most of these
files. They are unmodified copies of the vendor's downloads. If you hold the rights and
want a file removed, open an issue.
