# My fixed-partition CP/M 3 build

For this release I use **native CP/M filesystems at fixed offsets**, with 512-byte ATA sectors. I have not replaced BDOS's filesystem with FAT32. I am developing that separately.

I run non-banked CP/M 3 on the standard 64 KiB MZ-700, with the stock 40×25 display and GIDE at 20h. I do not require additional RAM, a SUC 80-column board or floppy hardware. I leave A: and B: unavailable and boot to **C>**.

## My card layout

| Area | First LBA | Sector count |
| --- | ---: | ---: |
| Native CP/M MBR partition, type 52h | 00000800h | 00008011h |
| C: native 8 MiB volume | 00000800h | 00004000h |
| D: native 8 MiB volume | 00004800h | 00004000h |
| `GIDE40!!` boot header | 00008800h | 1 |
| CPMLDR payload | 00008801h | 16 |
| Shared FAT32 MBR partition, type 0Ch | 00009000h | 00020000h |

I list FAT32 first in the MBR table for PC compatibility even though it physically follows the CP/M partition. I do not infer that CP/M can read FAT32 because both partitions share a card.

I use two 8 MiB CP/M volumes with 4 KiB allocation blocks, 512 directory entries and no reserved tracks or sector skew. BDOS manages the native 512-byte sector buffers; CP/M file records remain 128 bytes. My BIOS uses the Sharp's memory banking for keyboard and video access without expansion RAM.

## How I start it

I choose CP/M from the GIDE menu. The card's `CPM3.MZF` is the IDENTIFY-first MBR loader, with the white-on-blue screen setup applied before the CP/M console starts. I keep `CPM3.SYS` and `CCP.COM` on C:, user area 0.

I can try:

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

I retain BDS C 1.60 and its supplied small examples on D: from my existing fixed-partition build. I preserve Leor Zolman's public-domain declaration separately under `reference/BDS-C-NOTICE.txt`. I close files before reset or power-off because CP/M owns live sector buffers.

## Memory and development

I place BDOS at CC00h and BIOS at EB00h. I have 51,200 bytes of transient programme area at the prompt; an ordinary application can reclaim the command-loader prefix and use 51,968 bytes. I retain the native Sharp keyboard scanner through a documented relocation of the SUC binary, rather than claiming to have recovered its original source.

I am investigating a **CP/M FAT32 version**, including the cost of replacing filesystem code and sharing buffers. I have not included those experiments as the default CP/M system here. I am also looking to recreate the **SUC 80-column modification** so I can do more substantial CP/M work on the Sharp. I keep this initial software compatible with the original display while that proceeds.
