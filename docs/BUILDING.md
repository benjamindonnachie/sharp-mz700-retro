# Building

Python 3.10 or later is required. The repository includes the pinned pyz80 assembler, monitor and BASIC references, and fixed CP/M partition seed; the default build does not depend on external archive drives or downloads.

From the repository root:

```sh
python3 tools/build.py
```

This reassembles the diagnostic, tape first stage, file manager, BASIC patch, physical monitor, SAVE service and RAM monitor. It then constructs the ROM and tape starter images and checks their files, partition offsets, bootstrap checksums and helper vectors. The monitor and patched BASIC must reproduce the recorded binary hashes.

The default build uses the pinned CP/M system and loader binaries in `reference/cpm-build/`, then assembles the matching bootstrap. To rebuild the CP/M BIOS and system through ZXCC, RMAC, LINK and GENCPM as well:

```sh
python3 tools/build.py --rebuild-cpm
```

That option also requires a native C compiler, Make and a POSIX environment. ZXCC is built in a temporary directory. The fixed partition seed supplies the standard utilities and BDS C examples, while generated system components are replaced. This process retains the native C:/D: filesystem.

## Outputs

Generated assembly, maps and metadata go into each component's ignored `build/` or `build-mbr/` directory. Publication artifacts go into `release/`, with distinct `rom/` and `tape/` menu variants. Raw images are excluded from Git; deterministic gzip versions are supplied with compressed and uncompressed checksums.

The firmware remains V0.1.0, dated **18 November 2026**. Repository release v0.1.1 revises the documentation; it does not change the executable firmware. The card images include a revised README, so their checksums differ from the withdrawn package.

To validate the supplied artifacts without rebuilding:

```sh
python3 tests/validate_release.py
```

## Source layout

| Directory | Contents |
| --- | --- |
| `hardware/gide-monitor/` | Physical and RAM monitor, native SAVE gateway |
| `hardware/gide-menu/` | FAT32 reader, tape first stage, file manager and title indexes |
| `hardware/gide-basic/` | BASIC patches, compact driver and shared workspace |
| `hardware/gide-diagnostic/` | ATA and RTC diagnostic |
| `cpm/mz700-40/` | Fixed-volume BIOS and 40-column boot sources |
| `cpm/cpm3-on2/` | Preserved CP/M build inputs and ZXCC archive |
| `reference/` | Pinned binary inputs and provenance |
| `evidence/` | Recorded emulator and release checks |

The custom emulator and its complete historical test fixtures are not bundled. See [Testing](TESTING.md) for the scope of the supplied evidence and automated checks.
