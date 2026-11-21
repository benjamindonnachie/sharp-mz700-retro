# Development priorities

- **CP/M FAT32 support:** assess the filesystem changes, shared buffers and RAM cost while retaining the fixed-volume build as a working baseline.
- **SUC 80-column recreation:** complete and validate the hardware for further CP/M work. The present release remains compatible with the original display.
- **Physical firmware validation:** extend testing of the ROM boot path, RAM monitor, native SAVE entry points and recovery from media errors.
- **ROM helper interface:** provide useful storage services without overwriting application data that needs to be saved.
- **Staged software loading:** improve support for programmes that expect additional cassette blocks after their initial load.

These are development objectives, not features claimed by the current release.
