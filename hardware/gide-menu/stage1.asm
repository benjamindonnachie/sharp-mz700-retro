; SPDX-License-Identifier: GPL-3.0-or-later
; First stage: immutable code/constants, all mutable state in fixed RAM.
; BOOT_ORIGIN, STATE_BYTES, RAM symbols and common FAT routines supplied
; by build.py. The tape build runs at 8000h; ROM build at E800h.
        ORG BOOT_ORIGIN
start:
        DI
        IM 1
        LD SP,0x7F00
        XOR A
        OUT (0xE2),A
        OUT (0xE3),A
        LD HL,0x6000
        LD DE,0x6001
        LD BC,STATE_BYTES-1
        LD (HL),A
        LDIR
        LD A,0x16
        CALL putc
        LD HL,0xD800
        LD DE,0xD801
        LD BC,999
        LD (HL),0x71
        LDIR
        LD HL,waiting_text
        CALL puts
        LD A,5
        LD (init_attempts),A
initialise:
        LD A,0xA0
        OUT (0x2E),A
        CALL settle
        XOR A
        LD (post_command),A
        LD (wanted_drq),A
        CALL wait_status
        JP C,init_retry
        CALL register_test
        LD A,(reg_result)
        CP 1
        JP NZ,init_retry
        LD A,0xEC
        OUT (0x2F),A
        CALL settle
        LD A,1
        LD (post_command),A
        LD A,8
        LD (wanted_drq),A
        CALL wait_status
        JP C,init_retry
        LD HL,BUF
        LD BC,0x0028
        INIR
        LD B,0
        INIR
        XOR A
        LD (wanted_drq),A
        CALL wait_status
        JP C,init_retry
        LD A,(BUF+99)
        AND 2
        JP Z,init_retry
        LD A,(BUF+213)
        AND 0xD0
        CP 0x50
        JP Z,init_retry
        JP mount
init_retry:
        LD A,(init_attempts)
        DEC A
        LD (init_attempts),A
        JP Z,init_error
        LD D,2
init_delay_outer:
        LD BC,0
init_delay:
        DEC BC
        LD A,B
        OR C
        JP NZ,init_delay
        DEC D
        JP NZ,init_delay_outer
        JP initialise

; Common, validated MBR/BPB mount code is inserted here by the builder.
