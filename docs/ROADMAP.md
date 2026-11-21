# What I am working towards

- I am developing FAT32 support for CP/M. I intend to keep the working fixed-volume build available while I assess the BDOS/BIOS changes and RAM cost.
- I am looking to recreate the SUC 80-column modification for further CP/M work. I still need to complete and validate the hardware before I describe it as working.
- I want to extend physical testing of the replacement ROM, RAM monitor and native SAVE compatibility, including recovery after media errors.
- I want to make more use of the ROM helper interface without requiring an application to overwrite the data it intends to save.
- I intend to improve compatibility with staged cassette programmes and their later file loads. I do not assume every MZT/MZF becomes GIDE-compatible simply because its first block loads.

I treat these as development aims, not as features supplied by this release.
