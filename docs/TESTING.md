# Testing and validation

Release checks, emulator results and physical observations are recorded separately. Emulator success does not establish physical ATA timing, power-up behaviour or electrical margins.

## Release checks

`python3 tests/validate_release.py` checks download hashes, both decompressed card images, fixed CP/M offsets and files, matching menu variants, 23 retained ROM jump vectors, mirrored EPROM banks and raw bootstrap headers, bounds and checksums.

The firmware has been rebuilt from the public source, including an independent clean checkout and the optional CP/M toolchain build. The ROM and BASIC reproduce their recorded binary hashes. GitHub Actions validates the published artifacts, rebuilds them and checks for changes in `release/`.

The starter images contain the storage software, BASIC and fixed-volume CP/M system, without the games collection. Their emulator check is recorded separately from historical runs against the full development library.

## Emulator coverage

Monitor tests cover reset boot, bounded recovery, malformed headers, checksum rejection, bank switching, raw sector I/O and native cassette fallback. Native SAVE tests cover full headers, large blocks, source/workspace/stack exclusions, overwrite acceptance and cancellation, writer checksum rejection and recovery from an upper-RAM restore failure.

BASIC tests cover loading, programme and sequential writes, overwrite confirmation and readback-failure handling, including an ANIMALS learn/save/reload sequence. CP/M tests cover boot, volume reads and writes, console behaviour, warm boot and BDS C compile/link/run.

Selected machine-readable historical reports are retained under `evidence/emulator/`, with the tested firmware hashes. `evidence/public-image-emulator.json` records startup of the public ROM image, execution of a small machine-code programme, BASIC with 30,134 bytes free and CP/M running `VERS3`. Each case uses a disposable image and checks that its contents remain unchanged.

The full emulator integration suite is not rerun by GitHub Actions, because the custom emulator and all fixtures are outside this initial repository. CI covers the portable build and release contracts.

## Physical status

The fixed-partition CP/M system has booted on the development MZ-700, with C: and D: directory listings. The replacement Winbond EPROM has been programmed and verified, and its banner and recovery handler run on the Sharp. The matching CF image has been written and verified across its complete 85,983,232-byte populated prefix.

A successful complete ROM-to-menu boot using that updated card has not yet been recorded on the physical machine. Every native SAVE compatibility path also remains to be physically validated.

Earlier failures included device-initialisation problems and a separate adapter power-connection fault. Bounded retries provide recovery from some initialisation failures but do not demonstrate that an electrical fault has been resolved or that a particular adapter firmware is universally reliable.
