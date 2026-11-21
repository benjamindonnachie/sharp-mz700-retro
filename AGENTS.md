# Repository conventions

Use British English and direct technical prose. Use first person only where authorship, decisions or observations call for it. Avoid repetitive personal framing and detached references to a user. Preserve third-party notices verbatim.

Keep CP/M on its fixed native C:/D: volumes for this release. Describe CP/M FAT32 support and the SUC 80-column recreation as development work. Distinguish emulator results from physical validation, and menu/BASIC FAT32 access from CP/M's filesystem.

Build with `python3 tools/build.py` and validate with `python3 tests/validate_release.py`. Use disposable images for testing; keep game archives, personal backups, credentials and workstation-specific files out of the repository.

Credit Codex as co-author in project acknowledgements and relevant commit trailers.
