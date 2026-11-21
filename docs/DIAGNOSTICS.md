# How I use my GIDE diagnostic

I launch `GIDETST.MZF` from the menu. I use its task-register patterns, IDENTIFY information and repeated sector reads to separate device communication from filesystem or boot-image problems. I display the RTC directly from its registers, check that seconds advance, and can set a validated date/time in the range 1978–2077.

I enter a new RTC value as `YYYYMMDDHHMMSS`; for example, `20261121143000`. I check the resulting readback rather than assuming an accepted input proves that the RTC is counting.

## My optional write test

I keep the sector write test optional and require an explicit `WRITE` confirmation. I enter a sector number as **eight hexadecimal LBA digits**; that input is an address, not the data pattern to write. I do not assume that the last sector is unused or choose a live filesystem sector casually.

I read the original sector twice into RAM and compare the copies, write and read back five test patterns, then restore and verify the original data. If restoration fails, I retain the backup in RAM and offer another restoration attempt. I do not reset, switch off or remove the card while a failed restoration is pending.

I still take an independent card backup first. A RAM backup cannot protect the original sector if I lose power during the test. I do not use this test as a substitute for checking the complete card image after installing the boot software.
