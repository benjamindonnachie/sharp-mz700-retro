# How I install the GIDE software

I use GIDE at base address **20h**, with the storage device selected as ATA master. I switch the Sharp off before fitting or removing the card or changing IDE connections.

## My two boot arrangements

| My boot arrangement | Card image | First stage | Menu on the card |
| --- | --- | --- | --- |
| Original Sharp monitor and tape | `release/gide-tape-card.img.gz` | `release/tape/GIDE-BOOT.MZT` | `release/tape/MENU.MZF` |
| Replacement GIDE monitor ROM | `release/gide-rom-card.img.gz` | My physical 4 KiB monitor ROM | `release/rom/MENU.MZF` |

I decompress the selected `.img.gz` before writing it. I write the resulting image to the **whole device**, starting at byte zero, rather than to a partition or as a file. I check the device identity and take a backup first, because the image replaces the partition table and the populated area of the card. I do not supply an automatic physical-disk writer in this repository.

Each image is **85,983,232 bytes**, with a conventional MBR, fixed native CP/M volumes and a shared 64 MiB FAT32 partition. I can use a larger card, but this release leaves its remaining capacity unallocated.

I verify the download with `release/SHA256SUMS`. After writing, I compare the complete image-sized prefix of the card with the uncompressed image and eject the device before unplugging it.

## My replacement ROM

I use `release/rom/MZ700-GIDE-MONITOR-4K.bin` for a compatible 4 KiB EPROM, or `release/rom/MZ700-GIDE-MONITOR-W27C512-64K.bin` for my W27C512. The latter repeats the same monitor sixteen times. I have verified it using a T48 programmer and the `W27C512@DIP28` minipro profile.

I use an adapter because the original Mitsubishi M5L2732K monitor at position 5H is a 24-pin part, while my W27C512 is a 28-pin part. I check the complete pin mapping, chip-enable and output-enable wiring, supply polarity and orientation. I hold A12–A15 at defined logic levels on the adapter; with the mirrored image I can tie all four high or all four low. I keep these straps off the bare chip so they are absent when I put it in the programmer.

After reset I expect:

```text
GIDE BOOT MONITOR V0.1.0
2026-11-18
```

The ROM makes five bounded bootstrap attempts. If they fail, I get `GIDE ERROR R/L`: I use **R** to retry or **L** to fall back to the native tape loader. I first check that I wrote the ROM card image, because the older tape card does not contain the required raw sectors.

## My tape fallback

With the original monitor ROM, I enter **L** and play `GIDE-BOOT.MZT` using my cassette transfer arrangement. MZT is a tape-file container, not an audio waveform. The small first stage loads `MENU.MZF` from the FAT32 root.

I do not use that standalone tape first stage with the RAM-monitor menu. I keep each card image with its matching first stage.

## How I use the menu

I move with the cursor keys and press **Return** to open a folder or load a compatible machine-code file. I use **Delete** for the parent folder and **Space** for the action bar: CP/M, BASIC, Rescan, Parent and Monitor.

I use `TITLES.IDX` files when I want catalogue names rather than short filenames. The browser sorts by complete title and shows the selected title along the bottom. I use `hardware/gide-menu/title_index.py` to generate these indexes from my own `CATALOG.JSN` data.

I load BASIC programmes from within BASIC, rather than treating them as machine-code applications in the browser. I keep native CP/M files on C: and D:, separate from the FAT32 directories.

## My hardware observations

I initially had instability with a roughly 10 cm CPU-to-GIDE ribbon extension. Shortening it to less than 4 cm resolved that behaviour on my machine. I regard that as an observation about my wiring and loading, rather than a universal cable-length specification.

I check power and connectors before diagnosing a loader fault. I previously encountered a hot adapter power connection and display corruption, and I do not treat software retries as a cure for a power fault.
