# Sources, licences and acknowledgements

New driver, gateway and adaptation code is licensed under **GPL-3.0-or-later**, with the full licence in [COPYING](COPYING). Original Sharp monitor/BASIC code, NOBOMI-SOFT's UniCard patches, Digital Research components and the preserved SUC keyboard implementation retain their own notices and terms. They are not relicensed by this project.

Project author: **Benjamin Donnachie**. Code and documentation co-author: **OpenAI Codex**. This credit does not imply authorship of the third-party components below.

## Sharp monitor and character data

The European **1Z-013A** monitor is based on the published annotated disassembly from [the Sharp MZ archive](https://r3tr0.de/mirror/sharpmz.org/mz-700/monirom.html). Its original header remains in `cpm/mz700-monitor/reference/Mz700.asm`; the adjacent provenance file pins the source and ROM hashes. Matching character data is retained for emulator use. Sharp's components and branding remain attributed to Sharp.

Hardware details were checked against the [MZ-700 service manual](https://www.eps.udl.cat/export/sites/Eps/ca/documents/documents-general/Sharp-Personal-Computer-MZ-700.pdf).

## UniCard and BASIC

[UniCard](https://www.sharpwiki.cz/doku.php?id=unicard) provided the inspiration for this project. An existing GIDE interface provided the basis for pursuing IDE storage further.

The patched interpreter is derived from **NOBOMI-SOFT's UniCard BASIC MZ-5Z008 V0.1**, itself based on Sharp Quick Disk BASIC. The original Sharp and NOBOMI-SOFT credits are retained.

The pinned reference, `BASIC_5Z-008_for_unicard.mzf`, comes from the [UniCard demonstration download](https://www.sharpwiki.cz/doku.php?id=en:unicard:z50download), package `sd_1500_v5_fw023_man211_2021-05-23.zip`. Its SHA-256 is `61bf47315c57d47eac1c2d64745d153341a5c17d06839e41f6745549833a605f`. Publication of the adaptation does not grant a new licence over the interpreter or its pre-existing patches.

## GIDE

The implementation follows the [original GIDE specification](https://www.autometer.de/gide/GIDE.txt), with acknowledgement to Tilmann Reh and the other interface contributors. It targets the byte-wide CPU interface at 20h and ATA PIO/LBA28 devices. Adapter firmware is not included.

## CP/M, SUC and BIOS framework

The maintained Digital Research CP/M 3 components were preserved from [John Elliott's CP/M releases](https://www.seasip.info/Cpm/software/dri.html). The corresponding `cpm3src_unix.zip` archive, pinned provenance and original Digital Research/DRDOS notices are retained. CP/M's separate redistribution terms are described in the [rights-holder's licence statement](https://www.cpm.z80.de/license.html).

The generic BIOS framework retains Bill Smith/Morrow notices. Keyboard support relocates original SUC Personal CP/M machine code and tables; its source hash and relocation method are documented in `cpm/mz700-40/keyboard-provenance.json`. The DB/DW representation is not claimed as recovered original SUC assembly source.

## BDS C

**BDS C 1.60** and the small compiler/I/O examples are retained from the fixed-volume image. Leor Zolman's public-domain declaration is preserved verbatim in `reference/BDS-C-NOTICE.txt`, including the original wording.

## Build tools

**pyz80 1.3.0** is included with its unchanged GPL licence and pinned provenance under `cpm/gide/third_party/`. Acknowledgement is due to [Simon Owen's pyz80 project](https://github.com/simonowen/pyz80) and its contributors.

John Elliott's **ZXCC 0.5.7** source archive is included for the CP/M rebuild option, with its original licence retained inside the archive. RMAC, LINK and GENCPM retain their Digital Research notices.

## Exclusions

The initial repository excludes the games collection, personal card backups, private working directories and custom emulator. The FAT32 starter image contains the storage software alongside the existing fixed-volume CP/M build.
