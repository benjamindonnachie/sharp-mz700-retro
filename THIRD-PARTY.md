# My sources and third-party acknowledgements

I retain the credits and terms of the components on which this work depends. I apply **GPL-3.0-or-later** to my new driver, gateway and adaptation code, using the licence in [COPYING](COPYING). I do not apply that grant to the original Sharp monitor or BASIC, NOBOMI-SOFT's UniCard patches, Digital Research components or the preserved SUC keyboard implementation.

## Sharp monitor and character data

I use Sharp's European **1Z-013A** monitor, with the published annotated disassembly from [the Sharp MZ archive](https://r3tr0.de/mirror/sharpmz.org/mz-700/monirom.html). I retain its original header in `cpm/mz700-monitor/reference/Mz700.asm` and pin the source and ROM hashes in the neighbouring provenance file. I also retain the matching character data for emulator use. I do not claim ownership of those Sharp components or imply that Sharp endorses this project.

I checked the hardware details against the [Sharp MZ-700 service manual](https://www.eps.udl.cat/export/sites/Eps/ca/documents/documents-general/Sharp-Personal-Computer-MZ-700.pdf).

## UniCard and BASIC

I took inspiration from [UniCard](https://www.sharpwiki.cz/doku.php?id=unicard), but already had a GIDE interface and chose to explore that route. I adapt **NOBOMI-SOFT's UniCard BASIC MZ-5Z008 V0.1**, derived from Sharp Quick Disk BASIC. I preserve Sharp and NOBOMI-SOFT's credits.

My reference is `BASIC_5Z-008_for_unicard.mzf` from the [UniCard demonstration download](https://www.sharpwiki.cz/doku.php?id=en:unicard:z50download), package `sd_1500_v5_fw023_man211_2021-05-23.zip`. I pin its SHA-256 to `61bf47315c57d47eac1c2d64745d153341a5c17d06839e41f6745549833a605f`. I am publishing my adaptation with that provenance; I am not claiming to grant a new licence over the interpreter or its pre-existing patches.

## GIDE

I follow the [original GIDE specification](https://www.autometer.de/gide/GIDE.txt) and acknowledge Tilmann Reh and the other contributors to the interface. I target the byte-wide CPU interface at base 20h with ATA PIO/LBA28 devices. I have not copied an adapter's firmware into this repository.

## CP/M, SUC and BIOS framework

I use the maintained Digital Research CP/M 3 components preserved from [John Elliott's CP/M releases](https://www.seasip.info/Cpm/software/dri.html), with original Digital Research/DRDOS notices retained. I include the corresponding `cpm3src_unix.zip` archive and pin its provenance; I do not label the original operating system as my GPL code. I refer to the [CP/M rights-holder's licence statement](https://www.cpm.z80.de/license.html) for its separate redistribution terms.

I retain Bill Smith/Morrow notices in the generic BIOS framework. My keyboard support relocates original SUC Personal CP/M machine code and tables; I record its source hash and relocation method in `cpm/mz700-40/keyboard-provenance.json`. I do not claim that my DB/DW representation is recovered original SUC assembly source.

## BDS C

I retain **BDS C 1.60** and the small compiler/I/O examples from my fixed-partition image. I preserve Leor Zolman's public-domain declaration in `reference/BDS-C-NOTICE.txt`, including its original wording. I have not rewritten third-party rights notices into my own voice.

## Build tools

I include **pyz80 1.3.0**, with its unchanged GPL licence and pinned provenance under `cpm/gide/third_party/`. I acknowledge [Simon Owen's pyz80 project](https://github.com/simonowen/pyz80) and its contributors.

I include John Elliott's **ZXCC 0.5.7** source archive for the CP/M rebuild option, retaining its original licence inside that archive. I acknowledge the original RMAC, LINK and GENCPM tools and their Digital Research notices.

## Material I have left out

I have not included my third-party games collection, personal card backups, private working directories or the custom emulator in this initial upload. I use a small software-only FAT32 starter image alongside the existing fixed-partition CP/M build.
