; Optional per-folder TITLES.IDX. Each 128-byte record is the exact FAT short
; name (11 bytes), followed by a printable ASCII, NUL-terminated title.
; Cache at 4000..7FFF is discarded when a selected program is staged.
load_titles:
        XOR A
        LD (title_item),A
initial_title:
        LD A,(title_item)
        LD B,A
        LD A,(count)
        CP B
        JP Z,titles_index
        LD A,B
        CALL table_address
        PUSH HL
        LD A,(title_item)
        LD H,0
        LD L,A
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        LD DE,0x4000
        ADD HL,DE
        EX DE,HL
        POP HL
        PUSH HL
        PUSH DE
        LD BC,12
        ADD HL,BC
        LD (HL),E
        INC HL
        LD (HL),D
        POP DE
        POP HL
        LD B,8
fallback_base:
        LD A,(HL)
        INC HL
        CP 32
        JP Z,fallback_space
        LD (DE),A
        INC DE
fallback_space:
        DJNZ fallback_base
        LD A,(HL)
        CP 32
        JP Z,fallback_end
        LD A,46
        LD (DE),A
        INC DE
        LD B,3
fallback_extension:
        LD A,(HL)
        INC HL
        CP 32
        JP Z,fallback_extension_space
        LD (DE),A
        INC DE
fallback_extension_space:
        DJNZ fallback_extension
fallback_end:
        XOR A
        LD (DE),A
        LD A,(title_item)
        INC A
        LD (title_item),A
        JP initial_title
titles_index:
        LD A,(title_index_entry)
        OR A
        RET Z
        LD HL,(title_index_entry+30)
        LD A,H
        OR L
        RET NZ
        LD HL,(title_index_entry+28)
        LD A,L
        AND 127
        RET NZ
        LD A,H
        OR L
        RET Z
        LD DE,16385
        OR A
        SBC HL,DE
        RET NC
        LD HL,(title_index_entry+28)
        LD (title_remaining),HL
        LD HL,title_index_entry
        LD DE,selected
        LD BC,32
        LDIR
        XOR A
        LD (seen_count),A
        LD (within_cluster),A
        CALL selected_cluster
        CALL remember_cluster
        CALL cluster_lba
title_sector:
        CALL read_sector
        LD HL,BUF
        LD (title_record),HL
        LD A,4
        LD (title_records),A
title_record_loop:
        ; Validate before allowing a title to replace its short-name fallback.
        LD HL,(title_record)
        LD DE,11
        ADD HL,DE
        LD B,117
title_validate:
        LD A,(HL)
        OR A
        JP Z,title_valid
        CP 32
        JP C,title_next
        CP 127
        JP NC,title_next
        INC HL
        DJNZ title_validate
        JP title_next
title_valid:
        LD HL,(title_record)
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        OR A
        JP Z,title_next
        XOR A
        LD (title_item),A
title_match_item:
        LD A,(title_item)
        LD B,A
        LD A,(count)
        CP B
        JP Z,title_next
        LD A,B
        CALL table_address
        LD DE,(title_record)
        LD B,11
title_compare_name:
        LD A,(DE)
        CP (HL)
        JP NZ,title_not_match
        INC HL
        INC DE
        DJNZ title_compare_name
        INC HL                 ; skip attribute, reach private title pointer
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,(title_record)
        LD BC,11
        ADD HL,BC
        LD BC,117
        LDIR
        JP title_next
title_not_match:
        LD A,(title_item)
        INC A
        LD (title_item),A
        JP title_match_item
title_next:
        LD HL,(title_remaining)
        LD DE,128
        OR A
        SBC HL,DE
        LD (title_remaining),HL
        LD A,H
        OR L
        RET Z
        LD HL,(title_record)
        ADD HL,DE
        LD (title_record),HL
        LD A,(title_records)
        DEC A
        LD (title_records),A
        JP NZ,title_record_loop
        LD HL,lba
        CALL increment32
        LD A,(within_cluster)
        INC A
        LD (within_cluster),A
        LD B,A
        LD A,(spc)
        CP B
        JP NZ,title_sector
        CALL next_cluster
        LD A,(chain_end)
        OR A
        RET NZ
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
        JP title_sector
entry_title:
        LD DE,12
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        RET
; Render the selected title into three 40-character rows without scrolling
; the menu or changing the monitor cursor. Conversion table is copied from
; the repository reference monitor 1Z-013A ATBL (ASCII 00..7F).
draw_selected_title:
        LD HL,0xD370          ; row 22
        LD (title_screen),HL
        LD A,(count)
        OR A
        LD HL,title_blank
        JP Z,title_display
        LD A,(selection)
        CALL table_address
        CALL entry_title
title_display:
        LD B,120
title_display_loop:
        LD A,(HL)
        OR A
        JP Z,title_display_pad
        INC HL
        PUSH BC
        PUSH HL
        LD L,A
        LD H,0
        LD DE,title_ascii
        ADD HL,DE
        LD A,(HL)
        POP HL
        POP BC
        JP title_display_byte
title_display_pad:
        LD A,0
 title_display_byte:
        PUSH HL
        LD HL,(title_screen)
        LD (HL),A
        INC HL
        LD (title_screen),HL
        POP HL
        DJNZ title_display_loop
        RET
title_blank: DB 0
title_index_name: DEFM "TITLES  IDX"
title_index_entry: DEFS 32
title_item: DB 0
title_records: DB 0
title_record: DW 0
title_remaining: DW 0
title_screen: DW 0

title_ascii:
        DB 240,240,240,243,240,245,240,240,240,240,240,240,240,240,240,240
        DB 240,193,194,195,196,197,198,240,240,240,240,240,240,240,240,240
        DB 0,97,98,99,100,101,102,103,104,105,107,106,47,42,46,45
        DB 32,33,34,35,36,37,38,39,40,41,79,44,81,43,87,73
        DB 85,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
        DB 16,17,18,19,20,21,22,23,24,25,26,82,89,84,80,69
        DB 199,200,201,202,203,204,205,206,207,223,231,232,229,233,236,237
        DB 208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,192
