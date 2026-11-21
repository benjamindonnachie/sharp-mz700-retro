; GPL-3.0-or-later. Copy-on-write replacement of ordinary writable files.
check_old_fats:
        CALL fat_get
        LD HL,fat_value
        LD DE,fat_old
        CALL compare32
        JP NZ,io_error
        LD A,(fat_flags)
        BIT 7,A
        RET NZ
        LD A,(fat_count)
        CP 2
        RET NZ
        LD HL,lba
        LD DE,fat_size
        CALL add32
        CALL read_sector
        CALL read_fat_value
        LD HL,fat_value
        LD DE,fat_old
        CALL compare32
        JP NZ,io_error
        RET
replace_found:
        LD A,(replace_pending)
        OR A
        JP NZ,save_exists
        LD HL,(entry_pointer)
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        AND 0x1F
        JP NZ,save_exists
        CALL capture_slot
        LD HL,(entry_pointer)
        LD DE,replace_entry
        LD BC,32
        LDIR
        LD HL,replace_entry+8
        LD DE,save_name+8
        LD BC,3
        LDIR
        LD A,1
        LD (replace_pending),A
        JP save_count_entry
replace_confirm:
        LD A,(replace_pending)
        OR A
        RET Z
        CALL replace_validate
        CALL replace_key_release
        LD HL,replace_text
replace_prompt:
        LD A,(HL)
        INC HL
        OR A
        JP Z,replace_answer
        PUSH HL
        CALL 0x0012
        POP HL
        JP replace_prompt
replace_answer:
        CALL 0x001B
        AND 0xDF
        CP 0x59
        JP Z,replace_yes
        CP 0x4E
        JP Z,replace_no
        ; Return or BREAK declines as well; all other keys are ignored.
        CP 0x0D
        JP Z,replace_no
        CP 0x1B
        JP NZ,replace_answer
replace_no:
        CALL replace_key_release
        LD A,0x4E
        CALL 0x0012
        CALL 0x0006
        JP save_exists
replace_yes:
        CALL replace_key_release
        LD A,0x59
        CALL 0x0012
        CALL 0x0006
        XOR A
        RET
replace_first:
        LD HL,(replace_entry+26)
        LD (cluster),HL
        LD HL,(replace_entry+20)
        LD (cluster+2),HL
        LD HL,cluster
        LD A,(HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        RET
replace_validate:
        CALL replace_first
        RET Z
        XOR A
        LD (seen_count),A
replace_validate_cluster:
        LD HL,cluster
        CALL validate_cluster
        CALL remember_cluster
        LD HL,cluster
        LD DE,alloc_cursor
        CALL copy32
        CALL fat_get
        LD HL,fat_value
        LD DE,fat_old
        CALL copy32
        CALL check_old_fats
        LD HL,fat_old
        LD DE,cluster
        CALL copy32
        LD HL,cluster
        LD DE,eoc32
        CALL compare32
        RET NC
        JP replace_validate_cluster
replace_release:
        LD A,(replace_pending)
        OR A
        RET Z
        CALL replace_first
        RET Z
        LD B,64
replace_release_cluster:
        PUSH BC
        LD HL,cluster
        LD DE,alloc_cursor
        CALL copy32
        CALL fat_get
        LD HL,fat_value
        LD DE,fat_old
        CALL copy32
        LD HL,fat_new
        CALL zero32
        CALL fat_set
        LD HL,fat_old
        LD DE,cluster
        CALL copy32
        POP BC
        LD HL,cluster
        LD DE,eoc32
        CALL compare32
        JR NC,replace_released
        DJNZ replace_release_cluster
        JP io_error
replace_released:
        JP flush_disk
replace_slot_check:
        LD A,(replace_pending)
        OR A
        RET Z
        PUSH HL
        LD DE,replace_entry
        LD B,32
replace_slot_byte:
        LD A,(DE)
        CP (HL)
        JP NZ,io_error
        INC HL
        INC DE
        DJNZ replace_slot_byte
        POP HL
        RET
replace_key_release:
        ; Native physical-matrix scan: bit 0 means any ordinary key held.
        ; Drain queued/repeated input too, so the command's Return cannot
        ; decline a fast prompt, or its answer leak into the next command.
        CALL 0x0459
        AND 1
        JR NZ,replace_key_release
        CALL 0x001B
        OR A
        JR NZ,replace_key_release
        RET
replace_text:
        DB 13
        DEFM "OVERWRITE EXISTING FILE? (Y/N) "
        DB 0
