# My ROM and RAM monitor

I keep the physical ROM to 4 KiB. After the original hardware initialisation, I try to load a checksummed raw bootstrap from the GIDE card. That bootstrap installs a 4 KiB RAM monitor below 1000h, selects the RAM bank and starts the FAT32 first stage. I then load the larger menu from `MENU.MZF`.

I keep all 23 original public jump vectors at their original addresses and retain their original vector bytes. In the physical ROM I retain the original console, keyboard, timer, sound and tape implementations. In the RAM monitor I redirect the native write helpers to GIDE and forward the cassette read/verify and melody helpers back to the physical ROM through bank-safe gateways.

I retain J, L, M, V, D and B in the RAM monitor. I use **G**, **F** or **#** to return to the GIDE menu. I have replaced the old printer self-test command. Reset reselects the physical ROM and reloads the RAM monitor if an application has overwritten it.

## My reserved card sectors

| Slot | LBA |
| --- | --- |
| Bootstrap header | 8900h |
| Bootstrap payload, at most eight sectors | 8901h onwards |
| SAVE service header | 8920h |
| SAVE service payload, at most sixteen sectors | 8921h onwards |
| Lower RAM monitor | 8941h–8948h |
| Temporary upper-RAM backup, twenty-four sectors | 8A00h–8A17h |

I use the header magic `GIDEMN01`, a service identifier, fixed load and entry addresses, a bounded non-zero sector count and a 16-bit sum of the padded payload. I use these checks to detect corruption; I do not treat them as authentication.

## My raw ROM interface

I expose the descriptor at **0D8Eh** as `GIDE`, API version 1 and flags 0Fh, followed by jump entries:

| Entry | My routine |
| --- | --- |
| 0D94h | Initialise IDE |
| 0D97h | Read 512 bytes |
| 0D9Ah | Write 512 bytes |
| 0D9Dh | Load a card service: A=1 bootstrap, A=2 SAVE service |
| 0DA0h | Boot GIDE |
| 0DA3h | Native tape-load fallback |

I use this interface only with the **physical lower ROM selected**. I put a bank-switching gateway and stack outside 0000h–0FFFh, select ROM with OUT E2h and restore lower RAM with OUT E0h before returning to RAM code. I do not call the ROM descriptor in the RAM monitor bank.

For read/write I point IX to eight writable bytes, separate from the transfer buffer:

| Offset | My context field |
| --- | --- |
| +0..3 | Little-endian LBA28; upper nibble of byte 3 must be zero |
| +4..5 | Little-endian buffer address |
| +6 | Last sampled ATA status |
| +7 | Internal command byte |

I transfer exactly 512 bytes. The routines preserve IX and SP and clobber AF, BC, DE and HL. I check carry clear for success and carry set for failure; I do not rely on A. The routines leave the selected banks unchanged. I validate the buffer, stack and code placement myself: the raw interface does not supply partition guards, address-wrap checks, retries, write readback or cache flushes.

I disable interrupts around the call and restore the appropriate caller state afterwards. I do not call these routines concurrently or from an interrupt. IDE initialisation overwrites F800h–F9FFh and needs upper RAM there. I initialise once per device/session before transfers.

The service loader also overwrites 11D0h–11E2h and scratch at F800h–F9FFh, selects upper RAM and leaves it selected. I keep the stack outside the load region: 8000h–8FFFh for A=1 or D000h–EFFFh for A=2. On success I receive the entry in HL with carry clear; the loader does not execute it automatically. I allow AF, BC, DE, HL and IX to change and do not expect interrupt state to be preserved.

## My native SAVE redirection

In the **RAM monitor** I retain S at 0F5Eh, WRINF at 0021h and WRDAT at 0024h. For example, I use `S900093FF9000` to save 9000h–93FFh inclusive, with execution at 9000h, under `/SAVES` on FAT32.

From an application I fill the standard 128-byte header at 10F0h, call WRINF and check carry, then call WRDAT and check carry. WRINF snapshots the header without writing the disk or loading an overlay. WRDAT checks the length and source again before saving the complete header and payload. I use one known-length MZF per pair, including zero-length data blocks; I do not emulate an indefinite sequence of cassette blocks. I repeat WRINF before retrying a failed WRDAT.

I derive an 8.3 alias from the first eight title characters after leading spaces, while preserving the complete original header. I prompt before overwriting an existing ordinary file. I return A=0/carry clear on success, A=1/carry set on error, or A=2/carry set on cancellation, preserving BC, DE, HL, IX, IY and SP. I follow the original TIMFG=F0h interrupt re-enabling convention.

I accept non-empty sources in **1000h–CFFFh**, excluding the native workspace **10F0h–11F3h** and the 64 bytes below the caller's entry stack pointer plus its two-byte return address. I require the entry stack pointer within **1040h–CFFEh**, lower RAM selected and the normal upper I/O bank visible. I call serially, outside interrupt handlers.

I verify the expected partition layout before scratch writes, back up and verify all **D000h–FFFFh** in the reserved sectors, load the checksum-pinned writer, perform the save, then restore and verify that upper RAM before returning. If restoration still fails after three tries, I stay in the lower-RAM recovery path with `RAM RESTORE ERROR - R RETRIES`; I do not return through known-incomplete memory.

I currently limit `/SAVES` to 64 ordinary visible entries. I retain the old file until replacement data is verified and published, but I do not claim journalled or power-fail-atomic writes. The physical ROM's write entry points still implement tape; my GIDE write redirection depends on the card-loaded RAM monitor.
