# CP/M 3: fixed-volume build

The released CP/M system uses **native filesystems at fixed offsets** and 512-byte ATA sectors. FAT32 support for CP/M is in development and is not part of this build. The FAT32 file manager and BASIC operate independently of CP/M's filesystem.

The target is a standard 64 KiB MZ-700 with GIDE at 20h and a 40×25 display. No additional RAM, SUC 80-column board or floppy interface is required. A: and B: are unavailable; the initial prompt is **C>**.

## Layout

| Area | First LBA | Sector count |
| --- | ---: | ---: |
| Native CP/M MBR partition, type 52h | 00000800h | 00008011h |
| C: native 8 MiB volume | 00000800h | 00004000h |
| D: native 8 MiB volume | 00004800h | 00004000h |
| `GIDE40!!` boot header | 00008800h | 1 |
| CPMLDR payload | 00008801h | 16 |
| Shared FAT32 MBR partition, type 0Ch | 00009000h | 00020000h |

FAT32 appears first in the MBR table for PC compatibility, despite its later physical position. The two native volumes use 4 KiB allocation blocks, 512 directory entries, no reserved tracks and no sector skew. CP/M file records remain 128 bytes; BDOS manages native 512-byte sector buffers.

The BIOS uses the Sharp's existing memory banking for keyboard and video access. Here, non-banked CP/M means that no additional RAM banks are required; it does not mean that the peripheral mapping is static.

## Booting and supplied software

Select CP/M from the GIDE action bar. `CPM3.MZF` is the IDENTIFY-first MBR loader, with the white-on-blue attributes established across the screen before the CP/M console starts. `CPM3.SYS` and `CCP.COM` must remain on C:, user area 0.

Example commands:

```text
VERS3
DIR C:
DIR D:
TYPE D:DEMO.TXT
PIP C:COPY.TXT=D:DEMO.TXT
D:
HELLO
CC HELLO.C
CLINK HELLO
HELLO
```

D: contains BDS C 1.60 and small compiler/I/O examples from the existing fixed-volume build. Leor Zolman's public-domain declaration is retained in `reference/BDS-C-NOTICE.txt`. Close files before resetting or switching off, because CP/M maintains live sector buffers.

## Memory and development

BDOS starts at CC00h and BIOS at EB00h. The transient programme area is 51,200 bytes at the prompt; an application can reclaim the command-loader prefix and use 51,968 bytes. Keyboard support is a documented relocation of SUC machine code, not recovered original assembly source.

Work on a CP/M FAT32 version includes evaluating BDOS/BIOS changes, buffer sharing and RAM requirements. The fixed-volume implementation remains the release baseline. Recreating the SUC 80-column modification is a separate hardware objective intended to support further CP/M work.
