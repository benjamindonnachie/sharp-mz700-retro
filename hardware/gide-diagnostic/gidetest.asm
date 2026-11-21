; SPDX-License-Identifier: GPL-3.0-or-later
; Sharp MZ-700 monitor diagnostic for GIDE, base 20h.
; Default tests are read-only. W explicitly confirms a single-sector write
; test with two RAM backup copies and verified restoration on every exit.
; Uses stock 1Z-013A ROM: PRINT 0012, LETNL 0006, GETKY 001B.
        ORG 0x1200
BASE:   EQU 0x20
DATA:   EQU BASE+8
STATUS: EQU BASE+15
ALT:    EQU BASE+6
RTC:    EQU BASE+5

start:
        DI
        LD SP,stack_top
        XOR A
        LD (device),A
restart:
        XOR A
        LD (phase),A
        LD HL,results
        LD B,results_end-results
clear_results:
        LD (HL),A
        INC HL
        DJNZ clear_results
        INC A
        LD (phase),A
        CALL new_screen
        LD HL,title
        CALL puts
        LD A,(device)
        OR A
        LD HL,master_text
        JR Z,device_text
        LD HL,slave_text
device_text:
        CALL puts
        CALL ata_test
        CALL rtc_test
        LD HL,menu_text
        CALL puts
        LD A,2
        LD (phase),A
menu:
        CALL 0x001B
        OR A
        JR Z,menu
        AND 0xDF
        CP 0x51
        JP Z,0
        CP 0x4D
        JR Z,choose_master
        CP 0x53
        JR Z,choose_slave
        CP 0x52
        JP Z,restart
        CP 0x49
        JR Z,initialise_rtc
        CP 0x54
        JP Z,set_clock
        CP 0x48
        JP Z,main_menu
        CP 0x57
        JP Z,write_menu
        CP 0x43
        JP Z,live_clock
        JR menu
main_menu:
        XOR A
        LD (phase),A
        CALL key_release
        CALL new_screen
        LD HL,title
        CALL puts
        LD HL,main_text
        CALL puts
        LD A,(device)
        OR A
        LD HL,master_text
        JR Z,main_selected
        LD HL,slave_text
main_selected:
        CALL puts
        LD A,2
        LD (phase),A
        JP menu
initialise_rtc:
        ; Reh's RTCinit: 24-hour mode, reset pulse, release HOLD.
        ; Does not programme calendar digits. Explicit user action only.
        LD BC,0x0F00+RTC
        LD A,5
        OUT (C),A
        DEC A
        OUT (C),A
        LD B,0x0D
        XOR A
        OUT (C),A
        CALL key_release
        JP restart
choose_master:
        XOR A
        JR choose
choose_slave:
        LD A,0x10
choose:
        LD (device),A
        CALL key_release
        JP restart
key_release:
        CALL 0x001B
        OR A
        JR NZ,key_release
        RET

ata_test:
        LD A,(device)
        OR 0xA0
        OUT (BASE+14),A
        CALL settle
        CALL wait_idle
        JP C,ata_failure
        CALL register_test
        LD HL,register_text
        CALL puts
        LD A,(reg_result)
        CP 1
        LD HL,pass_text
        JR Z,register_report
        LD HL,fail_text
register_report:
        CALL puts
        LD A,0xEC
        OUT (STATUS),A
        CALL settle
        CALL wait_drq
        JP C,ata_failure
        LD HL,identify
        CALL transfer
        CALL wait_done
        JP C,ata_failure
        LD A,1
        LD (identify_result),A
        LD HL,identify_text
        CALL puts
        ; ATA strings are stored high character then low character per word.
        LD HL,identify+54
        LD B,16
model_loop:
        INC HL
        LD A,(HL)
        CALL printable
        DEC HL
        LD A,(HL)
        CALL printable
        INC HL
        INC HL
        DJNZ model_loop
        CALL newline
        LD HL,identify+120
        LD DE,capacity
        LD BC,4
        LDIR
        LD HL,capacity_text
        CALL puts
        LD HL,capacity
        CALL hex32
        CALL newline
