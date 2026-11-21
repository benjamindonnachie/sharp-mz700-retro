; SPDX-License-Identifier: GPL-3.0-or-later
; Lower-RAM monitor save gateway. It never loads code into 1000..CFFF.
; Complete D000..FFFF backup precedes overlays; complete restore precedes RET.
native_wrinf:
        DI
        PUSH HL
        PUSH DE
        PUSH BC
        XOR A
        LD (pending),A
        CALL check_range
        JR C,inf_done
        LD HL,0x10F0
        LD DE,pending_header
        LD BC,128
        LDIR
        LD A,1
        LD (pending),A
        XOR A
inf_done:
        POP BC
        POP DE
        POP HL
        PUSH AF
        LD A,(TIMFG)
        CP 0xF0
        JR NZ,inf_no_ei
        EI
inf_no_ei:
        POP AF
        RET
check_range:
        LD HL,(0x1102)
        LD A,H
        OR L
        RET Z
        LD DE,(0x1104)
        LD A,D
        CP 0x10
        JP C,save_bad
        ADD HL,DE
        JP C,save_bad
        CALL check_workspace
        RET C
        LD DE,0xD000
        OR A
        SBC HL,DE
        JR Z,range_good
        JP NC,save_bad
range_good:
        XOR A
        RET
check_workspace:
        PUSH HL
        LD BC,0x10F0
        OR A
        SBC HL,BC
        POP HL
        JR C,workspace_good
        JR Z,workspace_good
        PUSH HL
        EX DE,HL
        LD BC,0x11F4
        OR A
        SBC HL,BC
        POP HL
        JP C,save_bad
workspace_good:
        XOR A
        RET
save_bad:
        LD A,1
        SCF
        RET
native_wrdat:
        DI
        LD (caller_sp),SP
        LD SP,private_stack_end
        PUSH HL
        PUSH BC
        PUSH DE
        PUSH IX
        PUSH IY
        LD A,(pending)
        OR A
        JP Z,save_finish_bad
        XOR A
        LD (pending),A
        ; A changed live source/length is not the header which was accepted.
        LD HL,(0x1102)
        LD DE,(pending_header+18)
        OR A
        SBC HL,DE
        JP NZ,save_finish_bad
        LD HL,(0x1104)
        LD DE,(pending_header+20)
        OR A
        SBC HL,DE
        JP NZ,save_finish_bad
        OUT (0xE1),A
        CALL check_stack
        JP C,save_finish_bad
        CALL check_card_layout
        JP C,save_finish_bad
        CALL backup_upper
        JP C,save_finish_bad
        CALL load_writer
        JR C,save_overlay_failed
        LD HL,pending_header
        PUSH HL
        LD (service_low_sp),SP
        POP HL
        CALL 0xD003
save_overlay_failed:
        LD (save_result),A
        CALL restore_upper
        JP save_finish
save_finish_bad:
        LD A,1
        LD (save_result),A
        JP save_finish
save_finish:
        OUT (0xE3),A
        POP IY
        POP IX
        POP DE
        POP BC
        POP HL
        LD SP,(caller_sp)
        JP save_return_flags
save_return_flags:
        LD A,(TIMFG)
        CP 0xF0
        JR NZ,save_no_ei
        EI
save_no_ei:
        LD A,(save_result)
        OR A
        RET Z
        SCF
        RET
check_card_layout:
        ; Read the MBR as a stream, without borrowing an application buffer.
        ; The scratch LBAs are writable only on our exact partition layout.
        CALL scratch_context
        LD (IX+1),0
        LD A,0x20
        CALL rom_command
        RET C
        LD DE,446
skip_mbr_boot:
        IN A,(0x28)
        DEC DE
        LD A,D
        OR E
        JR NZ,skip_mbr_boot
        XOR A
        LD (verify_mismatch),A
        LD HL,expected_partitions
        LD B,66
