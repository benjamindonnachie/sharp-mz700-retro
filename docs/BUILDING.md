# How I build this release

I use Python 3.10 or later for the assembler and packaging scripts. I include the pinned pyz80 assembler, the monitor reference, the UniCard BASIC reference and the fixed CP/M partition seed so my normal firmware build does not need my archive drives or a network download.

From the repository root I run:

```sh
python3 tools/build.py
```

I reassemble the diagnostic, tape first stage, menu, BASIC patch, physical ROM, SAVE service and RAM monitor. I then create separate ROM and tape card images and check their files, partition offsets, bootstrap checksums and helper vectors. I require my ROM and patched BASIC to reproduce the known binary hashes before I accept the package.

For the default build I reuse the pinned CP/M system/loader binaries in `reference/cpm-build/`, and assemble their matching bootstrap. To rebuild the CP/M BIOS and system with the included ZXCC/RMAC/LINK/GENCPM toolchain as well, I run:

```sh
python3 tools/build.py --rebuild-cpm
```

For that option I also need a native C compiler, Make and a POSIX environment. I build ZXCC in a temporary directory rather than installing it system-wide. I retain the fixed C:/D: seed for the standard utility files and BDS C examples, then replace its generated system components. I have not added a CP/M FAT32 filesystem to this process.

## Files I produce

- I put generated assembly, maps and metadata in each component's ignored `build/` or `build-mbr/` directory.
- I put the publication artifacts in `release/`, with separate `rom/` and `tape/` menu variants.
- I keep raw `.img` files out of Git and publish deterministic gzip versions, with checksums for both the compressed downloads and the uncompressed images.
- I preserve the ROM's **18 November 2026** banner date for this build; my initial repository publication is **21 November 2026**. I have not changed firmware bytes merely to update the publication date.

I can check an existing release without rebuilding it:

```sh
python3 tests/validate_release.py
```

## My source layout

| Directory | What I keep there |
| --- | --- |
| `hardware/gide-monitor/` | My physical/RAM monitor and native SAVE gateway |
| `hardware/gide-menu/` | My FAT32 reader, tape first stage, browser and title indexes |
| `hardware/gide-basic/` | My BASIC patches, compact driver and shared read/write workspace |
| `hardware/gide-diagnostic/` | My ATA/RTC diagnostic |
| `cpm/mz700-40/` | My 40-column fixed-volume BIOS and boot sources |
| `cpm/cpm3-on2/` | The preserved CP/M build inputs and ZXCC archive |
| `reference/` | My pinned binary inputs and their provenance |
| `evidence/` | My recorded emulator and release checks |

I have not bundled the custom emulator itself in this first repository. I explain the scope of the emulator evidence in [my testing notes](TESTING.md).