identify_features:
        LD A,(identify+99)
        AND 2
        JP Z,unsupported
        ; ATA word 106: valid 01 in bits 15:14 and bit 12 set means
        ; logical sectors longer than 256 words. This tool transfers 512 bytes.
        LD A,(identify+213)
        AND 0xD0
        CP 0x50
        JP Z,unsupported
        ; LBA28 needs a nonzero count no larger than 10000000h sectors.
        LD HL,capacity
        LD A,(HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        JP Z,unsupported
        LD A,(capacity+3)
        CP 0x10
        JR C,capacity_ok
        JR NZ,cap_limit
        LD HL,capacity
        LD A,(HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        JR Z,capacity_ok
cap_limit:
        LD HL,limit_text
        CALL puts
        LD HL,0
        LD (capacity),HL
        LD HL,0x1000
        LD (capacity+2),HL
capacity_ok:
        LD HL,reads_text
        CALL puts
        LD HL,0
        LD (lba),HL
        LD (lba+2),HL
        CALL test_sector
        JP C,ata_failure
        LD HL,(capacity+2)
        LD A,H
        OR L
        JR NZ,sector_one
        LD HL,(capacity)
        DEC HL
        LD A,H
        OR L
        JR Z,last_sector
sector_one:
        LD HL,1
        LD (lba),HL
        CALL test_sector
        JP C,ata_failure
last_sector:
        LD HL,capacity
        LD DE,lba
        LD BC,4
        LDIR
        LD HL,lba
        LD B,4
subtract_one:
        LD A,(HL)
        SUB 1
        LD (HL),A
        JR NC,last_ready
        INC HL
        DJNZ subtract_one
last_ready:
        CALL test_sector
        JP C,ata_failure
        LD A,(reg_result)
        CP 1
        LD A,1
        JR Z,ata_pass
        LD A,2
ata_pass:
        LD (ata_result),A
        LD HL,stable_text
        JP puts
unsupported:
        LD A,4
        LD (ata_result),A
        LD HL,unsupported_text
        JP puts
ata_failure:
        LD A,(fault)
        CP 1
        LD A,2
        JR NZ,ata_fail_store
        LD A,3
ata_fail_store:
        LD (ata_result),A
        LD HL,ata_fail_text
        CALL puts
        LD A,(fault)
        CALL hex8
        LD HL,status_text
        CALL puts
        LD A,(last_status)
        CALL hex8
        LD HL,error_text
        CALL puts
        IN A,(BASE+9)
        CALL hex8
        JP newline

; Return carry on failure. fault: 1 absent, 2 timeout, 3 ATA error,
; 5 repeat mismatch. DRQ stuck after transfer is reported as timeout (2).
wait_idle:
        LD E,0x80
        JR wait_start
wait_drq:
        LD E,8
        JR wait_start
wait_done:
        LD E,0
wait_start:
        LD D,8
        LD BC,0
wait_loop:
        IN A,(ALT)
        LD (last_status),A
        OR A
        JR Z,absent
        CP 0xFF
        JR Z,absent
        BIT 7,A
        JR NZ,wait_next
        ; Ignore stale ERR/DF before a new command, check after a command.
        LD A,E
        CP 0x80
        JR Z,idle_check
        LD A,(last_status)
        AND 0x21
        JR NZ,device_error
idle_check:
        LD A,(last_status)
        AND 8
        LD H,A
        LD A,E
        AND 8
        CP H
        RET Z
wait_next:
        DEC BC
        LD A,B
        OR C
        JR NZ,wait_loop
        DEC D
        JR NZ,wait_loop
        LD A,2
        JR set_fault
absent:
        LD A,1
        JR set_fault
device_error:
        LD A,3
set_fault:
        LD (fault),A
        SCF
        RET
settle:
        IN A,(ALT)
        IN A,(ALT)
        IN A,(ALT)
        IN A,(ALT)
        RET
transfer:
        ; Two INIR blocks transfer 512 bytes, preserving low/high pairing.
        ; No task-register polling is permitted between paired data bytes.
        LD C,DATA
        LD B,0
        INIR
        LD B,0
        INIR
        RET

register_test:
        LD HL,saved_task
        LD C,BASE+10
        LD B,4
save_task:
        IN A,(C)
        LD (HL),A
        INC HL
        INC C
        DJNZ save_task
        LD A,1
        LD (reg_result),A
        LD HL,patterns
        LD D,12
pattern_loop:
        LD C,BASE+10
        LD B,4
pattern_reg:
        LD A,(HL)
        OUT (C),A
        IN A,(C)
        CP (HL)
        JR Z,pattern_match
        LD A,2
        LD (reg_result),A
pattern_match:
        INC C
        DJNZ pattern_reg
        INC HL
        DEC D
        JR NZ,pattern_loop
        LD HL,saved_task
        LD C,BASE+10
        LD B,4
restore_task:
        LD A,(HL)
        OUT (C),A
        INC HL
        INC C
        DJNZ restore_task
        RET

read_sector:
        CALL wait_idle
        RET C
        CALL setup_sector
        LD A,0x20
        OUT (STATUS),A
        CALL settle
        CALL wait_drq
        RET C
        LD HL,sector
        CALL transfer
        CALL wait_done
        RET C
        LD HL,(read_count)
        INC HL
        LD (read_count),HL
        OR A
        RET
setup_sector:
        LD A,(lba+3)
        AND 0x0F
        LD H,A
        LD A,(device)
        OR H
        OR 0xE0
        OUT (BASE+14),A
        CALL settle
        LD A,1
        OUT (BASE+10),A
        LD A,(lba)
        OUT (BASE+11),A
        LD A,(lba+1)
        OUT (BASE+12),A
        LD A,(lba+2)
        OUT (BASE+13),A
        RET
test_sector:
        CALL read_sector
        RET C
        LD HL,sector
        LD DE,reference
        LD BC,512
        LDIR
        LD A,7
        LD (repeats),A
repeat_read:
        CALL read_sector
        RET C
        LD HL,sector
        LD DE,reference
        LD BC,512
compare_byte:
        LD A,(DE)
        CP (HL)
        JR NZ,mismatch
        INC HL
        INC DE
        DEC BC
        LD A,B
        OR C
        JR NZ,compare_byte
        LD A,(repeats)
        DEC A
        LD (repeats),A
        JR NZ,repeat_read
        LD HL,lba
        CALL hex32
        LD HL,sum_text
        CALL puts
        LD HL,sector
        LD DE,0
        LD BC,512
sum_loop:
        LD A,(HL)
        ADD A,E
        LD E,A
        JR NC,sum_no_carry
        INC D
sum_no_carry:
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,sum_loop
        LD (last_sum),DE
        LD A,D
        CALL hex8
        LD A,E
        CALL hex8
        LD HL,eight_text
        CALL puts
        OR A
        RET
mismatch:
        LD (mismatch_address),HL
        LD A,5
        JP set_fault

; Optional single-sector write test. A dedicated backup and its guard copy
; are never used as transfer buffers. No normal-menu return until restored.
write_menu:
        XOR A
        LD (phase),A
        LD (write_result),A
        CALL key_release
        CALL new_screen
        LD HL,title
        CALL puts
        LD HL,write_heading
        CALL puts
        LD A,(ata_result)
        CP 1
        JP NZ,write_unavailable
        ; Write-cache enabled but no declared FLUSH support: refuse before
        ; altering media, because readback alone cannot establish persistence.
        XOR A
        LD (flush_required),A
        LD A,(identify+167)
        AND 0xD0
        CP 0x50
        JR NZ,check_cache
        LD A,1
        LD (flush_required),A
check_cache:
        LD A,(identify+170)
        AND 0x20
        JR Z,write_select
        LD A,(flush_required)
        OR A
        JP Z,write_cache_refused
write_select:
        ; Default is the final addressable sector, NOT assumed to be free.
        LD HL,capacity
        LD DE,lba
        LD BC,4
        LDIR
        LD HL,lba
        LD B,4
write_last:
        LD A,(HL)
        SUB 1
        LD (HL),A
        JR NC,write_show_target
        INC HL
        DJNZ write_last
write_show_target:
        LD A,(device)
        OR A
        LD HL,master_text
        JR Z,write_selected
        LD HL,slave_text
write_selected:
        CALL puts
        LD HL,write_default
        CALL puts
        LD HL,lba
        CALL hex32
        CALL newline
        LD HL,write_lba_prompt
        CALL puts
        LD A,7
        LD (phase),A
        LD DE,input_line
        CALL 0x0003
        LD A,(input_line)
        CP 0x1B
        JP Z,main_menu
        CALL parse_lba
        JP C,write_bad_lba
        CALL key_release
        LD HL,write_confirm
        CALL puts
        LD HL,lba
        CALL hex32
        CALL newline
        LD HL,write_risk
        CALL puts
        LD A,8
        LD (phase),A
        LD DE,input_line
        CALL 0x0003
        LD HL,input_line
        LD DE,confirm_word
        LD B,6
confirm_loop:
        LD A,(DE)
        CP (HL)
        JP NZ,main_menu
        INC DE
        INC HL
        DJNZ confirm_loop
        CALL key_release
        XOR A
        LD (write_result),A
        LD (backup_valid),A
        LD (pattern_passed),A
        LD (pattern_failed),A
        LD (write_fault),A
        LD (pattern_index),A
        LD A,4
        LD (phase),A
        CALL new_screen
        LD HL,title
        CALL puts
        LD HL,write_target
        CALL puts
        LD HL,lba
        CALL hex32
        CALL newline
        CALL read_sector
        JP C,backup_failed
        LD HL,sector
        LD DE,backup
        LD BC,512
        LDIR
        LD HL,backup
        LD DE,backup_guard
        LD BC,512
        LDIR
        CALL read_sector
        JP C,backup_failed
backup_verify:
        LD DE,backup
        CALL compare_sector
        JP C,backup_failed
        LD A,1
        LD (backup_valid),A
        LD HL,backup_ok_text
        CALL puts
write_patterns:
        CALL fill_pattern
        LD HL,reference
        LD (write_source),HL
        CALL write_sector
        JP C,on_pattern_failure
        CALL read_sector
        JP C,on_pattern_failure
pattern_verify:
        LD DE,reference
        CALL compare_sector
        JP C,on_pattern_failure
        LD A,(pattern_passed)
        INC A
        LD (pattern_passed),A
        LD HL,pattern_ok_text
        CALL puts
        LD A,(pattern_index)
        INC A
        LD (pattern_index),A
        CP 5
        JR NZ,write_patterns
        JP restore_begin
on_pattern_failure:
        LD A,(fault)
        LD (write_fault),A
        LD A,1
        LD (pattern_failed),A
        LD HL,pattern_fail_text
        CALL puts
restore_begin:
        LD HL,restoring_text
        CALL puts
restore_retry:
        LD A,3
        LD (restore_attempts),A
restore_attempt:
        ; Never knowingly put a damaged RAM backup back on the medium.
        LD HL,backup
        LD DE,backup_guard
        LD BC,512
backup_guard_check:
        LD A,(DE)
        CP (HL)
        JP NZ,backup_damaged
        INC DE
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,backup_guard_check
        ; Abort a possibly incomplete transfer before restoring. SRST lasts
        ; longer than 5 us; subsequent polling is bounded. Select again since
        ; reset may select master even when the test target is slave.
        LD A,4
        OUT (ALT),A
        CALL settle
        XOR A
        OUT (ALT),A
        CALL settle
        LD A,(device)
        OR 0xA0
        OUT (BASE+14),A
        CALL settle
        LD HL,backup
        LD (write_source),HL
before_restore_write:
        CALL write_sector
        LD A,0
        JR NC,restore_write_record
        INC A
restore_write_record:
        LD (restore_write_error),A
        ; A rejected write on read-only media may leave the original intact.
        ; Verify it even when the restoration write itself returned an error.
        CALL read_sector
        JR C,restore_again
restore_verify:
        LD DE,backup
        CALL compare_sector
        JR C,restore_again
        LD A,(flush_required)
        OR A
        JR Z,restore_verified
        LD A,(restore_write_error)
        OR A
        JR NZ,restore_again
restore_verified:
        XOR A
        LD (backup_valid),A
        LD HL,restore_ok_text
        CALL puts
        LD A,(pattern_failed)
        OR A
        LD A,1
        LD HL,write_pass_text
        JR Z,write_complete
        LD A,2
        LD HL,write_fail_restored_text
write_complete:
        LD (write_result),A
        CALL puts
        LD A,(pattern_failed)
        OR A
        JP Z,write_return_prompt
        LD HL,write_fault_text
        CALL puts
        LD A,(write_fault)
        CALL hex8
        CALL newline
        JP write_return_prompt
restore_again:
        LD A,(restore_attempts)
        DEC A
        LD (restore_attempts),A
        JP NZ,restore_attempt
        LD A,4
        LD (write_result),A
        LD HL,restore_failed_text
        JR critical_restore
backup_damaged:
        LD A,6
        LD (write_result),A
        LD HL,backup_damaged_text
critical_restore:
        PUSH HL
        CALL new_screen
        LD HL,title
        CALL puts
        LD HL,write_target
        CALL puts
        LD HL,lba
        CALL hex32
        CALL newline
        POP HL
        CALL puts
        LD HL,backup_address_text
        CALL puts
        LD HL,backup
        LD A,H
        CALL hex8
        LD A,L
        CALL hex8
        CALL newline
        LD HL,critical_text
        CALL puts
        CALL key_release
        LD A,5
        LD (phase),A
critical_wait:
        CALL 0x001B
        AND 0xDF
        CP 0x52
        JR NZ,critical_wait
        CALL key_release
        LD A,4
        LD (phase),A
        JP restore_retry
backup_failed:
        LD A,3
        LD (write_result),A
        LD HL,backup_failed_text
        JR write_notice
write_unavailable:
        LD HL,write_unavailable_text
        JR write_notice
write_cache_refused:
        LD HL,write_cache_text
        JR write_notice
write_bad_lba:
        LD HL,write_lba_error
write_notice:
        CALL puts
write_return_prompt:
        LD HL,continue_text
        CALL puts
        CALL key_release
        LD A,6
        LD (phase),A
write_return_wait:
        CALL 0x001B
        OR A
        JR Z,write_return_wait
        JP main_menu

write_sector:
        CALL wait_idle
        RET C
        CALL setup_sector
        LD A,0x30
        OUT (STATUS),A
        CALL settle
        CALL wait_drq
        RET C
        LD HL,(write_source)
        LD C,DATA
        LD B,0
        OTIR
        LD B,0
        OTIR
        CALL wait_done
        RET C
        LD A,(flush_required)
        OR A
        RET Z
flush_command:
        LD A,0xE7
        OUT (STATUS),A
        CALL settle
        JP wait_done
compare_sector:
        LD HL,sector
        LD BC,512
compare_buffer:
        LD A,(DE)
        CP (HL)
        JP NZ,mismatch
        INC DE
        INC HL
        DEC BC
        LD A,B
        OR C
        JR NZ,compare_buffer
        OR A
        RET
fill_pattern:
        LD HL,pattern_label
        CALL puts
        LD A,(pattern_index)
        ADD A,0x31
        CALL putc
        LD HL,pattern_of_text
        CALL puts
        LD A,(pattern_index)
        CP 4
        JR Z,fill_ramp
        LD E,A
        LD D,0
        LD HL,write_patterns_table
        ADD HL,DE
        LD A,(HL)
        LD HL,reference
        LD DE,reference+1
        LD BC,511
        LD (HL),A
        LDIR
        RET
fill_ramp:
        LD HL,reference
        LD B,0
        XOR A
fill_ramp_up:
        LD (HL),A
        INC HL
        INC A
        DJNZ fill_ramp_up
        DEC A
        LD B,0
fill_ramp_down:
        LD (HL),A
        INC HL
        DEC A
        DJNZ fill_ramp_down
        RET

parse_lba:
        LD HL,input_line
        LD A,(HL)
        CP 13
        RET Z                   ; blank line accepts displayed default
        PUSH HL
        LD HL,0
        LD (lba),HL
        LD (lba+2),HL
        POP HL
        LD B,8
parse_lba_digit:
        LD A,(HL)
        SUB 0x30
        CP 10
        JR C,parse_lba_nibble
        SUB 7
        CP 10
        JP C,bad_date
        CP 16
        JP NC,bad_date
parse_lba_nibble:
        LD C,A
        PUSH BC
        PUSH HL
        LD B,4
shift_lba:
        LD HL,lba
        SLA (HL)
        INC HL
        RL (HL)
        INC HL
        RL (HL)
        INC HL
        RL (HL)
        DJNZ shift_lba
        LD A,(lba)
        OR C
        LD (lba),A
        POP HL
        POP BC
        INC HL
        DJNZ parse_lba_digit
        LD A,(HL)
        CP 13
        JP NZ,bad_date
        LD HL,lba+3
        LD DE,capacity+3
        LD B,4
check_lba_range:
        LD A,(DE)
        CP (HL)
        JP C,bad_date
        JR NZ,lba_valid
        DEC HL
        DEC DE
        DJNZ check_lba_range
        JP bad_date              ; target equal to capacity is out of range
lba_valid:
        OR A
        RET

rtc_test:
        LD HL,rtc_text
        CALL puts
        LD BC,0x0D00+RTC
        IN A,(C)
        AND 0x0F
        LD (rtc_d),A
        CALL hex8
        LD A,0x2F
        CALL putc
        LD B,0x0E
        IN A,(C)
        AND 0x0F
        LD (rtc_e),A
        CALL hex8
        LD A,0x2F
        CALL putc
        LD B,0x0F
        IN A,(C)
        AND 0x0F
        LD (rtc_f),A
        CALL hex8
        CALL newline
        ; Read-only snapshot: deliberately do not change HOLD or clock mode.
        ; Digits may cross a rollover, so this is not an atomic calendar read.
        LD HL,rtc_digits
        LD BC,RTC
        LD D,13
rtc_digits_loop:
        IN A,(C)
        AND 0x0F
        LD (HL),A
        INC HL
        INC B
        DEC D
        JR NZ,rtc_digits_loop
        LD HL,digits_text
        CALL puts
        LD HL,rtc_digits
        LD B,13
show_digits:
        LD A,(HL)
        CALL nibble
        INC HL
        DJNZ show_digits
        CALL newline
        LD A,(rtc_f)
        AND 4
        JR Z,rtc_mode_checked
        LD HL,rtc_date_text
        CALL puts
        LD HL,rtc_digits+11
        CALL rtc_pair
        LD A,0x2D
        CALL putc
        CALL rtc_pair
        LD A,0x2D
        CALL putc
        CALL rtc_pair
        LD A,0x20
        CALL putc
        CALL rtc_pair
        LD A,0x3A
        CALL putc
        CALL rtc_pair
        LD A,0x3A
        CALL putc
        CALL rtc_pair
        CALL newline
rtc_mode_checked:
        LD A,(rtc_f)
        AND 3
        JR NZ,rtc_stopped
        LD A,(rtc_d)
        AND 1
        JR NZ,rtc_held
        LD A,(rtc_digits)
        CP 10
        JR NC,rtc_invalid
        LD (rtc_initial),A
        LD A,8
        LD (rtc_attempts),A
rtc_tick_loop:
        ; ~0.48 seconds at 3.55 MHz, eight attempts ~3.8 seconds.
        LD BC,0
rtc_delay:
        DEC BC
        LD A,B
        OR C
        JR NZ,rtc_delay
        LD BC,RTC
        IN A,(C)
        AND 0x0F
        CP 10
        JR NC,rtc_invalid
        LD HL,rtc_initial
        CP (HL)
        JR NZ,rtc_ticked
        LD A,(rtc_attempts)
        DEC A
        LD (rtc_attempts),A
        JR NZ,rtc_tick_loop
        LD A,4
        LD HL,rtc_notick_text
        JR rtc_report
rtc_ticked:
        LD A,1
        LD HL,rtc_tick_text
        JR rtc_report
rtc_stopped:
        LD A,3
        LD HL,rtc_stop_text
        JR rtc_report
rtc_held:
        LD A,5
        LD HL,rtc_hold_text
        JR rtc_report
rtc_invalid:
        LD A,2
        LD HL,rtc_invalid_text
rtc_report:
        LD (rtc_result),A
        JP puts
rtc_pair:
        LD A,(HL)
        CALL nibble
        DEC HL
        LD A,(HL)
        CALL nibble
        DEC HL
        RET

; Live display samples the RTC twice, retries at most three times, and never
; writes HOLD/STOP or clock digits. Rendering goes directly to VRAM so the
; screen does not scroll or flicker. CPU delay only throttles refresh; all
; displayed calendar/time values come from IN instructions at port xx25h.
live_clock:
        CALL key_release
        CALL new_screen
        LD HL,title
        CALL puts
        LD HL,live_heading
        CALL puts
        LD DE,0xD282
        LD HL,live_source_text
        CALL live_text
        LD DE,0xD2D2
        LD HL,live_year_text
        CALL live_text
        LD DE,0xD34A
        LD HL,live_keys_text
        CALL live_text
live_refresh:
        CALL live_sample
        CALL live_validate
        CALL live_draw
        LD HL,(live_refresh_count)
        INC HL
        LD (live_refresh_count),HL
        LD A,9
        LD (phase),A
live_frame_ready:
        ; About 0.12 s at 3.55 MHz. Check the keyboard throughout the delay.
        LD B,4
live_wait:
        PUSH BC
        CALL 0x001B
        POP BC
        OR A
        JR NZ,live_key
        LD DE,0x1000
live_delay:
        DEC DE
        LD A,D
        OR E
        JR NZ,live_delay
        DJNZ live_wait
        JP live_refresh
live_key:
        AND 0xDF
        CP 0x48
        JP Z,main_menu
        CP 0x51
        JP Z,0
        CP 0x54
        JR NZ,live_refresh
        LD A,1
        LD (set_return_live),A
        JP set_clock_entry

live_sample:
        LD A,3
        LD (live_attempts),A
live_sample_again:
        LD HL,live_digits
        CALL live_read_registers
        LD HL,live_check
        CALL live_read_registers
live_compare_start:
        LD HL,live_digits
        LD DE,live_check
        LD B,13
live_compare:
        LD A,(DE)
        CP (HL)
        JR NZ,live_sample_retry
        INC HL
        INC DE
        DJNZ live_compare
        ; Only HOLD and mode/STOP/RESET must be stable. BUSY and control E's
        ; interrupt flags need not remain constant when merely observing.
        LD A,(live_digits+13)
        LD B,A
        LD A,(live_check+13)
        XOR B
        AND 1
        JR NZ,live_sample_retry
        LD A,(live_digits+15)
        LD B,A
        LD A,(live_check+15)
        XOR B
        AND 15
        JR NZ,live_sample_retry
        XOR A
        LD (live_status),A
        RET
live_sample_retry:
        LD A,(live_attempts)
        DEC A
        LD (live_attempts),A
        JR NZ,live_sample_again
        LD A,6
        LD (live_status),A
        RET
live_read_registers:
        LD BC,RTC
        LD D,16
live_read_loop:
        IN A,(C)
        AND 15
        LD (HL),A
        INC HL
        INC B
        DEC D
        JR NZ,live_read_loop
        RET

live_validate:
        LD A,(live_status)
        OR A
        RET NZ
        LD HL,live_digits
        LD DE,live_values
        LD B,6
live_decode_pair:
        LD A,(HL)
        CP 10
        JP NC,live_invalid
        LD C,A
        INC HL
        LD A,B
        CP 4
        LD A,(HL)
        JR NZ,live_decode_tens
        ; Register 5 carries PM in bit 2 only in 12-hour mode.
        PUSH AF
        LD A,(live_digits+15)
        AND 4
        JR NZ,live_hour_24
        POP AF
        BIT 3,A
        JP NZ,live_invalid
        AND 3
        JR live_decode_tens
live_hour_24:
        POP AF
live_decode_tens:
        CP 10
        JP NC,live_invalid
        PUSH BC
        LD B,A
        ADD A,A
        ADD A,A
        ADD A,B
        ADD A,A
        ADD A,C
        POP BC
        LD (DE),A
        INC DE
        INC HL
        DJNZ live_decode_pair
        LD A,(live_values)
        CP 60
        JP NC,live_invalid
        LD A,(live_values+1)
        CP 60
        JP NC,live_invalid
        LD A,(live_digits+15)
        AND 4
        LD A,(live_values+2)
        JR Z,live_check_12
        CP 24
        JP NC,live_invalid
        JR live_check_date
live_check_12:
        OR A
        JP Z,live_invalid
        CP 13
        JP NC,live_invalid
live_check_date:
        LD A,(live_values+4)
        DEC A
        CP 12
        JP NC,live_invalid
        LD E,A
        LD D,0
        LD HL,month_lengths
        ADD HL,DE
        LD C,(HL)
        LD A,E
        CP 1
        JR NZ,live_check_day
        LD A,(live_values+5)
        AND 3
        JR NZ,live_check_day
        INC C
live_check_day:
        LD A,(live_values+3)
        OR A
        JP Z,live_invalid
        DEC A
        CP C
        JP NC,live_invalid
        LD A,(live_digits+12)
        CP 7
        JP NC,live_invalid
        LD A,(live_digits+15)
        BIT 3,A
        JR NZ,live_test_mode
        BIT 0,A
        JR NZ,live_reset_state
        BIT 1,A
        JR NZ,live_stopped_state
        LD A,(live_digits+13)
        AND 1
        RET Z
        LD A,3
        JR live_save_status
live_reset_state:
        LD A,2
        JR live_save_status
live_stopped_state:
        LD A,1
        JR live_save_status
live_test_mode:
        LD A,7
        JR live_save_status
live_invalid:
        LD A,4
live_save_status:
        LD (live_status),A
        RET

live_draw:
        LD DE,0xD0F2           ; row 6, column 2
        CALL live_clear_row
        LD HL,live_date_label
        CALL live_text
        CALL live_has_calendar
        JR C,live_draw_no_date
        LD A,(live_values+5)
        CP 78
        LD A,20
        JR C,live_century
        DEC A
live_century:
        CALL live_decimal
        LD A,(live_values+5)
        CALL live_decimal
        LD A,0x2D
        CALL live_char
        LD A,(live_values+4)
        CALL live_decimal
        LD A,0x2D
        CALL live_char
        LD A,(live_values+3)
        CALL live_decimal
        JR live_draw_time
live_draw_no_date:
        LD HL,live_no_date
        CALL live_text
live_draw_time:
        LD DE,0xD142           ; row 8
        CALL live_clear_row
        LD HL,live_time_label
        CALL live_text
        CALL live_has_calendar
        JR C,live_draw_no_time
        LD A,(live_values+2)
        CALL live_decimal
        LD A,0x3A
        CALL live_char
        LD A,(live_values+1)
        CALL live_decimal
        LD A,0x3A
        CALL live_char
        LD A,(live_values)
        CALL live_decimal
        LD A,(live_digits+15)
        AND 4
        LD HL,live_24h
        JR NZ,live_show_mode
        LD A,(live_digits+5)
        AND 4
        LD HL,live_am
        JR Z,live_show_mode
        LD HL,live_pm
live_show_mode:
        CALL live_text
        JR live_draw_weekday
live_draw_no_time:
        LD HL,live_no_time
        CALL live_text
live_draw_weekday:
        LD DE,0xD192           ; row 10
        CALL live_clear_row
        LD HL,live_weekday_label
        CALL live_text
        CALL live_has_calendar
        JR C,live_draw_status
        LD A,(live_digits+12)
        ADD A,A
        LD C,A
        LD B,0
        LD HL,weekday_names
        ADD HL,BC
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        CALL live_text
live_draw_status:
        LD DE,0xD1E2           ; row 12
        CALL live_clear_row
        LD HL,live_state_label
        CALL live_text
        LD A,(live_status)
        ADD A,A
        LD C,A
        LD B,0
        LD HL,live_states
        ADD HL,BC
        LD A,(HL)
        INC HL
        LD H,(HL)
        LD L,A
        CALL live_text
        LD DE,0xD232           ; row 14
        CALL live_clear_row
        LD HL,live_control_label
        CALL live_text
        LD A,(live_digits+13)
        CALL live_hex
        LD HL,live_control_e
        CALL live_text
        LD A,(live_digits+14)
        CALL live_hex
        LD HL,live_control_f
        CALL live_text
        LD A,(live_digits+15)
        JP live_hex
live_has_calendar:
        LD A,(live_status)
        CP 4
        JR Z,live_no_calendar
        CP 6
        JR Z,live_no_calendar
        OR A
        RET
live_no_calendar:
        SCF
        RET
live_decimal:
        PUSH BC
        LD B,0
live_decimal_tens:
        CP 10
        JR C,live_decimal_units
        SUB 10
        INC B
        JR live_decimal_tens
live_decimal_units:
        LD C,A
        LD A,B
        ADD A,0x30
        CALL live_char
        LD A,C
        ADD A,0x30
        CALL live_char
        POP BC
        RET
live_hex:
        AND 15
        ADD A,0x30
        CP 0x3A
        JR C,live_char
        ADD A,7
        JR live_char
live_clear_row:
        PUSH DE
        LD B,38
        XOR A
live_clear_loop:
        LD (DE),A
        INC DE
        DJNZ live_clear_loop
        POP DE
        RET
live_text:
        LD A,(HL)
        INC HL
        OR A
        RET Z
        CALL live_char
        JR live_text
live_char:
        CP 0x20
        JR Z,live_space
        CP 0x2D
        JR Z,live_dash
        CP 0x3A
        JR Z,live_colon
        CP 0x3A
        JR C,live_number
        SUB 0x40
        JR live_store
live_number:
        SUB 0x10
        JR live_store
live_dash:
        LD A,0x2A
        JR live_store
live_colon:
        LD A,0x4F
        JR live_store
live_space:
        XOR A
live_store:
        LD (DE),A
        INC DE
        RET

; Complete calendar, 1978..2077. ROM GETL edits an 81-byte buffer and
; supplies CR termination / Shift+Break cancellation. Setting is opt-in.
set_clock:
        XOR A
        LD (set_return_live),A
set_clock_entry:
        CALL key_release
        CALL new_screen
        LD HL,title
        CALL puts
        LD HL,set_prompt
        CALL puts
        LD DE,input_line
        CALL 0x0003
        LD A,(input_line)
        CP 0x1B
        JP Z,clock_set_return
        CALL parse_date
        JP C,set_invalid
        CALL acquire_rtc
        JP C,set_busy
        LD BC,0x0F00+RTC
        LD A,6                   ; 24-hour mode, STOP; RESET/TEST off
        OUT (C),A
        LD HL,set_fields+6       ; sec, min, hour, day, month, year
        LD BC,RTC
        LD D,6
set_pair:
        LD A,(HL)
        LD E,0
set_tens:
        CP 10
        JR C,set_units
        SUB 10
        INC E
        JR set_tens
set_units:
        OUT (C),A
        INC B
        LD A,E
        OUT (C),A
        INC B
        DEC HL
        DEC D
        JR NZ,set_pair
        LD A,(set_weekday)
        OUT (C),A               ; register C, Sunday=0
        ; Verify under STOP/HOLD before allowing the clock to advance.
        LD HL,set_fields+6
        LD BC,RTC
        LD D,6
verify_pair:
        IN A,(C)
        AND 15
        LD E,A
        INC B
        IN A,(C)
        AND 15
        PUSH DE
        LD D,A
        ADD A,A
        ADD A,A
        ADD A,D
        ADD A,A
        ADD A,E
        POP DE
        CP (HL)
        JR NZ,set_verify_failed
        INC B
        DEC HL
        DEC D
        JR NZ,verify_pair
        IN A,(C)
        AND 15
        LD HL,set_weekday
        CP (HL)
        JR NZ,set_verify_failed
        CALL start_rtc
        LD A,1
        LD (set_result),A
        LD HL,set_ok_text
        JR set_message
set_verify_failed:
        CALL start_rtc
        LD A,4
        LD (set_result),A
        LD HL,set_verify_text
        JR set_message
set_invalid:
        LD A,2
        LD (set_result),A
        LD HL,set_invalid_text
        JR set_message
set_busy:
        LD A,3
        LD (set_result),A
        LD HL,set_busy_text
set_message:
        CALL puts
        LD HL,continue_text
        CALL puts
        CALL key_release
        LD A,3
        LD (phase),A
set_wait:
        CALL 0x001B
        OR A
        JR Z,set_wait
        CALL key_release
clock_set_return:
        LD A,(set_return_live)
        OR A
        JP NZ,live_clock
        JP restart

acquire_rtc:
        LD E,0
acquire_try:
        LD BC,0x0D00+RTC
        LD A,1
        OUT (C),A
        IN A,(C)
        AND 2
        RET Z
        XOR A
        OUT (C),A
        DEC E
        JR NZ,acquire_try
        SCF
        RET
start_rtc:
        LD BC,0x0D00+RTC
        XOR A
        OUT (C),A               ; release HOLD while STOP still asserted
        LD B,0x0F
        LD A,4
        OUT (C),A               ; start counting in 24-hour mode
        RET

parse_date:
        LD HL,input_line
        LD DE,set_fields
        LD B,7
parse_pair:
        LD A,(HL)
        SUB 0x30
        CP 10
        JP NC,bad_date
        LD C,A
        ADD A,A
        ADD A,A
        ADD A,C
        ADD A,A
        LD C,A
        INC HL
        LD A,(HL)
        SUB 0x30
        CP 10
        JP NC,bad_date
        ADD A,C
        LD (DE),A
        INC DE
        INC HL
        DJNZ parse_pair
        LD A,(HL)
        CP 13
        JP NZ,bad_date
        LD A,(set_fields)
        CP 19
        JR Z,year_1900
        CP 20
        JP NZ,bad_date
        LD A,(set_fields+1)
        CP 78
        JP NC,bad_date
        LD HL,2000
        JR year_valid
year_1900:
        LD A,(set_fields+1)
        CP 78
        JP C,bad_date
        LD HL,1900
year_valid:
        LD E,A
        LD D,0
        ADD HL,DE
        LD (set_year),HL
        LD A,(set_fields+2)
        DEC A
        CP 12
        JR NC,bad_date
        LD E,A
        LD D,0
        LD HL,month_lengths
        ADD HL,DE
        LD C,(HL)
        LD A,E
        CP 1
        JR NZ,check_day
        LD A,(set_fields+1)
        AND 3
        JR NZ,check_day
        INC C
check_day:
        LD A,(set_fields+3)
        OR A
        JR Z,bad_date
        DEC A
        CP C
        JR NC,bad_date
        LD A,(set_fields+4)
        CP 24
        JR NC,bad_date
        LD A,(set_fields+5)
        CP 60
        JR NC,bad_date
        LD A,(set_fields+6)
        CP 60
        JR NC,bad_date
        JP calculate_weekday
bad_date:
        SCF
        RET

calculate_weekday:
        ; 1 January 1978 was Sunday. Accumulate days modulo seven.
        LD HL,1978
        LD DE,(set_year)
        LD C,0
weekday_year:
        LD A,H
        CP D
        JR NZ,weekday_add_year
        LD A,L
        CP E
        JR Z,weekday_months
weekday_add_year:
        INC C
        LD A,L
        AND 3
        JR NZ,weekday_nonleap
        INC C
weekday_nonleap:
        LD A,C
        CALL modulo_seven
        LD C,A
        INC HL
        JR weekday_year
weekday_months:
        LD HL,month_lengths
        LD A,(set_fields+2)
        DEC A
        LD B,A
        OR A
        JR Z,weekday_day
weekday_month:
        LD A,C
        ADD A,(HL)
        CALL modulo_seven
        LD C,A
        INC HL
        DJNZ weekday_month
        LD A,(set_fields+2)
        CP 3
        JR C,weekday_day
        LD A,(set_fields+1)
        AND 3
        JR NZ,weekday_day
        INC C
weekday_day:
        LD A,(set_fields+3)
        DEC A
        ADD A,C
        CALL modulo_seven
        LD (set_weekday),A
        OR A
        RET
modulo_seven:
        CP 7
        RET C
        SUB 7
        JR modulo_seven

; PRINT wrapper preserves loop registers. A and flags are scratch.
new_screen:
        LD A,0x16
        CALL putc
        LD HL,0xD800
        LD DE,0xD801
        LD BC,999
        LD (HL),0x70
        LDIR
        LD HL,0xD800
        LD DE,0xD801
        LD BC,119
        LD (HL),0x71
        LDIR
        LD HL,0xDB98
        LD DE,0xDB99
        LD BC,79
        LD (HL),0x71
        LDIR
        ; Fixed footer written directly in Sharp display codes, so it does
        ; not change the ROM text cursor or interfere with line editing.
        LD HL,footer_text
        LD DE,0xD3C1
footer_loop:
        LD A,(HL)
        INC HL
        OR A
        RET Z
        CP 0x20
        JR Z,footer_space
        CP 0x2D
        JR Z,footer_dash
        CP 0x2F
        JR Z,footer_slash
        CP 0x3A
        JR C,footer_number
        SUB 0x40
        JR footer_store
footer_number:
        SUB 0x10
        JR footer_store
footer_dash:
        LD A,0x2A
        JR footer_store
footer_slash:
        LD A,0x2D
        JR footer_store
footer_space:
        XOR A
footer_store:
        LD (DE),A
        INC DE
        JR footer_loop
putc:
        PUSH BC
        PUSH DE
        PUSH HL
        CALL 0x0012
        POP HL
        POP DE
        POP BC
        RET
newline:
        PUSH BC
        PUSH DE
        PUSH HL
        CALL 0x0006
        POP HL
        POP DE
        POP BC
        RET
puts:
        LD A,(HL)
        INC HL
        OR A
        RET Z
        CP 13
        JR NZ,puts_char
        CALL newline
        JR puts
puts_char:
        CALL putc
        JR puts
printable:
        CP 32
        JR C,print_dot
        CP 127
        JR NC,print_dot
        JP putc
print_dot:
        LD A,0x2E
        JP putc
hex32:
        PUSH HL
        INC HL
        INC HL
        INC HL
        LD B,4
hex32_loop:
        LD A,(HL)
        CALL hex8
        DEC HL
        DJNZ hex32_loop
        POP HL
        RET
hex8:
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
        JR C,nibble_print
        ADD A,7
nibble_print:
        JP putc

title:  DEFM "======================================"
        DB 13
        DEFM " GIDE DIAGNOSTICS 1.2         BASE 20H"
        DB 13
        DEFM "======================================"
        DB 13,0
footer_text: DEFM "SHARP MZ-700 / GIDE BASE 20H"
        DB 0
master_text: DEFM "DEVICE: MASTER"
        DB 13
        DB 0
slave_text: DEFM "DEVICE: SLAVE"
        DB 13
        DB 0
register_text: DEFM "TASK REGISTER PATTERNS: "
        DB 0
pass_text: DEFM "PASS"
        DB 13
        DB 0
fail_text: DEFM "FAIL"
        DB 13
        DB 0
identify_text: DEFM "IDENTIFY: PASS"
        DB 13
        DB 0
capacity_text: DEFM "LBA SECTOR COUNT (HEX): "
        DB 0
limit_text: DEFM "READ RANGE CAPPED TO LBA28"
        DB 13
        DB 0
reads_text: DEFM "LBA       SUM16  REPEATS"
        DB 13
        DB 0
sum_text: DEFM "  "
        DB 0
eight_text: DEFM "   8 OK"
        DB 13
        DB 0
stable_text: DEFM "REPEATED READS: PASS"
        DB 13
        DB 0
unsupported_text: DEFM "READS SKIPPED: NO USABLE LBA28"
        DB 13
        DB 0
ata_fail_text: DEFM "ATA FAIL CODE "
        DB 0
status_text: DEFM " STATUS "
        DB 0
error_text: DEFM " ERROR "
        DB 0
rtc_text: DEFM "RTC CONTROL D/E/F: "
        DB 0
digits_text: DEFM "RTC DIGITS 0-C: "
        DB 0
rtc_date_text: DEFM "RTC YY-MM-DD: "
        DB 0
rtc_tick_text: DEFM "RTC SECONDS ADVANCING: PASS"
        DB 13
        DB 0
rtc_notick_text: DEFM "RTC NO TICK: INIT/SUPPLY/DECODE?"
        DB 13
        DB 0
rtc_stop_text: DEFM "RTC STOP OR RESET SET: PRESS I"
        DB 13
        DB 0
rtc_hold_text: DEFM "RTC HOLD SET: PRESS I"
        DB 13
        DB 0
rtc_invalid_text: DEFM "RTC INVALID SECONDS / NO RESPONSE?"
        DB 13
        DB 0
menu_text: DB 13
        DEFM "--------------------------------------"
        DB 13
        DEFM " H MAIN MENU   R REPEAT   W WRITE TEST"
        DB 13,0
main_text: DB 13
        DEFM " STORAGE"
        DB 13
        DEFM "   M  READ TESTS / SELECT MASTER"
        DB 13
        DEFM "   S  READ TESTS / SELECT SLAVE"
        DB 13
        DEFM "   R  REPEAT SELECTED DEVICE TESTS"
        DB 13
        DEFM "   W  WRITE PATTERNS / RESTORE SECTOR"
        DB 13,13
        DEFM " REAL-TIME CLOCK"
        DB 13
        DEFM "   C  LIVE CLOCK DISPLAY"
        DB 13
        DEFM "   T  SET DATE AND TIME"
        DB 13
        DEFM "   I  INITIALISE CLOCK CONTROLS"
        DB 13,13
        DEFM " SYSTEM"
        DB 13
        DEFM "   Q  RETURN TO SHARP MONITOR"
        DB 13,13
        DEFM " WRITES REQUIRE SEPARATE CONFIRMATION."
        DB 13,13,0
live_heading: DB 13
        DEFM " REAL-TIME CLOCK / LIVE HARDWARE"
        DB 13,0
live_source_text: DEFM "SOURCE  GIDE RTC PORT 0025H"
        DB 0
live_year_text: DEFM "YEAR WINDOW 1978-2077"
        DB 0
live_keys_text: DEFM "H MENU   T SET TIME   Q MONITOR"
        DB 0
live_date_label: DEFM "DATE    "
        DB 0
live_time_label: DEFM "TIME    "
        DB 0
live_weekday_label: DEFM "DAY     "
        DB 0
live_state_label: DEFM "STATE   "
        DB 0
live_control_label: DEFM "CONTROL D "
        DB 0
live_control_e: DEFM "  E "
        DB 0
live_control_f: DEFM "  F "
        DB 0
live_no_date: DEFM "---- -- --"
        DB 0
live_no_time: DEFM "--:--:--"
        DB 0
live_24h: DEFM " 24H"
        DB 0
live_am: DEFM " AM"
        DB 0
live_pm: DEFM " PM"
        DB 0
weekday_names: DW day_sun,day_mon,day_tue,day_wed,day_thu,day_fri,day_sat
day_sun: DEFM "SUNDAY"
        DB 0
day_mon: DEFM "MONDAY"
        DB 0
day_tue: DEFM "TUESDAY"
        DB 0
day_wed: DEFM "WEDNESDAY"
        DB 0
day_thu: DEFM "THURSDAY"
        DB 0
day_fri: DEFM "FRIDAY"
        DB 0
day_sat: DEFM "SATURDAY"
        DB 0
live_states: DW live_enabled,live_stop,live_reset,live_hold,live_bad,live_bad,live_unstable,live_test
live_enabled: DEFM "COUNTING ENABLED"
        DB 0
live_stop: DEFM "STOPPED"
        DB 0
live_reset: DEFM "RESET ASSERTED"
        DB 0
live_hold: DEFM "HELD"
        DB 0
live_bad: DEFM "INVALID OR UNSET DATE"
        DB 0
live_unstable: DEFM "READ CHANGING - RETRYING"
        DB 0
live_test: DEFM "TEST MODE"
        DB 0
write_heading: DB 13
        DEFM " OPTIONAL SECTOR WRITE TEST"
        DB 13
        DEFM "--------------------------------------"
        DB 13,0
write_default: DEFM "DEFAULT LBA: "
        DB 0
write_lba_prompt: DB 13
        DEFM "8 HEX DIGITS / RETURN ACCEPTS DEFAULT"
        DB 13
        DEFM "SHIFT+BREAK CANCELS."
        DB 13,0
write_confirm: DB 13
        DEFM "TARGET LBA: "
        DB 0
write_risk: DB 13
        DEFM "ORIGINAL SECTOR WILL BE SAVED IN RAM."
        DB 13
        DEFM "POWER LOSS CAN LOSE THE ORIGINAL DATA."
        DB 13
        DEFM "THE LAST SECTOR MAY CONTAIN LIVE DATA."
        DB 13,13
        DEFM "TYPE WRITE THEN RETURN TO PROCEED."
        DB 13
        DEFM "ANY OTHER INPUT CANCELS."
        DB 13,0
confirm_word: DEFM "WRITE"
        DB 13
write_target: DB 13
        DEFM "WRITE TEST / LBA "
        DB 0
backup_ok_text: DEFM "BACKUP READ TWICE / RAM COPIES AGREE"
        DB 13,13,0
pattern_label: DEFM "  PATTERN "
        DB 0
pattern_of_text: DEFM "/5 ... "
        DB 0
pattern_ok_text: DEFM "WRITE / READ PASS"
        DB 13,0
pattern_fail_text: DEFM "FAIL - RESTORING ORIGINAL"
        DB 13,0
restoring_text: DB 13
        DEFM "RESTORING ORIGINAL SECTOR ..."
        DB 13,0
restore_ok_text: DEFM "ORIGINAL DATA READBACK VERIFIED"
        DB 13,13,0
write_pass_text: DEFM "RESULT: WRITE TEST PASS / RESTORED"
        DB 13,0
write_fail_restored_text: DEFM "RESULT: TEST FAILED / ORIGINAL INTACT"
        DB 13,0
write_fault_text: DEFM "TEST FAILURE CODE: "
        DB 0
restore_failed_text: DB 13
        DEFM "RESTORATION FAILED - BACKUP RETAINED"
        DB 13,0
backup_damaged_text: DB 13
        DEFM "RAM BACKUPS DIFFER - RESTORE BLOCKED"
        DB 13,0
backup_address_text: DEFM "512-BYTE BACKUP AT RAM "
        DB 0
critical_text: DEFM "DO NOT RESET, POWER OFF OR REMOVE CARD."
        DB 13
        DEFM "R RETRY RESTORATION"
        DB 13,0
backup_failed_text: DEFM "BACKUP FAILED / NO WRITE COMMAND ISSUED"
        DB 13,0
write_unavailable_text: DEFM "RUN AND PASS READ TESTS BEFORE WRITING."
        DB 13,0
write_cache_text: DEFM "CACHE ENABLED WITHOUT FLUSH SUPPORT."
        DB 13
        DEFM "WRITE TEST REFUSED / MEDIA UNCHANGED."
        DB 13,0
write_lba_error: DEFM "INVALID OR OUT-OF-RANGE LBA."
        DB 13
        DEFM "MEDIA UNCHANGED."
        DB 13,0
write_patterns_table: DB 0,0xFF,0xAA,0x55
set_prompt: DEFM "SET RTC: YYYYMMDDHHMMSS"
        DB 13
        DEFM "EXAMPLE: 20261114143000"
        DB 13
        DEFM "YEARS 1978-2077. SHIFT+BREAK CANCELS."
        DB 13,0
set_ok_text: DEFM "RTC SET AND READBACK VERIFIED"
        DB 13,0
set_invalid_text: DEFM "INVALID DATE/TIME - RTC UNCHANGED"
        DB 13,0
set_busy_text: DEFM "RTC BUSY / NO RESPONSE - SET FAILED"
        DB 13,0
set_verify_text: DEFM "RTC READBACK FAILED - CHECK HARDWARE"
        DB 13,0
continue_text: DEFM "PRESS A KEY TO CONTINUE"
        DB 13,0
month_lengths: DB 31,28,31,30,31,30,31,31,30,31,30,31
set_fields: DEFS 7
set_year: DW 0
set_weekday: DB 0
set_result: DB 0
input_line: DEFS 81
patterns: DB 0,0xFF,0xAA,0x55,1,2,4,8,0x10,0x20,0x40,0x80
device: DB 0
phase: DB 0
results:
ata_result: DB 0
reg_result: DB 0
identify_result: DB 0
rtc_result: DB 0
fault: DB 0
last_status: DB 0
read_count: DW 0
last_sum: DW 0
mismatch_address: DW 0
rtc_d: DB 0
rtc_e: DB 0
rtc_f: DB 0
rtc_digits: DEFS 13
results_end:
saved_task: DEFS 4
capacity: DEFS 4
lba: DEFS 4
repeats: DB 0
rtc_initial: DB 0
rtc_attempts: DB 0
identify: DEFS 512
sector: DEFS 512
reference: DEFS 512
backup: DEFS 512
backup_guard: DEFS 512
write_source: DW 0
write_result: DB 0
backup_valid: DB 0
pattern_passed: DB 0
pattern_failed: DB 0
pattern_index: DB 0
write_fault: DB 0
flush_required: DB 0
restore_attempts: DB 0
restore_write_error: DB 0
live_digits: DEFS 16
live_check: DEFS 16
live_values: DEFS 6
live_attempts: DB 0
live_status: DB 0
live_refresh_count: DW 0
set_return_live: DB 0
        DEFS 256
stack_top:
        DB 0
program_end:
        DB 0
