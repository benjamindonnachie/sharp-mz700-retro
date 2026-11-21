# Sharp MZ-700 retro projects

I am Benjamin Donnachie, and this is where I keep my Sharp MZ-700 experiments. My initial focus is booting from a GIDE interface, loading software from CompactFlash or SD through IDE, and making the machine more useful for BASIC and CP/M.

I took inspiration from [UniCard](https://www.sharpwiki.cz/doku.php?id=unicard). As I already had a GIDE interface, I chose to explore that route further rather than replace it. UniCard is also the starting point for my patched BASIC, with the original Sharp and NOBOMI-SOFT credits retained.

![My GIDE menu running from the public starter image in my emulator](docs/images/gide-menu.png)

## What I have included

| Component | My current implementation |
| --- | --- |
| GIDE boot monitor | A replacement 4 KiB monitor ROM, with the original public helper entry points retained. I load a more comprehensive RAM monitor from the card after reset. |
| Bootloader and menu | A small tape first stage, or the replacement ROM, loads the main menu from the card. I use a two-column, alphabetically sorted browser with cursor selection and catalogue titles. |
| Patched BASIC | I have redirected file access to GIDE/FAT32, including LOAD, SAVE, confirmed overwrite and sequential data files. I retain **30,134 bytes free** at startup, matching the UniCard version. |
| CP/M 3 | I use the working **fixed-partition, native CP/M filesystem** build, with C: and D: as separate 8 MiB volumes and the stock 40-column display. |
| Diagnostics | I have included my GIDE diagnostic with ATA checks, an RTC display and setting option, and an optional sector write/verify/restore test. |

My menu and BASIC already use FAT32. **My CP/M FAT32 version is in development and is not included as a working filesystem in this release.** For now, selecting CP/M boots the fixed-volume implementation; it does not give CP/M access to the shared FAT32 files.

I am also looking to recreate the **SUC 80-column modification** for further CP/M work. I have not made an 80-column board a requirement of this release, and I am not presenting that hardware as finished.

## Getting started

I describe both boot arrangements in [my installation notes](docs/INSTALLATION.md):

- With the original Sharp monitor, I load `GIDE-BOOT.MZT` from tape and use the **tape** card image.
- With my replacement monitor ROM, I use the matching **ROM** card image. That image contains the raw bootstrap sectors and RAM monitor as well as the FAT32 files.

I keep the two menu variants separate because their bank-switching assumptions differ. Copying a menu file onto an old card does not install the ROM bootstrap.

I publish the binaries, compressed card images and checksums under [release/](release/). I have deliberately left out my game collection and personal card backups. I can add my own compatible MZT/MZF files to the FAT32 partition from a PC.

## Hardware and status

I target a PAL MZ-700 with 64 KiB RAM, GIDE at **20h**, an ATA master with 512-byte sectors, and the original 40-column display. I have a HAL PCG attached, but the storage system does not require it. I use a Winbond W27C512-45Z through an adapter for the replacement ROM; I provide a 64 KiB image containing sixteen identical 4 KiB copies.

I have booted the fixed-partition CP/M build on my physical Sharp. I have also confirmed that the replacement EPROM reaches its boot banner and recovery handler on that machine. I have written and readback-verified the matching CF card. At this initial publication I have not yet recorded a successful complete ROM-to-menu boot on the physical Sharp with that updated card, or a physical validation of every SAVE path. I keep those distinctions in [my testing notes](docs/TESTING.md).

## Building and using it

I document my [build process](docs/BUILDING.md), [BASIC commands](docs/BASIC.md), [fixed CP/M layout](docs/CPM.md), [diagnostic](docs/DIAGNOSTICS.md), and [ROM/RAM helper interface](docs/MONITOR.md). I record the work I intend to pursue in [my roadmap](docs/ROADMAP.md).

I license my new code under GPL-3.0-or-later. I retain the separate provenance and notices for Sharp, NOBOMI-SOFT, Digital Research/DRDOS, SUC, BDS C, ZXCC and pyz80 components in [my third-party notes](THIRD-PARTY.md). I do not claim those components as my original work or relicense them under my own licence.