compare_mbr:
        IN A,(0x28)
        CP (HL)
        JR Z,mbr_equal
        LD A,1
        LD (verify_mismatch),A
mbr_equal:
        INC HL
        DJNZ compare_mbr
        LD E,0
        CALL rom_wait
        RET C
        LD A,(verify_mismatch)
        OR A
        RET Z
        SCF
        RET
backup_upper:
        CALL scratch_context
        LD B,24
backup_sector:
        PUSH BC
        CALL rom_write
        CALL NC,verify_backup
        POP BC
        RET C
        CALL next_sector
        DJNZ backup_sector
        XOR A
        RET
scratch_context:
        LD IX,raw_context
        LD (IX+0),0
        LD (IX+1),0x8A
        LD (IX+2),0
        LD (IX+3),0
        LD (IX+4),0
        LD (IX+5),0xD0
        RET
next_sector:
        INC (IX+0)
        INC (IX+5)
        INC (IX+5)
        RET
verify_backup:
        LD A,0x20
        CALL rom_command
        RET C
        LD L,(IX+4)
        LD H,(IX+5)
        LD DE,512
        XOR A
        LD (verify_mismatch),A
verify_byte:
        IN A,(0x28)
        CP (HL)
        JR Z,verify_equal
        LD A,1
        LD (verify_mismatch),A
verify_equal:
        INC HL
        DEC DE
        LD A,D
        OR E
        JR NZ,verify_byte
        LD E,0
        CALL rom_wait
        RET C
        LD A,(verify_mismatch)
        OR A
        RET Z
        SCF
        RET
load_writer:
        CALL scratch_context
        LD (IX+0),0x21
        LD (IX+1),0x89
        LD B,WRITER_SECTORS
load_writer_sector:
        PUSH BC
        CALL rom_read
        POP BC
        RET C
        CALL next_sector
        DJNZ load_writer_sector
        LD HL,0xD000
        LD BC,WRITER_SECTORS*512
        LD DE,0
writer_sum:
        LD A,(HL)
        INC HL
        ADD A,E
        LD E,A
        JR NC,writer_sum_next
        INC D
writer_sum_next:
        DEC BC
        LD A,B
        OR C
        JR NZ,writer_sum
        LD HL,EXPECTED_WRITER_SUM
        OR A
        SBC HL,DE
        JP NZ,save_bad
        XOR A
        RET
restore_upper:
        CALL scratch_context
        LD B,24
restore_sector:
        LD A,3
        LD (restore_attempts),A
restore_try:
        PUSH BC
        CALL rom_read
        CALL NC,verify_backup
        POP BC
        JR NC,restore_good
        LD A,(restore_attempts)
        DEC A
        LD (restore_attempts),A
        JR NZ,restore_try
        ; Never return into a caller whose upper RAM is only partly restored.
        OUT (0xE3),A
        LD DE,restore_text
        CALL 0x0015
restore_key:
        CALL 0x001B
        CP 0x52
        JR NZ,restore_key
        OUT (0xE1),A
        JP restore_upper
restore_good:
        CALL next_sector
        DJNZ restore_sector
        RET
rom_read:
        LD HL,0x0D97
        JP raw_call
rom_write:
        LD HL,0x0D9A
        JP raw_call
rom_command:
        LD HL,ROM_COMMAND_ADDRESS
        JP raw_call
rom_wait:
        LD HL,ROM_WAIT_ADDRESS
        JP raw_call
raw_call:
        ; Both stack AND IX context must remain mapped while ROM is visible.
        PUSH AF
        PUSH DE
        PUSH HL
        LD A,1
        LD (raw_active),A
        LD HL,(caller_sp)
        LD DE,16
        OR A
        SBC HL,DE
        LD (raw_transfer_sp),HL
        EX DE,HL
        LD HL,raw_context
        LD BC,8
        LDIR
        POP HL
        POP DE
        POP AF
        LD (raw_low_sp),SP
        LD IX,(raw_transfer_sp)
        LD SP,(raw_transfer_sp)
        LD BC,0x006B
        PUSH BC
        JP 0x0107
