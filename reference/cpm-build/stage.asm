LOADER_DRIVER: EQU 3192
LOADER_LBA: EQU 34817
LOADER_SECTORS: EQU 16
LOADER_SUM: EQU 21512
; SPDX-License-Identifier: GPL-3.0-or-later
; Instrumented physical-hardware bootstrap; same SD payload as CPM3-40.MZT.
BOOT_STAGE: EQU 0x7FE0
BOOT_STATUS: EQU 0x7FE1
BOOT_ERROR: EQU 0x7FE2
BOOT_LBA: EQU 0x7FE3
BOOT_REASON: EQU 0x7FE5
BOOT_SUM: EQU 0x7FE6
        ORG 0x8000
start:
        DI
        IM 1
        LD SP,0x7F00
        XOR A
        LD HL,BOOT_STAGE
        LD DE,BOOT_STAGE+1
        LD BC,15
        LD (HL),A
        LDIR
        OUT (0xE0),A
        OUT (0xE1),A
        LD HL,0
        LD (HL),A
        LD DE,1
        LD BC,0xFFF
        LDIR
        ; PPI direction and motor/interrupt masks. Stock 40-column hardware.
        OUT (0xE3),A
        LD A,0x8A
        LD (0xE003),A
        LD A,6                 ; leave PC3 low: do not toggle cassette motor
        LD (0xE003),A
        LD A,5
        LD (0xE003),A
        OUT (0xE1),A
        LD A,0x48              ; H: reading boot header
        LD (BOOT_STAGE),A
        LD DE,34816
        LD HL,0x7000
        LD A,1
        CALL read_blocks
        LD A,0x4D              ; M: checking boot magic
        LD (BOOT_STAGE),A
        LD HL,0x7000
        LD DE,magic
        LD B,8
check_magic:
        LD A,(DE)
        CP (HL)
        JP NZ,bad_magic
        INC HL
        INC DE
        DJNZ check_magic
        LD A,0x4C              ; L: reading CPMLDR
        LD (BOOT_STAGE),A
        LD DE,LOADER_LBA
        LD HL,0x100
        LD A,LOADER_SECTORS
        CALL read_blocks
        LD A,0x43              ; C: checking CPMLDR checksum
        LD (BOOT_STAGE),A
        LD HL,0x100
        LD BC,LOADER_SECTORS*512
        LD DE,LOADER_SUM
        CALL checksum
        CALL LOADER_DRIVER
        LD A,2
        LD (4),A
        LD A,3
        LD (0x7FF0),A
        JP 0x100

; DE=LBA16, HL=destination, A=sector count. Fixed boot area below 65536.
read_blocks:
        LD (remaining),A
next_block:
        LD (BOOT_LBA),DE
        PUSH DE
        PUSH HL
        LD A,0xE0
        OUT (0x2E),A
        LD BC,0x0000           ; idle, ignore stale ERR before command
        CALL wait_status
        LD A,1
        OUT (0x2A),A
        LD A,E
        OUT (0x2B),A
        LD A,D
        OUT (0x2C),A
        XOR A
        OUT (0x2D),A
        LD A,0x20
        OUT (0x2F),A
        LD BC,0x0108           ; command must produce DRQ, no ERR/DF
        CALL wait_status
        POP HL
        LD C,0x28
        LD B,0
        INIR
        LD B,0
        INIR
        LD BC,0x0100           ; transfer done: DRQ clear, no ERR/DF
        CALL wait_status
        POP DE
        INC DE
        LD A,(remaining)
        DEC A
        LD (remaining),A
        JR NZ,next_block
        RET
wait_status:
        PUSH DE
        PUSH HL
        LD HL,8
        LD DE,0
poll:
        IN A,(0x26)
        LD (BOOT_STATUS),A
        CP 0xFF
        JP Z,no_device
        BIT 7,A
        JR NZ,busy
        OR A
        JR Z,busy
        LD A,B
        OR A
        JR Z,check_drq
        LD A,(BOOT_STATUS)
        BIT 0,A
        JP NZ,ata_error
        BIT 5,A
        JP NZ,ata_fault
