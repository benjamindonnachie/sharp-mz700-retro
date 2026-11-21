; SPDX-License-Identifier: GPL-3.0-or-later
; All three gateways fit the CP/M3 reserved003B-004F range. DI and stack
; operations are in high RAM before mapping; low gateways never touch SP.
install_helper:
        LD HL,helper_image
        LD DE,0x3B
        LD BC,19
        LDIR
        RET
helper_image:
        DB 0xD3,0xE3,0x7E,0xD3,0xE1,0xC9
        DB 0xD3,0xE3,0x77,0xD3,0xE1,0xC9
        DB 0xD3,0xE3,0xED,0xB0,0xD3,0xE1,0xC9
; Preserve BC/DE/HL and input flags. Original SUC scan compares row selector
; after WRITE and reads a row without disturbing those comparison flags.
mmio_write:
        PUSH BC
        PUSH DE
        PUSH HL
        PUSH AF
        LD C,A
        LD A,I
        PUSH AF
        DI
        LD A,C
        CALL 0x41
        POP AF
        JP PO,write_irq_off
        POP AF
        POP HL
        POP DE
        POP BC
        EI
        RET
write_irq_off:
        POP AF
        POP HL
        POP DE
        POP BC
        RET
mmio_read:
        PUSH BC
        PUSH DE
        PUSH HL
        PUSH AF
        LD A,I
        PUSH AF
        DI
        CALL 0x3B
        LD C,A
        POP AF
        JP PO,read_irq_off
        POP AF
        LD A,C
        POP HL
        POP DE
        POP BC
        EI
        RET
read_irq_off:
        POP AF
        LD A,C
        POP HL
        POP DE
        POP BC
        RET
; LDIR consumes BC and advances HL/DE just as a normal memory copy would.
mmio_copy:
        PUSH AF
        LD A,I
        PUSH AF
        DI
        CALL 0x47
        POP AF
        JP PO,copy_irq_off
        POP AF
        EI
        RET
copy_irq_off:
        POP AF
        RET
