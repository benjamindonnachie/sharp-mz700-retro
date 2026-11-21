; GPL-3.0-or-later. FAT32 backend with confirmed replacement for UniCard BASIC MZ-5Z008.
; Packed into retired cassette/serial/floppy/debugger areas by pack_driver.py.
; The stock BASIC programme ceiling remains FF00; sector buffer FE00..FFFF.
        ORG 0xF000
driver_entry:
        LD (driver_stack),SP
        LD (caller_pointer),HL
        LD (caller_count),BC
        LD (service),A
        XOR A
        LD (fat_cache_valid),A
        LD A,(mounted)
        OR A
        JP Z,io_error
driver_dispatch:
        ; A sequential writer owns the shared sector and allocation plan.
        ; Refuse directory/LOAD/SAVE/FREE operations until its CLOSE.
        LD A,(seq_active)
        OR A
        JR Z,driver_available
        LD A,(service)
        CP 6
        JP NZ,io_error
driver_available:
        LD A,(service)
        OR A
        JP Z,get_name
        DEC A
        JP Z,get_header
        DEC A
        JP Z,get_data
        DEC A
        JP Z,change_directory
        DEC A
        JP Z,print_cwd
        DEC A
        JP Z,save_prepare
        DEC A
        JP Z,save_commit
        JP get_free
bad_chain:
disk_error:
        LD A,(booting)
        OR A
        JP NZ,boot_error
        LD A,(resolving)
        OR A
        JP NZ,chdir_failure
        XOR A
        LD (file_open),A
io_error:
        LD A,(booting)
        OR A
        JP NZ,boot_error
        XOR A
        LD (save_pending),A
        LD (seq_active),A
        LD A,1
        SCF
        LD SP,(driver_stack)
        RET
not_found:
        LD A,(resolving)
        OR A
        JP NZ,chdir_failure
        LD A,4
        SCF
        LD SP,(driver_stack)
        RET

get_name:
        LD HL,(0x38C1)
        LD A,(HL)
        INC A
        JP Z,not_found
        LD (HL),A
        LD (ordinal),A
        CALL begin_directory
name_search:
        CALL next_entry
        LD A,(ordinal)
        DEC A
        LD (ordinal),A
        JP NZ,name_search
        LD HL,selected
        LD DE,0x38CB
        LD B,8
name_base:
        LD A,(HL)
        INC HL
        CP 32
        JP Z,name_space
        LD (DE),A
        INC DE
name_space:
        DJNZ name_base
        LD A,(HL)
        CP 32
        JP Z,name_suffix
        LD A,46
        LD (DE),A
        INC DE
        LD B,3
name_extension:
        LD A,(HL)
        INC HL
        CP 32
        JP Z,name_ext_space
        LD (DE),A
        INC DE
name_ext_space:
        DJNZ name_extension
name_suffix:
        LD A,(selected+11)
        AND 16
        JP Z,name_finish
        LD A,47
        LD (DE),A
        INC DE
name_finish:
        LD A,13
        LD (DE),A
        LD HL,(0x38C1)
        LD A,(HL)
        OR A
        RET

begin_directory:
        LD HL,dir_cluster
        LD DE,cluster
        CALL copy32
begin_cluster:
        XOR A
        LD (seen_count),A
        LD (within_cluster),A
        LD HL,2048
        LD (directory_budget),HL
        CALL remember_cluster
        CALL cluster_lba
        CALL read_sector
        LD HL,BUF
        LD (entry_pointer),HL
        LD A,16
        LD (entries_left),A
        RET
next_entry:
        LD A,(entries_left)
        OR A
        JP NZ,entry_available
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
        JP NZ,directory_read
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,not_found
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
directory_read:
        CALL read_sector
        LD HL,BUF
        LD (entry_pointer),HL
        LD A,16
        LD (entries_left),A