bank_return:
        PUSH AF
        LD A,(raw_active)
        OR A
        JR Z,normal_return
        XOR A
        LD (raw_active),A
        LD IX,raw_context
        POP AF
        LD SP,(raw_low_sp)
        RET
normal_return:
        POP AF
        POP HL
        RET
check_stack:
        LD HL,(caller_sp)
        LD DE,0x1040
        OR A
        SBC HL,DE
        JP C,save_bad
        LD HL,(caller_sp)
        LD DE,0xCFFF
        OR A
        SBC HL,DE
        JP NC,save_bad
        ; Raw ROM calls need an ordinary mapped stack. Keep their bounded
        ; workspace outside the payload, as for any native monitor call.
        LD HL,(pending_header+18)
        LD A,H
        OR L
        RET Z
        LD DE,(pending_header+20)
        ADD HL,DE
        LD DE,(caller_sp)
        PUSH HL
        LD HL,64
        EX DE,HL
        OR A
        SBC HL,DE
        EX DE,HL
        POP HL
        OR A
        SBC HL,DE
        JP C,stack_good
        RET Z
        LD HL,(caller_sp)
        INC HL
        INC HL
        LD DE,(pending_header+20)
        OR A
        SBC HL,DE
        JR C,stack_good
        JR Z,stack_good
        JP save_bad
stack_good:
        XOR A
        RET
console_putc:
        PUSH HL
        LD HL,0x0012
        JP console_call
console_key:
        PUSH HL
        LD HL,0x001B
        JP console_call
console_line:
        PUSH HL
        LD HL,0x0003
        JP console_call
console_call:
        LD (console_high_sp),SP
        LD SP,(service_low_sp)
        OUT (0xE3),A
        CALL console_dispatch
        OUT (0xE1),A
        LD SP,(console_high_sp)
        POP HL
        RET
console_dispatch:
        JP (HL)
read_header:
        PUSH HL
        LD HL,0x006B
        PUSH HL
        LD HL,ORIGINAL_RDINF
        JP 0x0107
read_data:
        PUSH HL
        LD HL,0x006B
        PUSH HL
        LD HL,ORIGINAL_RDDAT
        JP 0x0107
verify_tape:
        PUSH HL
        LD HL,0x006B
        PUSH HL
        LD HL,ORIGINAL_VERFY
        JP 0x0107
tape_motor:
        PUSH HL
        LD HL,0x006B
        PUSH HL
        LD HL,ORIGINAL_MOTOR
        JP 0x0107
tape_stop:
        PUSH HL
        LD HL,0x006B
        PUSH HL
        LD HL,ORIGINAL_MSTOP
        JP 0x0107
play_melody:
        PUSH HL
        LD HL,0x006B
        PUSH HL
        LD HL,ORIGINAL_MELDY
        JP 0x0107
monitor_date:
        CALL 0x0006
        LD DE,monitor_date_text
        RST 0x18
        JP 0x0577
monitor_date_text:
        ; DATE_BYTES
expected_partitions:
        ; EXPECTED_PARTITIONS_BYTES
copy_s_name:
        LD B,17
copy_s_name_byte:
        INC DE
        LD A,(DE)
        LD (HL),A
        INC HL
        CP 13
        RET Z
        DJNZ copy_s_name_byte
        DEC HL
        LD (HL),13
        RET
restore_text:
        DEFM "RAM RESTORE ERROR - R RETRIES"
        DB 13
pending_header:
        DEFS 128
private_stack:
        DEFS 64
private_stack_end:
raw_context:
        DEFS 8
caller_sp: DW 0
pending: DB 0
save_result: DB 0
verify_mismatch: DB 0
restore_attempts: DB 0
raw_active: DB 0
raw_low_sp: DW 0
service_low_sp: DW 0
console_high_sp: DW 0
raw_transfer_sp: DW 0
