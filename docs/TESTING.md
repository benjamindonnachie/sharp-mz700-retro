# What I have tested

I distinguish byte-level release checks, tests in my native PAL MZ-700 emulator and observations on my physical Sharp. I do not treat a passing emulator run as proof of physical ATA timing or power-up behaviour.

## My release checks

I run `python3 tests/validate_release.py` against the published files. I check both decompressed card images, every download checksum, the fixed CP/M partition offsets and files, the two menu variants, the ROM's 23 retained public jump vectors, the sixteen mirrored EPROM banks, and the raw bootstrap headers, counts and checksums. I also rebuild the firmware from the staged public source and compare it with the known ROM and BASIC hashes.

I keep the public starter images separate from my personal card: I include the storage software, CP/M utilities and BASIC, but no game catalogue or game payloads. I record a separate emulator check for these starter images rather than assume that my full-library image's hash applies to them.

## My emulator work

Before publication I tested the monitor and its native SAVE redirection in my custom `mz700emu-pal` build. I exercised reset boot, bounded recovery, malformed raw headers, checksum rejection, bank switching, raw sector I/O and native cassette fallback. For SAVE I exercised full headers, large source blocks, source/workspace/stack exclusion, overwrite acceptance and cancellation, writer checksum failure and recovery after a failed upper-RAM restore.

I tested GIDE BASIC loading, programme and sequential data writes, confirmed overwrite and readback-failure handling. I also ran sample BASIC programmes, including an ANIMALS learn/save/reload sequence. I tested CP/M boot, native volume reads and writes, its console, warm boot and BDS C compile/link/run. I retain selected machine-readable results under `evidence/`; those historic reports identify their tested firmware hashes and are not new claims of hardware validation.

My emulator tests use disposable disk images. I have not included the emulator and all its historical test fixtures in this initial repository, so the GitHub workflow checks the portable build and release contracts rather than claiming to rerun that complete integration suite.

## My physical observations

I have run the fixed-partition CP/M build on my MZ-700 and listed both C: and D:. I have programmed and verified the replacement Winbond EPROM, and its banner and GIDE recovery handler run on the Sharp. I updated the CF card with the matching raw bootstrap and RAM monitor and verified its entire 85,983,232-byte populated prefix by readback.

At this publication I have not recorded a successful full ROM-to-menu boot on the physical Sharp using that updated card. I have also not physically verified every native SAVE compatibility path. I will update these notes when I have those results.

I have previously seen both device-initialisation failures and a separate power-connection fault. I have bounded retries, but I do not interpret them as evidence that an electrical fault is fixed or that a particular adapter firmware is universally reliable.
