; New GIDE loader/raw-sector API. Stock monitor primitives remain in ROM.
; IX points to an 8-byte raw I/O context: LBA28[4], buffer[2], status, command.
rom_boot:
        DI
        LD SP,0x7F00
        LD B,5
rom_boot_attempt:
        PUSH BC
        LD A,1
        CALL load_service
        POP BC
        JR NC,rom_boot_go
        DJNZ rom_boot_attempt
        JP rom_error
rom_boot_go:
        JP (HL)
rom_error:
        XOR A
        OUT (0xE3),A
        LD SP,0x10F0
        LD DE,error_text
        RST 0x18
rom_error_key:
        CALL 0x001B
        CP 0x52
        JP Z,0
        CP 0x4C
        JP Z,0x0111
        JR rom_error_key
error_text:
        DEFM "GIDE ERROR R/L"
        DB 13
load_service:
        DI
        LD IX,0x11D0
        LD (IX+15),A
        XOR A
        OUT (0xE1),A
        CALL ide_init
        JP C,service_exit
        LD A,(IX+15)
        DEC A
        JR Z,service_menu
        DEC A
        JP NZ,service_bad
        LD H,0xD0
        LD L,0
        LD B,16
        LD A,0x20
        JR service_address
service_menu:
        LD H,0x80
        LD L,0
        LD B,8
        XOR A
service_address:
        LD (IX+18),B
        LD (IX+13),L
        LD (IX+14),H
        LD (IX+0),A
        LD (IX+1),0x89
        LD (IX+2),0
        LD (IX+3),0
        LD (IX+4),0
        LD (IX+5),0xF8
        CALL ide_read
        JP C,service_exit
        LD HL,service_magic
        LD DE,0xF800
        LD B,8
service_magic_check:
        LD A,(DE)
        CP (HL)
        JP NZ,service_bad
        INC HL
        INC DE
        DJNZ service_magic_check
        LD A,(0xF811)
        CP (IX+15)
        JP NZ,service_bad
        LD HL,(0xF80A)
        LD E,(IX+13)
        LD D,(IX+14)
        OR A
        SBC HL,DE
        JP NZ,service_bad
        LD HL,(0xF80C)
        OR A
        SBC HL,DE
        JP NZ,service_bad
        LD A,(0xF810)
        OR A
        JP Z,service_bad
        CP (IX+18)
        JR Z,service_size_ok
        JP NC,service_bad
service_size_ok:
        LD (IX+8),A
        LD HL,(0xF80E)
        LD (IX+9),L
        LD (IX+10),H
        LD (IX+11),0
        LD (IX+12),0
        LD (IX+4),E
        LD (IX+5),D
service_sector:
        INC (IX+0)
        CALL ide_read
        JP C,service_exit
        LD L,(IX+4)
        LD H,(IX+5)
        LD BC,512
        LD E,(IX+11)
        LD D,(IX+12)
service_sum:
        LD A,(HL)
        ADD A,E
        LD E,A
        JR NC,service_sum_next
        INC D
service_sum_next:
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,service_sum
        LD (IX+11),E
        LD (IX+12),D
        LD (IX+4),L
        LD (IX+5),H
        DEC (IX+8)
        JP NZ,service_sector
        LD L,(IX+9)
        LD H,(IX+10)
        OR A
        SBC HL,DE
        JP NZ,service_bad
        LD L,(IX+13)
        LD H,(IX+14)
        XOR A
service_exit:
        RET
service_bad:
        LD A,1
        SCF
        RET
service_magic:
        DEFM "GIDEMN01"
ide_init:
        LD A,0xA0
        OUT (0x2E),A
        CALL ide_settle
        LD E,0
        CALL ide_wait
        RET C
        LD A,0xEC
        OUT (0x2F),A
        CALL ide_settle
        LD E,8
        CALL ide_wait
        RET C
        LD HL,0xF800
        CALL read_bytes
        LD E,0
        JP ide_wait
ide_read:
        LD A,0x20
        CALL ide_command
        RET C
ide_read_buffer:
        LD L,(IX+4)
        LD H,(IX+5)
        CALL read_bytes
        LD E,0
        JP ide_wait
read_bytes:
        LD BC,0x0028
        INIR
        LD B,0
        INIR
        RET
ide_write:
        LD A,0x30
        CALL ide_command
        RET C
ide_write_buffer:
        LD L,(IX+4)
        LD H,(IX+5)
        LD BC,0x0028
write_bytes:
        OTIR
        LD B,0
        OTIR
        LD E,0
        JP ide_wait
ide_command:
        LD (IX+7),A
        LD A,(IX+3)
        AND 0xF0
        JP NZ,ide_bad
ide_buffer_ok:
        LD E,0
        CALL ide_wait
        RET C
        LD A,(IX+3)
        OR 0xE0
        OUT (0x2E),A
        CALL ide_settle
        LD A,1
        OUT (0x2A),A
        LD A,(IX+0)
        OUT (0x2B),A
        LD A,(IX+1)
        OUT (0x2C),A
        LD A,(IX+2)
        OUT (0x2D),A
        LD A,(IX+7)
        OUT (0x2F),A
        CALL ide_settle
        LD E,8
        JP ide_wait
ide_wait:
        LD BC,0
ide_wait_loop:
        IN A,(0x26)
        LD (IX+6),A
        OR A
        JR Z,ide_wait_next
        CP 0xFF
        JR Z,ide_wait_next
        BIT 7,A
        JR NZ,ide_wait_next
        AND 0x29
        CP E
        RET Z
        AND 0x21
        JP NZ,ide_bad
ide_wait_next:
        DEC BC
        LD A,B
        OR C
        JR NZ,ide_wait_loop
ide_bad:
        LD A,1
        SCF
        RET
ide_settle:
        IN A,(0x26)
        IN A,(0x26)
        IN A,(0x26)
        IN A,(0x26)
        RET

brand_date:
        CALL 0x0006
        LD DE,brand_date_text
        RST 0x18
        JP 0x0577
brand_date_text:
        ; DATE_BYTES
