; SPDX-License-Identifier: GPL-3.0-or-later
; Native fixed-disk driver adapted from cpm/gide/resident.asm.
select:
        LD A,C
        CP 2
        JR Z,select_c
        CP 3
        JR Z,select_d
        LD HL,0
        RET
select_c:
        LD A,1
        LD HL,dph_c
        JR select_hd
select_d:
        LD A,2
        LD HL,dph_d
select_hd:
        PUSH AF
        PUSH HL
        LD A,0xE0
        OUT (0x2E),A
        CALL ata_idle
        POP HL
        JR C,select_failed
        POP AF
        LD (active),A
        RET
select_failed:
        POP AF
        LD HL,0                   ; leave the previous active device intact
        RET

disk_home:
        LD BC,0
set_track:
        LD (track),BC
        RET
set_dma:
        LD (dma_address),BC
        RET

set_sector:
        LD (physical_sector),BC
        RET

read:
        CALL physical_address
        JR C,io_error
        CALL ata_read
        JR C,io_error
        XOR A
        RET
write:
        CALL physical_address
        JR C,io_error
        CALL ata_write
        JR C,io_error
        XOR A
        RET
io_error:
        LD A,1
        RET

; SETSEC supplies physical sector 0..31. DPB SPT remains 128 records.
; C/D retain the existing 8MiB on-disk layout without conversion.
physical_address:
        LD HL,(track)
        LD A,H
        CP 2
        JR NC,address_error
        LD A,(physical_sector+1)
        OR A
        JR NZ,address_error
        LD A,(physical_sector)
        CP 32
        JR NC,address_error
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        LD E,A
        LD D,0
        ADD HL,DE
        LD A,(active)
        CP 2
        JR NZ,address_c
        SET 6,H
address_c:
        LD (lba),HL
        OR A
        RET
address_error:
        SCF
        RET

; Bounded polling: C flag means failure. Alternate status preserves GIDE LH.
ata_idle:
        LD BC,0x8000
idle_loop:
        IN A,(0x26)
        CP 0xFF
        JR Z,ata_error
        OR A
        JR Z,ata_error
        AND 0xC8
        CP 0x40
        RET Z
        DEC BC
        LD A,B
        OR C
        JR NZ,idle_loop
ata_error:
        SCF
        RET
ata_drq:
        LD BC,0x8000
wait_loop:
        IN A,(0x26)
        CP 0xFF
        JR Z,ata_error
        OR A
        JR Z,ata_error
        BIT 7,A
        JR NZ,wait_again
        AND 0x29                  ; DF, DRQ, ERR
        CP 8
        RET Z
        AND 0x21
        JR NZ,ata_error
wait_again:
        DEC BC
        LD A,B
        OR C
        JR NZ,wait_loop
        JR ata_error
issue:
        PUSH AF
        CALL ata_idle
        JR C,issue_error
        LD A,0xE0
        OUT (0x2E),A               ; master, LBA28
        LD A,1
        OUT (0x2A),A
        LD HL,(lba)
        LD A,L
        OUT (0x2B),A
        LD A,H
        OUT (0x2C),A
        XOR A
        OUT (0x2D),A
        POP AF
        OUT (0x2F),A               ; task register establishes low-byte phase
        JP ata_drq
issue_error:
        POP AF
        SCF
        RET
ata_read:
        LD A,0x20
        CALL issue
        RET C
        LD HL,(dma_address)
        LD C,0x28
        LD B,0
        INIR
        LD B,0
        INIR
        JR transfer_done
ata_write:
        LD A,0x30
        CALL issue
        RET C
        LD HL,(dma_address)
        LD C,0x28
        LD B,0
        OTIR
        LD B,0
        OTIR
        CALL ata_idle
        RET C
transfer_done:
        IN A,(0x2F)
        AND 0x29                  ; BSY, DF, DRQ, ERR must all be clear
        RET Z
        SCF
        RET

; Complete CP/M3 non-banked disk structures.
; One shared directory BCB and one shared data BCB, each with its own
; 512-byte buffer. Non-banked BDOS tags ownership and flushes dirty data
; before replacement. Alternating C/D random writes are regression-tested.
track: DW 0
dma_address: DW 0x80
active: DB 0
lba: DW 0
physical_sector: DW 0
; XLT0, scratch2..10, MF11, DPB12, CSV14, ALV16,
; DIRBCB18, DTABCB20, HASH22, HBANK24.
dph_c:  DW 0,0,0,0,0
        DB 0,0
        DW dpb,0,allocation_c,dir_bcb,data_bcb,0xFFFF
        DB 0
dph_d:  DW 0,0,0,0,0
        DB 0,0
        DW dpb,0,allocation_d,dir_bcb,data_bcb,0xFFFF
        DB 0
dpb:    DW 128
        DB 5,31,1
        DW 2047,511
        DB 0xF0,0
        DW 0,0
        DB 2,3
; BCB: DRV, REC[3], WFLG, reserved, TRACK[2], SECTOR[2], BUFFAD[2].
dir_bcb: DB 0xFF,0,0,0,0,0
        DW 0,0,directory_buffer
data_bcb: DB 0xFF,0,0,0,0,0
        DW 0,0,data_buffer
allocation_c: DS 256
allocation_d: DS 256
directory_buffer: DS 512
data_buffer: DS 512
resident_end: DB 0
bank_test_area: DS 64
high_stack_base: DS 64
high_stack_end: DB 0