check_drq:
        LD A,(BOOT_STATUS)
        AND 8
        CP C
        JR Z,ready
busy:
        DEC DE
        LD A,D
        OR E
        JR NZ,poll
        DEC HL
        LD A,H
        OR L
        JR NZ,poll
        LD A,(BOOT_STATUS)
        OR A
        JP Z,no_device
        LD A,0x54              ; T: timed out
        JR reason_failed
ready:
        POP HL
        POP DE
        RET
no_device:
        LD A,0x4E              ; N: no responding device (00/FF)
        JR reason_failed
ata_error:
        LD A,0x45              ; E: ATA ERR
        JR reason_failed
ata_fault:
        LD A,0x46              ; F: ATA device fault
        JR reason_failed
bad_magic:
        LD A,0x4D
        JR reason_failed
bad_checksum:
        LD A,0x43
reason_failed:
        LD (BOOT_REASON),A
        JP failed
; Sum of padded block bytes modulo65536. Fail closed on corrupt boot blocks.
checksum:
        PUSH DE
        LD DE,0
sum_loop:
        LD A,(HL)
        ADD A,E
        LD E,A
        JR NC,no_carry
        INC D
no_carry:
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,sum_loop
        LD (BOOT_SUM),DE
        POP HL
        OR A
        SBC HL,DE
        JP NZ,bad_checksum
        RET
failed:
        DI
        LD A,0xFF
        LD (0x7FF0),A
        IN A,(0x29)
        LD (BOOT_ERROR),A
        LD A,0xFF
        OUT (0xE3),A
        LD HL,error_heading
        LD DE,0xD000
        CALL text
        LD HL,stage_label
        LD DE,0xD028
        CALL text
        LD A,(BOOT_STAGE)
        CALL character
        LD HL,reason_label
        CALL text
        LD A,(BOOT_REASON)
        CALL character
        LD HL,status_label
        LD DE,0xD050
        CALL text
        LD A,(BOOT_STATUS)
        CALL hex_byte
        LD HL,error_label
        CALL text
        LD A,(BOOT_ERROR)
        CALL hex_byte
        LD HL,lba_label
        LD DE,0xD078
        CALL text
        LD HL,0
        CALL hex_word
        LD HL,(BOOT_LBA)
        CALL hex_word
        LD HL,sum_label
        LD DE,0xD0A0
        CALL text
        LD HL,(BOOT_SUM)
        CALL hex_word
        LD HL,expected_label
        CALL text
        LD HL,LOADER_SUM
        CALL hex_word
        LD HL,header_label
        LD DE,0xD0C8
        CALL text
        LD HL,0x7000
        LD B,8
show_header:
        LD A,(HL)
        CALL hex_byte
        INC HL
        DJNZ show_header
halted:
        HALT
        JR halted
text:
        LD A,(HL)
        INC HL
        OR A
        RET Z
        CALL character
        JR text
character:
        CP 0x20
        JR Z,space
        CP 0x3A
        JR C,digit
        SUB 0x40
        JR store
space:
        XOR A
        JR store
digit:
        SUB 0x10
store:
        LD (DE),A
        INC DE
        RET
hex_word:
        LD A,H
        CALL hex_byte
        LD A,L
hex_byte:
        PUSH AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL nibble
        POP AF
nibble:
        AND 15
        ADD A,0x30
        CP 0x3A
        JR C,character
        ADD A,7
        JR character
error_heading: DEFM "GIDE BOOT ERROR"
        DB 0
stage_label: DEFM "STAGE "
        DB 0
reason_label: DEFM "  REASON "
        DB 0
status_label: DEFM "STATUS "
        DB 0
error_label: DEFM "  ERROR "
        DB 0
lba_label: DEFM "LBA "
        DB 0
sum_label: DEFM "SUM "
        DB 0
expected_label: DEFM "  EXPECT "
        DB 0
header_label: DEFM "HEADER "
        DB 0
magic: DEFM "GIDE40!!"
error_text: DB 7,9,4,5,0,2,15,15,20,0,5,18,18,15,18
remaining: DB 0
