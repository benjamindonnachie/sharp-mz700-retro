# My GIDE BASIC

I have adapted NOBOMI-SOFT's UniCard BASIC MZ-5Z008 V0.1, itself derived from Sharp Quick Disk BASIC. I retain the language, editor, display and keyboard behaviour, and redirect file storage to FAT32 over GIDE at 20h. I launch `GIDEBW.MZF` from the menu's BASIC action.

I use the inherited `SD:` device spelling even though the transfers go through IDE. These are examples of my normal commands:

```basic
DIR "SD:"
INIT "SD:/BASIC"
LOAD "SD:MYPROG"
RUN
SAVE "SD:MYPROG"
WOPEN "MYDATA"
PRINT/T "AN EXAMPLE"
CLOSE
ROPEN "MYDATA"
INPUT/T A$
CLOSE
```

I use `RUN "SD:MYPROG"` when I want LOAD and RUN together. I select files by the Sharp header name, which can differ from the PC filename or the catalogue title. I use tokenised MZ-700 S-BASIC programmes; I do not assume that another BASIC dialect or a multi-block machine-code dependency will work unchanged.

## Memory I have retained

| Version | Free programme RAM at startup |
| --- | ---: |
| Original UniCard BASIC | 30,134 bytes |
| My earlier GIDE read-only build | 26,038 bytes |
| My current GIDE BASIC | **30,134 bytes** |

I recovered cassette, serial, floppy and debugger code space for the GIDE driver. I share the sector buffer and workspace between reading and writing, so I reserve no additional programme RAM relative to the UniCard version. I bank the monitor ROM out and use the RAM underneath it. An open sequential file still consumes the interpreter's normal temporary file structures until CLOSE.

## How I save and overwrite

I create 8.3 MZF files using one to eight letters, digits, underscores or hyphens. If an ordinary writable MZF/MZT already exists, I answer `OVERWRITE EXISTING FILE? (Y/N)`. **N**, Return and Break cancel. **Y** writes and verifies a new chain before switching the directory entry and releasing the old chain. I refuse hidden, system, read-only and directory entries, and ambiguous matching MZF/MZT pairs.

I need enough free space to retain the original during replacement. I do not describe the writer as journalled or power-fail atomic: a failed or interrupted save can still leave allocated clusters or inconsistent FAT copies. I keep backups and check the filesystem on the PC after an I/O failure.

## Sequential data

I redirect `WOPEN`, `PRINT/T`, `CLOSE`, `ROPEN` and `INPUT/T` to GIDE in the current directory. This supports the bare filenames used by programmes such as ANIMALS for their learned data. I preserve Sharp's native block framing inside an attribute-04h MZF. I use bare filenames or `SD:`; I have not restored explicit `CMT:` device prefixes.

I close a sequential writer before another GIDE operation. I do not support concurrent DIR, INIT, LOAD, SAVE or another OPEN while that writer is active. I limit sequential payloads to 30 KiB including framing, or 29 complete native data blocks.

## Limits I currently work within

I keep each BASIC directory within the inherited cache limit of 64 visible files and folders. I use short directory components of up to eight characters; INIT accepts up to 63 input characters, with a 127-character current path. I reload BASIC after changing media because I do not have a resident remount operation. I retain the original 85FFh programme base and FF00h ceiling.
