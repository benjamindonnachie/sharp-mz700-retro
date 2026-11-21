; SPDX-License-Identifier: GPL-3.0-or-later
fat_selected:
        LD HL,root_cluster
        LD DE,cluster
        CALL copy32
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
        LD HL,2048
        LD (directory_budget),HL
find_menu_sector:
        CALL read_sector
        LD HL,BUF
        LD (entry_pointer),HL
        LD A,16
        LD (entries_left),A
find_menu_entry:
        LD HL,(entry_pointer)
        LD A,(HL)
        OR A
        JP Z,missing_menu
        CP 0xE5
        JP Z,find_menu_next
        LD DE,menu_filename
        LD B,11
find_menu_compare:
        LD A,(DE)
        CP (HL)
        JP NZ,find_menu_next
        INC DE
        INC HL
        DJNZ find_menu_compare
        LD HL,(entry_pointer)
        LD DE,selected
        LD BC,32
        LDIR
        LD A,(selected+11)
        AND 0x18
        JP NZ,missing_menu
        JP load_menu
find_menu_next:
        LD HL,(entry_pointer)
        LD DE,32
        ADD HL,DE
        LD (entry_pointer),HL
        LD A,(entries_left)
        DEC A
        LD (entries_left),A
        JP NZ,find_menu_entry
        LD HL,(directory_budget)
        DEC HL
        LD (directory_budget),HL
        LD A,H
        OR L
        JP Z,bad_chain
        LD HL,lba
        CALL increment32
        LD A,(within_cluster)
        INC A
        LD (within_cluster),A
        LD B,A
        LD A,(spc)
        CP B
        JP NZ,find_menu_sector
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,missing_menu
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
        JP find_menu_sector
load_menu:
        XOR A
        LD (seen_count),A
        CALL selected_cluster
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
        CALL read_sector
        LD A,(BUF)
        CP 1
        JP NZ,bad_menu
        LD HL,(BUF+20)
        LD DE,0x1000
        OR A
        SBC HL,DE
        JP NZ,bad_menu
        LD HL,(BUF+22)
        OR A
        SBC HL,DE
        JP NZ,bad_menu
        LD HL,(BUF+18)
        LD A,H
        OR L
        JP Z,bad_menu
        LD (payload_size),HL
        LD DE,0x1A00
        OR A
        SBC HL,DE
        JP C,menu_size_ok
        JP NZ,bad_menu
menu_size_ok:
        LD HL,(payload_size)
        LD DE,128
        ADD HL,DE
        LD DE,(selected+28)
        OR A
        SBC HL,DE
        JP NZ,bad_menu
        LD HL,(selected+30)
        LD A,H
        OR L
        JP NZ,bad_menu
        LD HL,loading_text
        CALL puts
        LD HL,0x3000
        LD (stage_pointer),HL
        LD HL,(payload_size)
        LD (remaining),HL
        LD HL,BUF+128
        LD DE,384
        CALL copy_menu_bytes
menu_sector_loop:
        LD HL,(remaining)
        LD A,H
        OR L
        JP Z,menu_loaded
        LD HL,lba
        CALL increment32
        LD A,(within_cluster)
        INC A
        LD (within_cluster),A
        LD B,A
        LD A,(spc)
        CP B
        JP NZ,menu_sector_ready
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,bad_chain
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
menu_sector_ready:
        CALL read_sector
        LD HL,BUF
        LD DE,512
        CALL copy_menu_bytes
        JP menu_sector_loop
copy_menu_bytes:
        PUSH HL
        LD HL,(remaining)
        OR A
        SBC HL,DE
        JP NC,menu_full_chunk
        LD DE,(remaining)
menu_full_chunk:
        LD (copy_count),DE
        LD HL,(remaining)
        OR A
        SBC HL,DE
        LD (remaining),HL
        LD B,D
        LD C,E
        POP HL
        LD DE,(stage_pointer)
        LDIR
        LD (stage_pointer),DE
        RET
menu_loaded:
        LD HL,0x3000
        LD DE,0x1000
        LD BC,(payload_size)
        LDIR
        JP 0x1000

init_error:
        LD HL,init_error_text
        JP show_error
missing_menu:
        LD HL,missing_text
        JP show_error
bad_menu:
        LD HL,menu_error_text
        JP show_error
bad_mbr:
bad_bpb:
bad_chain:
        LD HL,fat_error_text
        JP show_error
disk_error:
        LD HL,disk_error_text
show_error:
        LD SP,0x7F00
        CALL newline
        CALL puts
        CALL newline
        LD HL,error_keys_text
        CALL puts
        LD A,2
        LD (menu_ready),A
error_keys:
        CALL 0x001B
        CP 0x52
        JP Z,start
        CP 0x51
        JP Z,0
        JP error_keys
waiting_text: DEFM "WAITING FOR IDE DEVICE"
        DB 13,0
loading_text: DEFM "LOADING MENU.MZF"
        DB 13,0
init_error_text: DEFM "IDE NOT READY"
        DB 0
missing_text: DEFM "NO MENU.MZF"
        DB 0
menu_error_text: DEFM "BAD MENU.MZF"
        DB 0
fat_error_text: DEFM "FAT32 ERROR"
        DB 0
disk_error_text: DEFM "IDE READ ERROR"
        DB 0
error_keys_text: DEFM "R RETRY  Q EXIT"
        DB 13,0
menu_filename: DEFM "MENU    MZF"
two32: DB 2,0,0,0
eoc32: DB 0xF8,0xFF,0xFF,0x0F
fat32_minimum: DB 0xF5,0xFF,0,0
patterns: DB 0,0xFF,0xAA,0x55,1,2,4,8,0x10,0x20,0x40,0x80
