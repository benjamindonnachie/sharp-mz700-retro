; Read-only ATA initialisation while the monitor ROM/I/O mapping is active.
; Matches GIDETEST's A0h device selection and IDENTIFY transfer. It omits
; GIDETEST's task-register pattern test, RTC tests and sector reads.
prime_identify:
        LD A,0x49              ; I: device initialisation / IDENTIFY
        LD (BOOT_STAGE),A
        LD A,0xA0
        OUT (0x2E),A
        CALL prime_settle
        LD BC,0x0000           ; idle, ignore stale ERR/DF
        CALL wait_status
prime_command:
        LD A,0xEC
        OUT (0x2F),A
        CALL prime_settle
        LD BC,0x0108
        CALL wait_status
        LD HL,0x7200           ; retain IDENTIFY separately from boot header
        LD C,0x28
        LD B,0
        INIR
        LD B,0
        INIR
        LD BC,0x0100
        CALL wait_status
        RET
prime_settle:
        IN A,(0x26)
        IN A,(0x26)
        IN A,(0x26)
        IN A,(0x26)
        RET
