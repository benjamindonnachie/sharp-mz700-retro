# Installation

The software expects GIDE at **20h**, an ATA master and 512-byte logical sectors. Switch off the Sharp before fitting or removing storage media or changing IDE connections.

## Card images

| Boot arrangement | Image | First stage | Matching menu |
| --- | --- | --- | --- |
| Original monitor and tape | `release/gide-tape-card.img.gz` | `release/tape/GIDE-BOOT.MZT` | `release/tape/MENU.MZF` |
| Replacement monitor ROM | `release/gide-rom-card.img.gz` | Replacement 4 KiB ROM | `release/rom/MENU.MZF` |

Decompress the appropriate image and write it to the **whole device**, starting at byte zero. It is not a file to copy into an existing partition. Confirm the device identity and take a backup first: writing the image replaces the partition table and populated area of the card. No automatic physical-disk writer is included.

Both images are **85,983,232 bytes** and contain an MBR, the fixed CP/M volumes and a 64 MiB FAT32 partition. Larger cards are supported, with the remaining capacity left unallocated.

Download checksums are listed in `release/SHA256SUMS`. After writing, compare the complete image-sized prefix of the card with the uncompressed image, then eject it before removal.

## Replacement ROM

The original monitor is a Mitsubishi M5L2732K, a 24-pin 4 KiB EPROM at motherboard position **5H**. The replacement firmware is supplied in two forms:

- `release/rom/MZ700-GIDE-MONITOR-4K.bin`: the physical 4 KiB monitor image.
- `release/rom/MZ700-GIDE-MONITOR-W27C512-64K.bin`: sixteen identical copies for a 28-pin W27C512.

The W27C512 requires a correctly wired adapter. Check the address/data mapping, enable signals, power connections and orientation. Hold A12–A15 at defined levels on the adapter. With the mirrored image, tying all four high or all four low selects an identical copy. Keep these straps on the adapter rather than the chip so they are absent during programming.

The Winbond image has been programmed and verified with a T48 using minipro's `W27C512@DIP28` profile. On reset, the firmware displays:

```text
GIDE BOOT MONITOR V0.1.0
2026-11-18
```

The ROM makes five bounded bootstrap attempts. `GIDE ERROR R/L` indicates that loading or validation failed: **R** retries; **L** enters the original tape loader. A card prepared for tape boot alone lacks the raw bootstrap sectors required by this ROM.

## Tape boot

With the original monitor, enter **L** and play `GIDE-BOOT.MZT` through a suitable cassette transfer arrangement. MZT is a tape-file container, not an audio waveform. The first stage reads `MENU.MZF` from the FAT32 root.

Use the tape card image with this standalone first stage. The RAM-monitor menu requires the replacement ROM's bootstrap and must not be substituted into this arrangement.

## File manager

| Key | Action |
| --- | --- |
| Cursor keys | Move the selection |
| Return | Open a folder or load a compatible machine-code file |
| Delete | Return to the parent directory |
| Space | Open the action bar: CP/M, BASIC, Rescan, Parent or Monitor |

Folders precede files in the alphabetically sorted, two-column display. Where `TITLES.IDX` is present, catalogue titles determine sorting and the selected full title appears along the bottom. `hardware/gide-menu/title_index.py` generates these indexes from `CATALOG.JSN` data.

BASIC programmes are loaded from within GIDE BASIC. CP/M files belong on the native C: and D: volumes, separately from the FAT32 directories.

## Hardware observations

On the development machine, a roughly 10 cm CPU-to-GIDE ribbon extension caused instability. Shortening it to less than 4 cm resolved that behaviour. This is an observation about that assembly, rather than a universal cable-length specification.

A separate adapter power-connection fault caused heating and display corruption. Check supply integrity and connectors before attributing failures to filesystem or boot code; software retries do not resolve an electrical fault.
