# GIDE BASIC

The patched interpreter is based on NOBOMI-SOFT's UniCard MZ-5Z008 V0.1, derived from Sharp Quick Disk BASIC. The language, editor, display and keyboard routines are retained; file access is redirected to FAT32 through GIDE at 20h. The file manager's BASIC action launches `GIDEBW.MZF`.

The inherited device name remains `SD:`, although transfers use IDE:

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

`RUN "SD:MYPROG"` combines LOAD and RUN. File selection uses the Sharp header name, which may differ from the PC filename or catalogue title. Compatible tokenised MZ-700 S-BASIC programmes can be loaded directly; other dialects, additional tape blocks and machine-code dependencies need separate assessment.

## Memory

| Build | Free programme RAM at startup |
| --- | ---: |
| Original UniCard BASIC | 30,134 bytes |
| Earlier GIDE read-only build | 26,038 bytes |
| Current GIDE BASIC | **30,134 bytes** |

The driver occupies reclaimed cassette, serial, floppy and debugger code space. Reading and writing share the sector buffer and workspace, leaving the original programme base at 85FFh and ceiling at FF00h. The monitor ROM is banked out to expose lower RAM. An open sequential file still uses the interpreter's normal temporary file structures until CLOSE.

## SAVE and overwrite

SAVE creates an MZF using an 8.3 filename: one to eight letters, digits, underscores or hyphens. For an existing ordinary writable MZF/MZT, `OVERWRITE EXISTING FILE? (Y/N)` requests confirmation. **N**, Return and Break cancel without replacing it. **Y** writes and verifies a new cluster chain before switching the directory entry and releasing the old chain.

Hidden, system, read-only and directory entries are refused, as are ambiguous matching MZF/MZT pairs. Replacement needs enough free space to retain the original while the new data is written.

The filesystem is not journalled or power-fail atomic. Interrupted saves can leave allocated clusters or inconsistent FAT copies; retain a backup and check the filesystem on a PC after an I/O failure.

## Sequential files

`WOPEN`, `PRINT/T`, `CLOSE`, `ROPEN` and `INPUT/T` use GIDE in the current directory. This supports bare filenames used by programmes such as ANIMALS for learned data. Sharp's block framing is retained inside an attribute-04h MZF. Bare filenames and `SD:` are supported; explicit `CMT:` prefixes are not.

Close an active sequential writer before DIR, INIT, LOAD, SAVE or another OPEN. Concurrent GIDE operations are not supported. The sequential payload limit is 30 KiB including framing, allowing 29 complete native data blocks.

## Limits

The inherited BASIC directory cache holds 64 visible files and folders. Directory components use short names of up to eight characters; INIT accepts 63 input characters and the current path is limited to 127. BASIC must be reloaded after changing media because no resident remount operation is provided.
