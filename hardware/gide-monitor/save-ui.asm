; Card-resident memory-save tool. Source must be 1200..CEFF; CF00..CFFF
; is its stack, D000..EFFF its code, F000..FFFF filesystem workspace.
        ORG 0xD000
save_entry:
        JP ui_entry
        JP native_save_entry
service_putc:
        JP 0x1040
service_getkey:
        JP 0x1048
service_getline:
        JP 0x1050
ui_entry:
        DI
        XOR A
        LD (native_mode),A
        LD SP,0xCFF0
        LD HL,ram_gates
        LD DE,0x1040
        LD BC,ram_gates_end-ram_gates
        LDIR
        LD HL,0x1040
        LD (service_putc+1),HL
        LD HL,0x1048
        LD (service_getkey+1),HL
        LD HL,0x1050
        LD (service_getline+1),HL
        XOR A
        LD HL,0xF000
        LD DE,0xF001
        LD BC,0xAFF
        LD (HL),A
        LDIR
        LD A,0x16
        CALL RAM_PUTC
        LD HL,save_title
        CALL ui_puts
        CALL boot_entry
        LD A,(mounted)
        OR A
        JP Z,ui_failed
        LD HL,save_folder
        LD (caller_pointer),HL
        CALL service_change_directory
        JP C,ui_failed
        LD HL,ask_start
        CALL input_hex
        JP C,ui_bad_range
        LD (ui_start),HL
        LD DE,0x1200
        OR A
        SBC HL,DE
        JP C,ui_bad_range
        LD HL,ask_end
        CALL input_hex
        JP C,ui_bad_range
        LD (ui_end),HL
        LD DE,0xCF00
        OR A
        SBC HL,DE
        JP NC,ui_bad_range
        LD HL,(ui_end)
        LD DE,(ui_start)
        OR A
        SBC HL,DE
        JP C,ui_bad_range
        INC HL
        LD (ui_length),HL
        LD HL,ask_exec
        CALL input_hex
        JP C,ui_bad_range
        LD (ui_exec),HL
        LD HL,ask_name
        CALL ui_puts
        LD DE,0x11A3
        CALL RAM_GETLINE
        LD HL,0x10F0
        LD DE,0x10F1
        LD BC,127
        LD (HL),13
        LDIR
        LD A,1
        LD (0x10F0),A
        LD HL,0x11A3
        LD DE,0x10F1
        LD B,8
ui_name_copy:
        LD A,(HL)
        CP 13
        JR Z,ui_name_ready
        LD (DE),A
        INC HL
        INC DE
        DJNZ ui_name_copy
        LD A,(HL)
        CP 13
        JP NZ,ui_bad_range
ui_name_ready:
        LD HL,(ui_length)
        LD (0x1102),HL
        LD HL,(ui_start)
        LD (0x1104),HL
        LD HL,(ui_exec)
        LD (0x1106),HL
        ; Adapt stock MZF header to the existing backend's native header shim.
        LD HL,0x10F0
        LD DE,NATIVE_HEADER
        LD BC,18
        LDIR
        INC DE
        INC DE
        LD BC,6
        LDIR
        LD HL,saving_text
        CALL ui_puts
        CALL ui_save
        JP C,ui_failed
        LD HL,success_text
        JR ui_finish
ui_bad_range:
        LD HL,range_text
        JR ui_finish
ui_failed:
        LD HL,failed_text
ui_finish:
        CALL ui_puts
        CALL replace_key_release
ui_wait:
        CALL RAM_GETKEY
        OR A
        JR Z,ui_wait
        JP 0
ui_save:
        LD (driver_stack),SP
        LD HL,NATIVE_HEADER
        LD (caller_pointer),HL
        CALL save_prepare
        LD HL,(ui_start)
        LD (caller_pointer),HL
        LD HL,(ui_length)
        LD (caller_count),HL
        JP save_commit
input_hex:
        CALL ui_puts
        LD DE,0x11A3
        CALL RAM_GETLINE
        LD DE,0x11A3
        LD HL,0
        LD B,4
ui_hex_loop:
        LD A,(DE)
        INC DE
        SUB 48
        JR C,ui_hex_bad
        CP 10
        JR C,ui_hex_digit
        SUB 7
        CP 10
        JR C,ui_hex_bad
        CP 16
        JR NC,ui_hex_bad
ui_hex_digit:
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        OR L
        LD L,A
        DJNZ ui_hex_loop
        LD A,(DE)
        CP 13
        RET Z
ui_hex_bad:
        SCF
        RET
ui_puts:
        LD A,(HL)
        INC HL
        OR A
        RET Z
        PUSH HL
        CALL RAM_PUTC
        POP HL
        JR ui_puts
ascii_value:
        RET
seq_begin:
seq_append:
        JP io_error
