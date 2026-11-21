# Monitor architecture and interface

The physical monitor occupies 4 KiB. After the original hardware initialisation, it loads a checksummed bootstrap from reserved card sectors. The bootstrap installs a 4 KiB monitor in lower RAM, selects that bank and starts the FAT32 first stage, which loads the main file manager from `MENU.MZF`.

All 23 original public jump vectors retain their addresses and vector bytes. The physical ROM preserves the original console, keyboard, timer, sound and tape implementations. In the RAM monitor, native write helpers are redirected to GIDE; cassette read/verify and melody calls are forwarded to the physical ROM through bank-safe gateways.

The RAM monitor retains J, L, M, V, D and B. **G**, **F** and **#** return to GIDE. The obsolete printer self-test is removed. Reset selects the physical ROM and reloads the RAM monitor, including after an application has overwritten lower RAM.

## Reserved sectors

| Slot | LBA |
| --- | --- |
| Bootstrap header | 8900h |
| Bootstrap payload, at most eight sectors | 8901h onwards |
| SAVE service header | 8920h |
| SAVE service payload, at most sixteen sectors | 8921h onwards |
| Lower RAM monitor | 8941h–8948h |
| Temporary upper-RAM backup, twenty-four sectors | 8A00h–8A17h |

The service header contains `GIDEMN01`, a service identifier, fixed load/entry addresses, a bounded non-zero sector count and a 16-bit sum of the padded payload. These checks detect accidental corruption; they do not authenticate code.

## Physical ROM API

The descriptor at **0D8Eh** contains `GIDE`, API version 1 and flags 0Fh, followed by these jump entries:

| Entry | Routine |
| --- | --- |
| 0D94h | Initialise IDE |
| 0D97h | Read 512 bytes |
| 0D9Ah | Write 512 bytes |
| 0D9Dh | Load service: A=1 bootstrap, A=2 SAVE service |
| 0DA0h | Boot GIDE |
| 0DA3h | Native tape-load fallback |

The physical lower ROM must be selected. A bank-switching gateway and its stack must reside outside 0000h–0FFFh: select ROM with OUT E2h, call the entry, then restore lower RAM with OUT E0h before returning to RAM code. This descriptor is not available in the RAM monitor bank.

For sector reads and writes, IX points to eight writable bytes outside the transfer buffer:

| Offset | Context field |
| --- | --- |
| +0..3 | Little-endian LBA28; the upper nibble of byte 3 must be zero |
| +4..5 | Little-endian buffer address |
| +6 | Last sampled ATA status |
| +7 | Internal command byte |

Each transfer covers exactly 512 bytes. IX and SP are preserved; AF, BC, DE and HL are clobbered. Carry clear indicates success and carry set failure; A is unspecified. Memory-bank selection is unchanged. Buffer placement, address wrap, partition protection and overlap with live code, context or stack are the caller's responsibility.

The raw interface provides no automatic retry, write readback or cache flush. Interrupts must be disabled during calls and restored appropriately afterwards. Concurrent or interrupt-handler calls are unsupported. Initialisation overwrites F800h–F9FFh, requires upper RAM there and should precede transfers once per device/session.

## Service loader

The loader overwrites 11D0h–11E2h and scratch at F800h–F9FFh. It selects upper RAM and leaves it selected. The stack must remain outside the load region: 8000h–8FFFh for A=1 or D000h–EFFFh for A=2, and outside the scratch buffer in either case.

On success, HL contains the service entry and carry is clear. The service is not executed automatically. AF, BC, DE, HL and IX are clobbered; interrupt state is not preserved.

## Native SAVE redirection

In the **RAM monitor**, S at 0F5Eh, WRINF at 0021h and WRDAT at 0024h retain their entry addresses. For example, `S900093FF9000` saves 9000h–93FFh inclusive, with execution at 9000h, as an MZF under `/SAVES`.

An application fills the standard 128-byte header at 10F0h, calls WRINF and checks carry, then calls WRDAT and checks carry. WRINF snapshots the header without disk writes or overlays. WRDAT rechecks the length and source before saving the complete header and payload. Each pair produces one known-length MZF, including zero-length data blocks; indefinite cassette block streams are not emulated. WRINF must be repeated before retrying a failed WRDAT.

The FAT alias is derived from the first eight title characters after leading spaces, while the complete original header is retained. Existing ordinary files require overwrite confirmation. Results are A=0/carry clear for success, A=1/carry set for error and A=2/carry set for cancellation. BC, DE, HL, IX, IY and SP are preserved. Interrupt re-enabling follows the original TIMFG=F0h convention.

Non-empty sources must lie within **1000h–CFFFh**, excluding **10F0h–11F3h** and the 64 bytes below the caller's entry SP plus its two-byte return address. Entry SP must be within **1040h–CFFEh**, with lower RAM selected and the normal upper I/O bank visible. Calls must be serial and outside interrupt handlers.

Before scratch writes, the expected partition layout is checked. All **D000h–FFFFh** is backed up and verified in the reserved sectors before the checksum-pinned writer is loaded. After saving, upper RAM is restored and verified before return. If restoration fails after three attempts, execution remains in lower RAM at `RAM RESTORE ERROR - R RETRIES`; it does not return through known-incomplete memory.

The save directory is currently limited to 64 ordinary visible entries. Replacement data is written and verified before publication, but the filesystem is not journalled or power-fail atomic. These GIDE write services depend on the RAM monitor; the physical ROM's original write helpers remain cassette routines.
