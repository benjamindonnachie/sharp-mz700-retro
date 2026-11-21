# My repository conventions

I write project documentation in the first person, as Benjamin Donnachie, using British English. I distinguish working features from plans and emulator results from physical observations. I preserve third-party notices verbatim rather than rewriting their legal wording.

I keep CP/M on its fixed native C:/D: volumes for this release. I describe CP/M FAT32 support and the SUC 80-column recreation as work in development. I do not conflate the menu/BASIC FAT32 implementation with CP/M's filesystem.

I build with `python3 tools/build.py` and validate with `python3 tests/validate_release.py`. I never use a physical card as a disposable test fixture. I keep game archives, personal backups, credentials and workstation-specific files out of this repository.
