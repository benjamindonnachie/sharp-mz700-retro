# GIDE diagnostics

`GIDETST.MZF` provides task-register pattern tests, IDENTIFY information, repeated sector reads and RTC checks. The clock display reads the RTC registers directly and checks that seconds advance. A setting option accepts a validated date/time in the range 1978–2077.

Enter the RTC value as `YYYYMMDDHHMMSS`, for example `20261121143000`. The diagnostic verifies the readback; a successful setting alone does not establish that the clock continues counting.

## Optional sector write test

The address prompt accepts **eight hexadecimal LBA digits**, not a data pattern. The test requires an explicit `WRITE` confirmation. The final sector is not necessarily unused, and any selected sector may contain filesystem data.

The original sector is read twice into RAM and the copies compared. Five patterns are then written and verified before the original is restored and checked by readback. If restoration fails, the RAM backup is retained and another restoration attempt is offered.

Do not reset, switch off or remove the card while a failed restoration is pending. Take an independent backup before using the test: a RAM copy cannot protect the original sector against power loss during the operation.
