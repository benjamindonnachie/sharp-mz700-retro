# GIDE software v0.1.1

This release replaces the withdrawn initial package with revised technical documentation and explicit co-author attribution to OpenAI Codex. Executable firmware remains V0.1.0, dated 18 November 2026. The README embedded in each card image has changed; the new images and checksums are supplied together.

The package includes the replacement monitor ROM, card-resident file manager, patched BASIC, ATA/RTC diagnostic and fixed-partition CP/M 3 build. BASIC retains 30,134 bytes free with GIDE/FAT32 LOAD, SAVE, confirmed overwrite and sequential data files.

The project was inspired by UniCard. An existing GIDE interface provided the basis for exploring IDE storage further. CP/M continues to use fixed native C:/D: volumes and the original 40-column display. CP/M FAT32 support is in development, alongside work towards recreating the SUC 80-column modification.

Separate ROM and tape starter images are supplied without the games collection. Decompress the appropriate image before writing it to a backed-up, correctly identified whole device. The menu variants are not interchangeable. Download checksums are in `release/SHA256SUMS`; uncompressed sizes and hashes are in `release/manifest.json`.

See `docs/TESTING.md` for emulator coverage and the current limits of physical validation.