entry_available:
        LD HL,(entry_pointer)
        LD DE,selected
        LD BC,32
        LDIR
        LD (entry_pointer),HL
        LD A,(entries_left)
        DEC A
        LD (entries_left),A
        LD A,(selected)
        OR A
        JP Z,not_found
        CP 0xE5
        JP Z,next_entry
        LD A,(selected+11)
        AND 0x0E
        JP NZ,next_entry
        LD A,(resolving)
        OR A
        RET NZ
        LD A,(selected)
        CP 46
        JP Z,next_entry
        XOR A
        RET

get_header:
        LD HL,(selected+30)
        LD A,H
        OR L
        JP NZ,io_error
        LD HL,(selected+28)
        LD DE,128
        OR A
        SBC HL,DE
        JP C,io_error
        LD (file_remaining),HL
        CALL selected_cluster
        XOR A
        LD (seen_count),A
        LD (within_cluster),A
        CALL remember_cluster
        CALL cluster_lba
        CALL read_sector
        LD HL,(BUF+18)
        LD DE,(file_remaining)
        OR A
        SBC HL,DE
        JP NZ,io_error
        LD HL,BUF
        LD DE,(caller_pointer)
        LD BC,18
        LDIR
        INC DE
        INC DE
        LD BC,12
        LDIR
        LD HL,BUF+128
        LD (file_pointer),HL
        LD A,1
        LD (file_open),A
        XOR A
        RET
get_data:
        LD A,(file_open)
        OR A
        JP Z,io_error
        LD HL,(file_remaining)
        LD DE,(caller_count)
        OR A
        SBC HL,DE
        JP C,io_error
        LD HL,(caller_pointer)
        ADD HL,DE
        JP C,io_error
        LD DE,0xFF00
        OR A
        SBC HL,DE
        JP NC,io_error
read_loop:
        LD HL,(caller_count)
        LD A,H
        OR L
        JP Z,read_complete
        LD HL,(file_pointer)
        LD DE,BUF+512
        OR A
        SBC HL,DE
        CALL Z,advance_file
        LD HL,(file_pointer)
        LD A,(HL)
        INC HL
        LD (file_pointer),HL
        LD HL,(caller_pointer)
        LD (HL),A
        INC HL
        LD (caller_pointer),HL
        LD HL,(caller_count)
        DEC HL
        LD (caller_count),HL
        LD HL,(file_remaining)
        DEC HL
        LD (file_remaining),HL
        JP read_loop
read_complete:
        LD HL,(file_remaining)
        LD A,H
        OR L
        RET NZ
        XOR A
        LD (file_open),A
        RET
advance_file:
        LD HL,lba
        CALL increment32
        LD A,(within_cluster)
        INC A
        LD (within_cluster),A
        LD B,A
        LD A,(spc)
        CP B
        JP NZ,file_read_sector
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,bad_chain
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
file_read_sector:
        CALL read_sector
        LD HL,BUF
        LD (file_pointer),HL
        RET

; INIT "SD:/PATH" retains the existing BASIC parser. Resolve each 8.3
; component by FAT directory traversal, including parent '..' entries.
change_directory:
        XOR A
        LD (resolving),A
        LD HL,dir_cluster
        LD DE,saved_directory
        CALL copy32
        LD HL,cwd_path
        LD DE,saved_path
        LD BC,128
        LDIR
        LD HL,(caller_pointer)
        LD DE,path_input
        LD B,63
copy_path:
        LD A,(HL)
        CP 34
        JP Z,path_copied
        CP 32
        JP C,path_copied
        CALL 0x396C
        LD (DE),A
        INC DE
        INC HL
        DJNZ copy_path
        JP chdir_failure
path_copied:
        XOR A
        LD (DE),A
        LD HL,path_input
        LD A,(HL)
        OR A
        RET Z
        CP 47
        JP NZ,component_start
        LD HL,root_cluster
        LD DE,dir_cluster
        CALL copy32
        LD HL,cwd_path+1
        LD (HL),0
        LD HL,path_input
        INC HL
