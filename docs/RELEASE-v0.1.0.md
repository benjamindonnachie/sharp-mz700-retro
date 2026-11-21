# My first Sharp MZ-700 retro release

I am publishing my GIDE boot monitor and card-resident menu, patched GIDE BASIC, RTC/ATA diagnostic and working fixed-partition CP/M 3 build.

I took inspiration from UniCard, but I already had a GIDE interface and chose to explore that route further. I keep the 4 KiB ROM small and load the RAM monitor and main menu from the card. My BASIC patch retains 30,134 bytes free while supporting LOAD, SAVE, confirmed overwrite and sequential data files through GIDE/FAT32.

For CP/M I use the fixed native C:/D: volumes and original 40-column screen. My CP/M FAT32 version is in development. I am also looking to recreate the SUC 80-column modification for further CP/M work.

I have included separate ROM and tape starter images, without my game collection. I decompress the image for my chosen boot arrangement and write it to a backed-up, correctly identified whole device. I do not mix the ROM and tape menu variants. I check the compressed downloads with `SHA256SUMS` and the uncompressed sizes/hashes in `manifest.json`.

I retain the 18 November 2026 ROM banner date; I publish this repository release on 21 November 2026. I document the emulator checks and the limits of my physical testing in `docs/TESTING.md`.