; Called by the lower-RAM monitor with HL -> an intact 128-byte MZF header.
; The lower monitor has already backed up all D000..FFFF RAM. This entry
; never writes application RAM, and uses its own upper-RAM stack.
native_save_entry:
        LD (api_return_sp),SP
        LD SP,0xF7F0
        LD (api_header),HL
        LD HL,0x0837
        LD (service_putc+1),HL
        LD HL,0x083F
        LD (service_getkey+1),HL
        LD HL,0x0847
        LD (service_getline+1),HL
        XOR A
        LD HL,0xF000
        LD DE,0xF001
        LD BC,0xAFF
        LD (HL),A
        LDIR
        LD A,1
        LD (native_mode),A
        CALL boot_entry
        LD A,(mounted)
        OR A
        JR Z,native_failed
        LD HL,save_folder
        LD (caller_pointer),HL
        CALL service_change_directory
        JR C,native_failed
        LD HL,(api_header)
        LD DE,NATIVE_HEADER
        LD BC,18
        LDIR
        INC DE
        INC DE
        LD BC,6
        LDIR
        ; Use an 8.3 alias, retaining the complete original MZF header below.
        LD HL,NATIVE_HEADER+1
        LD DE,NATIVE_HEADER+1
        LD B,17
native_alias_skip:
        LD A,(HL)
        CP 32
        JR NZ,native_alias_begin
        INC HL
        DJNZ native_alias_skip
        JR native_alias_empty
native_alias_begin:
        LD B,8
native_alias:
        LD A,(HL)
        OR A
        JR Z,native_alias_end
        CP 13
        JR Z,native_alias_end
        CP 97
        JR C,native_alias_upper
        CP 123
        JR NC,native_alias_upper
        SUB 32
native_alias_upper:
        CP 65
        JR C,native_alias_digit
        CP 91
        JR C,native_alias_store
native_alias_digit:
        CP 48
        JR C,native_alias_replace
        CP 58
        JR C,native_alias_store
native_alias_replace:
        LD A,95
native_alias_store:
        LD (DE),A
        INC HL
        INC DE
        DJNZ native_alias
native_alias_end:
        LD A,B
        CP 8
        JR NZ,native_alias_finish
native_alias_empty:
        LD HL,native_default_alias
        LD DE,NATIVE_HEADER+1
        LD BC,8
        LDIR
native_alias_finish:
        LD A,13
        LD (DE),A
        CALL native_commit
        JR C,native_failed
        XOR A
        JR native_return
native_failed:
        CP 2
        JR Z,native_return_error
        LD A,1
native_return_error:
        SCF
native_return:
        LD SP,(api_return_sp)
        RET
native_commit:
        LD (driver_stack),SP
        LD HL,NATIVE_HEADER
        LD (caller_pointer),HL
        CALL save_prepare
        ; The common writer's filename alias must not alter native metadata.
        LD HL,(api_header)
        LD DE,save_header
        LD BC,128
        LDIR
        LD HL,(api_header)
        LD DE,20
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD (caller_pointer),DE
        LD HL,(save_length)
        LD (caller_count),HL
        JP save_commit
service_change_directory:
        LD (driver_stack),SP
        JP change_directory
api_return_sp: DW 0
api_header: DW 0
native_mode: DB 0
native_default_alias: DEFM "UNTITLED"
native_cancel_error:
        LD A,2
        SCF
        LD SP,(driver_stack)
        RET
ram_gates:
        OUT (0xE3),A
        CALL 0x0012
        OUT (0xE1),A
        RET
        OUT (0xE3),A
        CALL 0x001B
        OUT (0xE1),A
        RET
        OUT (0xE3),A
        CALL 0x0003
        OUT (0xE1),A
        RET
ram_gates_end:
ui_start: DW 0
ui_end: DW 0
ui_length: DW 0
ui_exec: DW 0
save_folder: DEFM "/SAVES"
        DB 0
save_title: DEFM "SAVE MEMORY TO GIDE"
        DB 13
        DEFM "======================================="
        DB 13
        DEFM "SOURCE: 1200..CEFF  /  FILES IN /SAVES"
        DB 13,13,0
ask_start: DEFM "START ADDRESS (4 HEX): "
        DB 13,0
ask_end: DEFM "LAST ADDRESS  (4 HEX): "
        DB 13,0
ask_exec: DEFM "EXEC ADDRESS  (4 HEX): "
        DB 13,0
ask_name: DEFM "FILE NAME (1-8 CHARACTERS): "
        DB 13,0
saving_text: DB 13
        DEFM "WRITING AND VERIFYING..."
        DB 13,0
success_text: DEFM "SAVED. PRESS A KEY FOR GIDE."
        DB 13,0
range_text: DB 13
        DEFM "INVALID INPUT OR UNSAFE MEMORY RANGE."
        DB 13
failed_text: DEFM "SAVE FAILED. PRESS A KEY FOR GIDE."
        DB 13,0