component_start:
        LD (path_cursor),HL
        LD A,(HL)
        OR A
        JP Z,chdir_complete
        CP 47
        JP NZ,component_prepare
        INC HL
        JP component_start
component_prepare:
        LD HL,component
        LD DE,component+1
        LD BC,10
        LD (HL),32
        LDIR
        LD DE,component
        LD B,8
        LD HL,(path_cursor)
component_copy:
        LD A,(HL)
        OR A
        JP Z,component_done
        CP 47
        JP Z,component_done
        LD (DE),A
        INC HL
        INC DE
        DJNZ component_copy
        LD A,(HL)
        OR A
        JP Z,component_done
        CP 47
        JP NZ,chdir_failure
component_done:
        LD (path_next),HL
        LD A,(component)
        CP 46
        JP NZ,component_lookup
        LD A,(component+1)
        CP 32
        JP Z,path_component_next
        LD HL,dir_cluster
        LD DE,root_cluster
        CALL compare32
        JP Z,path_component_next
component_lookup:
        LD A,1
        LD (resolving),A
        CALL begin_directory
component_search:
        CALL next_entry
        LD HL,selected
        LD DE,component
        LD B,11
component_compare:
        LD A,(DE)
        CP (HL)
        JP NZ,component_search
        INC HL
        INC DE
        DJNZ component_compare
        LD A,(selected+11)
        AND 16
        JP Z,chdir_failure
        CALL selected_cluster_unchecked
        LD A,(cluster)
        LD HL,cluster+1
        OR (HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        JP NZ,component_cluster_ok
        LD HL,root_cluster
        LD DE,cluster
        CALL copy32
component_cluster_ok:
        LD HL,cluster
        CALL validate_cluster
        LD HL,cluster
        LD DE,dir_cluster
        CALL copy32
        LD A,(component)
        CP 46
        JP Z,path_parent
        LD HL,cwd_path
        LD B,0
path_length:
        LD A,(HL)
        OR A
        JP Z,path_append
        INC HL
        INC B
        JP path_length
path_append:
        LD A,B
        CP 118
        JP NC,chdir_failure
        LD A,B
        CP 1
        JP Z,path_append_name
        LD (HL),47
        INC HL
path_append_name:
        LD DE,component
        LD B,8
path_name_char:
        LD A,(DE)
        CP 32
        JP Z,path_name_end
        LD (HL),A
        INC HL
        INC DE
        DJNZ path_name_char
path_name_end:
        LD (HL),0
        JP path_component_next
path_parent:
        LD A,(component+1)
        CP 46
        JP NZ,path_component_next
        LD HL,cwd_path
path_parent_end:
        LD A,(HL)
        INC HL
        OR A
        JP NZ,path_parent_end
        DEC HL
path_parent_back:
        DEC HL
        LD A,(HL)
        CP 47
        JP NZ,path_parent_back
        LD DE,cwd_path
        OR A
        SBC HL,DE
        ADD HL,DE
        JP NZ,path_parent_cut
        INC HL
path_parent_cut:
        LD (HL),0
path_component_next:
        LD HL,(path_next)
        JP component_start
chdir_complete:
        XOR A
        LD (resolving),A
        LD (file_open),A
        LD (0x38BF),A
        LD (0x38C0),A
        RET
chdir_failure:
        LD HL,saved_directory
        LD DE,dir_cluster
        CALL copy32
        LD HL,saved_path
        LD DE,cwd_path
        LD BC,128
        LDIR
        XOR A
        LD (resolving),A
        JP not_found
print_cwd:
        LD HL,cwd_path
print_cwd_loop:
        LD A,(HL)
        OR A
        RET Z
        PUSH HL
        CALL 0x0012
        POP HL
        INC HL
        JP print_cwd_loop

; Common FAT32 mount, read-only ATA and arithmetic routines follow.

; Retired automatic CMT/RS startup OPEN hook. Preserve the original token
; buffer at 84E7: BASIC reuses its welcome text storage for direct commands.
runtime_ready:
        RET
