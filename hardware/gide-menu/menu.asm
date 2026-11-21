; SPDX-License-Identifier: GPL-3.0-or-later
; Stock MZ-700, GIDE 20h. Read-only FAT32 browser / machine-code MZT loader.
; Code/state <2A00, stack 2BF0, sector buffer 2C00, chain history 2E00,
; catalogue 3000..3FFF (discarded while staging payload at 3000..EFFF).
        ORG 0x1000
BUF: EQU 0x2C00
SEEN: EQU 0x2E00
TABLE: EQU 0x3000
EXIT: EQU 0xD3E4
start:
        DI
        LD SP,0x2BF0
        XOR A
        OUT (0xE2),A
        OUT (0xE3),A
        LD (depth),A
        LD HL,root_name
        LD DE,folder_name
        LD BC,11
        LDIR
mount:
        LD SP,0x2BF0
        XOR A
        OUT (0xE3),A
        LD (active_volume),A
        LD (depth),A
        LD (menu_ready),A
        LD (pending_cpm),A
        LD A,3
        LD (mount_attempts),A
mount_mbr:
        LD HL,lba
        CALL zero32
        CALL read_sector
        LD HL,(BUF+510)
        LD DE,0xAA55
        OR A
        SBC HL,DE
        JP Z,mbr_valid
        LD A,(mount_attempts)
        DEC A
        LD (mount_attempts),A
        JP NZ,mount_mbr
        JP bad_mbr
mbr_valid:
        LD HL,BUF+446
        LD B,4
find_partition:
        PUSH HL
        LD DE,4
        ADD HL,DE
        LD A,(HL)
        POP HL
        CP 0x0B
        JP Z,partition_found
        CP 0x0C
        JP Z,partition_found
        LD DE,16
        ADD HL,DE
        DJNZ find_partition
        JP bad_mbr
partition_found:
        LD A,(HL)
        AND 0x7F
        JP NZ,bad_mbr
        LD DE,8
        ADD HL,DE
        LD DE,partition_start
        CALL copy32
        LD DE,partition_size
        CALL copy32
        LD HL,partition_start
        CALL nonzero32
        JP Z,bad_mbr
        LD HL,partition_size
        CALL nonzero32
        JP Z,bad_mbr
        LD HL,partition_start
        LD DE,partition_end
        CALL copy32
        LD HL,partition_end
        LD DE,partition_size
        CALL add32
        JP C,bad_mbr
        LD A,(partition_end+3)
        AND 0xF0
        JP NZ,bad_mbr
        LD A,1
        LD (active_volume),A
        LD HL,partition_start
        LD DE,lba
        CALL copy32
        CALL read_sector
        LD HL,(BUF+510)
        LD DE,0xAA55
        OR A
        SBC HL,DE
        JP NZ,bad_bpb
        LD HL,(BUF+11)
        LD DE,512
        OR A
        SBC HL,DE
        JP NZ,bad_bpb
        LD HL,(BUF+17)           ; FAT32 has no fixed root directory
        LD A,H
        OR L
        JP NZ,bad_bpb
        LD HL,(BUF+22)
        LD A,H
        OR L
        JP NZ,bad_bpb
        LD HL,(BUF+42)           ; filesystem version must be 0
        LD A,H
        OR L
        JP NZ,bad_bpb
        LD A,(BUF+13)
        OR A
        JP Z,bad_bpb
        LD (spc),A
        LD B,0
cluster_shift_loop:
        CP 1
        JP Z,cluster_shift_done
        BIT 0,A
        JP NZ,bad_bpb
        SRL A
        INC B
        JP cluster_shift_loop
cluster_shift_done:
        LD A,B
        LD (cluster_shift),A
        LD A,(BUF+16)
        CP 1
        JP Z,fat_count_ok
        CP 2
        JP NZ,bad_bpb
fat_count_ok:
        LD (fat_count),A
        LD HL,(BUF+14)
        LD A,H
        OR L
        JP Z,bad_bpb
        LD (reserved),HL
        LD HL,BUF+36
        LD DE,fat_size
        CALL copy32
        LD HL,fat_size
        CALL nonzero32
        JP Z,bad_bpb
        LD HL,BUF+32
        LD DE,total_sectors
        CALL copy32
        LD HL,total_sectors
        CALL nonzero32
        JP Z,bad_bpb
        LD HL,total_sectors
        LD DE,partition_size
        CALL compare32
        JP C,total_size_ok
        JP NZ,bad_bpb
total_size_ok:
        LD HL,BUF+28
        LD DE,partition_start
        CALL compare32
        JP NZ,bad_bpb
        LD HL,BUF+44
        LD DE,root_cluster
        CALL copy32
        LD A,(root_cluster+3)
        AND 0xF0
        JP NZ,bad_bpb
        LD A,(BUF+40)
        LD (fat_flags),A
        LD HL,partition_start
        LD DE,fat_start
        CALL copy32
        LD HL,fat_start
        LD DE,(reserved)
        CALL add_word
        LD HL,fat_start
        LD DE,data_start
        CALL copy32
        LD A,(fat_count)
        LD (work_count),A
add_fat_metadata:
        LD HL,data_start
        LD DE,fat_size
        CALL add32
        JP C,bad_bpb
        LD A,(work_count)
        DEC A
        LD (work_count),A
        JP NZ,add_fat_metadata
        ; Metadata size = data_start - partition_start; then data clusters.
        LD HL,data_start
        LD DE,temp32
        CALL copy32
        LD HL,temp32
        LD DE,partition_start
        CALL subtract32
        JP C,bad_bpb
        LD HL,total_sectors
        LD DE,max_cluster
        CALL copy32
        LD HL,max_cluster
        LD DE,temp32
        CALL subtract32
        JP C,bad_bpb
        LD A,(cluster_shift)
        OR A
        JP Z,clusters_divided
        LD B,A
divide_clusters:
        LD HL,max_cluster+3
        SRL (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DJNZ divide_clusters
clusters_divided:
        LD HL,max_cluster
        LD DE,fat32_minimum
        CALL compare32
        JP C,bad_bpb
        LD A,(max_cluster+3)
        AND 0xF0
        JP NZ,bad_bpb
        LD HL,max_cluster
        CALL increment32
        ; FAT must contain an entry for every declared data cluster.
        LD HL,max_cluster
        LD DE,temp32
        CALL copy32
        LD HL,temp32
        LD DE,128
        CALL add_word
        LD B,7
fat_capacity_shift:
        LD HL,temp32+3
        SRL (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DJNZ fat_capacity_shift
        LD HL,temp32
        LD DE,fat_size
        CALL compare32
        JP C,fat_capacity_ok
        JP NZ,bad_bpb
fat_capacity_ok:
        LD HL,root_cluster
        CALL validate_cluster
        ; Honour an explicitly selected active FAT when mirroring is off.
        LD A,(fat_flags)
        BIT 7,A
        JP Z,fat_selected
        AND 15
        LD B,A
        LD A,(fat_count)
        CP B
        JP C,bad_bpb
        JP Z,bad_bpb
        LD A,B
        OR A
        JP Z,fat_selected
        LD HL,fat_start
        LD DE,fat_size
        CALL add32
fat_selected:
        LD HL,root_cluster
        LD DE,dir_cluster
        CALL copy32
        LD HL,root_name
        LD DE,folder_name
        LD BC,11
        LDIR
rescan:
        XOR A
        LD (title_index_entry),A
        LD A,1
        LD (need_sort),A
        XOR A
        LD (selection),A
        LD (actions_open),A
        LD (menu_ready),A
        LD (page),A
        LD (count),A
        LD (truncated),A
        LD HL,TABLE
        LD (table_pointer),HL
        LD HL,2048              ; bounded traversal of malformed directories
        LD (directory_budget),HL
        LD HL,dir_cluster
        LD DE,cluster
        CALL copy32
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
directory_sector:
        CALL read_sector
        LD HL,BUF
        LD (entry_pointer),HL
        LD A,16
        LD (entries_left),A
directory_entry:
        LD HL,(entry_pointer)
        LD A,(HL)
        OR A
        JP Z,directory_done
        CP 0xE5
        JP Z,directory_skip
        CP 0x2E
        JP Z,directory_skip
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        AND 0x0E                ; deleted/LFN/hidden/system/volume labels
        JP NZ,directory_skip
        LD HL,(entry_pointer)
        LD DE,title_index_name
        LD B,11
index_name_check:
        LD A,(DE)
        CP (HL)
        JP NZ,index_name_done
        INC HL
        INC DE
        DJNZ index_name_check
        LD HL,(entry_pointer)
        LD DE,title_index_entry
        LD BC,32
        LDIR
        JP directory_skip
index_name_done:
        LD HL,(entry_pointer)
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        AND 0x10
        JP NZ,directory_keep
        LD HL,(entry_pointer)
        LD DE,8
        ADD HL,DE
        LD A,(HL)
        AND 0xDF
        CP 0x4D
        JP NZ,directory_skip
        INC HL
        LD A,(HL)
        AND 0xDF
        CP 0x5A
        JP NZ,directory_skip
        INC HL
        LD A,(HL)
        AND 0xDF
        CP 0x54
        JP Z,directory_keep
        CP 0x46
        JP NZ,directory_skip
directory_keep:
        LD A,(count)
        CP 128
        JP NZ,directory_append
        LD A,1
        LD (truncated),A
        JP directory_skip
directory_append:
        LD HL,(entry_pointer)
        LD DE,(table_pointer)
        LD BC,32
        LDIR
        LD (table_pointer),DE
        LD A,(count)
        INC A
        LD (count),A
        JP directory_skip
directory_skip:
        LD HL,(entry_pointer)
        LD DE,32
        ADD HL,DE
        LD (entry_pointer),HL
        LD A,(entries_left)
        DEC A
        LD (entries_left),A
        JP NZ,directory_entry
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
        JP NZ,directory_sector
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,directory_done
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
        JP directory_sector

; SPDX-License-Identifier: GPL-3.0-or-later
; Two-column, row-major file grid. 24 items/page; cursor keys and Return.
directory_done:
        CALL load_titles
        JP draw
; TUI_INCLUDE
select_index:
        LD B,A
        LD A,(count)
        CP B
        JP Z,keys
        JP C,keys
        LD A,B
        CALL table_address
        LD DE,selected
        LD BC,32
        LDIR
        LD A,(selected+11)
        AND 0x10
        JP Z,load_file
        LD A,(depth)
        CP 8
        JP NC,too_deep
        CALL stack_address
        EX DE,HL
        LD HL,dir_cluster
        LD BC,4
        LDIR
        LD HL,folder_name
        LD BC,11
        LDIR
        LD A,(depth)
        INC A
        LD (depth),A
        CALL selected_cluster
        LD HL,cluster
        LD DE,dir_cluster
        CALL copy32
        LD HL,selected
        LD DE,folder_name
        LD BC,11
        LDIR
        JP rescan
up:
        LD A,(depth)
        OR A
        JP Z,draw
        DEC A
        LD (depth),A
        CALL stack_address
        LD DE,dir_cluster
        LD BC,4
        LDIR
        LD DE,folder_name
        LD BC,11
        LDIR
        JP rescan
cpm:
        LD A,1
        JP shortcut
basic:
        LD A,2
shortcut:
        LD (pending_cpm),A       ; 1=CP/M, 2=GIDE BASIC
        LD A,(depth)
        OR A
        JP Z,find_cpm
        XOR A
        LD (depth),A
        LD HL,root_cluster
        LD DE,dir_cluster
        CALL copy32
        LD HL,root_name
        LD DE,folder_name
        LD BC,11
        LDIR
        JP rescan
find_cpm:
        LD HL,TABLE
        LD A,(count)
        LD (work_count),A
cpm_search:
        LD A,(work_count)
        OR A
        JP Z,no_cpm
        PUSH HL
        LD DE,cpm_name
        LD A,(pending_cpm)
        CP 2
        JP NZ,shortcut_name_ready
        LD DE,basic_name
shortcut_name_ready:
        LD B,11
cpm_compare:
        LD A,(DE)
        CP (HL)
        JP NZ,cpm_not_here
        INC DE
        INC HL
        DJNZ cpm_compare
        POP HL
        LD DE,selected
        LD BC,32
        LDIR
        JP load_file
cpm_not_here:
        POP HL
        LD DE,32
        ADD HL,DE
        LD A,(work_count)
        DEC A
        LD (work_count),A
        JP cpm_search

load_file:
        XOR A
        LD (menu_ready),A
        LD (seen_count),A
        CALL selected_cluster
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
        CALL read_sector
        LD A,(BUF)
        CP 1
        JP NZ,bad_type
        LD HL,(BUF+18)
        LD A,H
        OR L
        JP Z,bad_header
        LD (payload_size),HL
        LD HL,(BUF+20)
        LD (destination),HL
        LD DE,0x1000
        OR A
        SBC HL,DE
        JP C,bad_header
        LD HL,(destination)
        LD DE,(payload_size)
        ADD HL,DE
        JP C,bad_header
        LD (payload_end),HL
        LD DE,0xD000
        OR A
        SBC HL,DE
        JP C,payload_range_ok
        JP NZ,bad_header
payload_range_ok:
        LD HL,(BUF+22)
        LD (execution),HL
        LD DE,(destination)
        OR A
        SBC HL,DE
        JP C,bad_header
        LD HL,(execution)
        LD DE,(payload_end)
        OR A
        SBC HL,DE
        JP NC,bad_header
        LD HL,(payload_size)
        LD DE,128
        ADD HL,DE
        LD DE,(selected+28)
        OR A
        SBC HL,DE
        JP NZ,bad_header
        LD HL,(selected+30)
        LD A,H
        OR L
        JP NZ,bad_header
        LD HL,loading_text
        CALL puts
        LD HL,selected
        CALL print_name
        CALL newline
        LD HL,0x3000
        LD (stage_pointer),HL
        LD HL,(payload_size)
        LD (remaining),HL
        LD HL,BUF+128
        LD DE,384
        CALL stage_bytes
file_loop:
        LD HL,(remaining)
        LD A,H
        OR L
        JP Z,file_complete
        LD HL,lba
        CALL increment32
        LD A,(within_cluster)
        INC A
        LD (within_cluster),A
        LD B,A
        LD A,(spc)
        CP B
        JP NZ,file_sector_ready
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,bad_chain
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
file_sector_ready:
        CALL read_sector
        LD HL,BUF
        LD DE,512
        CALL stage_bytes
        JP file_loop
stage_bytes:
        PUSH HL
        LD HL,(remaining)
        OR A
        SBC HL,DE
        JP NC,stage_full
        LD DE,(remaining)
stage_full:
        LD (copy_count),DE
        LD HL,(remaining)
        OR A
        SBC HL,DE
        LD (remaining),HL
        LD B,D
        LD C,E
        POP HL
        LD DE,(stage_pointer)
        XOR A
        OUT (0xE1),A            ; stage includes RAM behind VRAM/I/O
        LDIR
        LD (stage_pointer),DE
        RET
file_complete:
        ; Exit bridge is copied into both shadow RAM and actual VRAM.
        ; OUT E3 changes the mapping; JP(HL) is identical in both copies.
        XOR A
        OUT (0xE3),A
        LD HL,0xD800
        LD DE,0xD801
        LD BC,999
        LD (HL),0x71
        LDIR
        LD A,0xD3
        LD (EXIT),A
        LD A,0xE3
        LD (EXIT+1),A
        LD A,0xE9
        LD (EXIT+2),A
        XOR A
        OUT (0xE1),A
        LD HL,trampoline_bytes
        LD DE,0xF000
        LD BC,TRAMP_SIZE
        LDIR
        LD HL,(destination)
        LD (TRAMP_DEST),HL
        LD HL,(payload_size)
        LD (TRAMP_COUNT),HL
        LD HL,(execution)
        LD (TRAMP_EXEC),HL
        DI
        OUT (0xE0),A
        JP 0xF000

; ---------- FAT chain operations ----------
selected_cluster:
        LD HL,(selected+26)
        LD (cluster),HL
        LD HL,(selected+20)
        LD (cluster+2),HL
        LD HL,cluster
        JP validate_cluster
validate_cluster:
        PUSH HL
        LD DE,two32
        CALL compare32
        POP HL
        JP C,bad_chain
        LD DE,max_cluster
        CALL compare32
        RET C
        RET Z
        JP bad_chain
cluster_lba:
        LD HL,cluster
        CALL validate_cluster
        LD HL,cluster
        LD DE,temp32
        CALL copy32
        LD HL,temp32
        LD DE,two32
        CALL subtract32
        LD A,(cluster_shift)
        OR A
        JP Z,cluster_scaled
        LD B,A
cluster_scale:
        LD HL,temp32
        SLA (HL)
        INC HL
        RL (HL)
        INC HL
        RL (HL)
        INC HL
        RL (HL)
        JP C,bad_chain
        DJNZ cluster_scale
cluster_scaled:
        LD HL,data_start
        LD DE,lba
        CALL copy32
        LD HL,lba
        LD DE,temp32
        CALL add32
        JP C,bad_chain
        RET
next_cluster:
        LD HL,cluster
        LD DE,temp32
        CALL copy32
        LD B,7                  ; cluster*4 / 512 = cluster >> 7
fat_sector_shift:
        LD HL,temp32+3
        SRL (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DJNZ fat_sector_shift
        LD HL,temp32
        LD DE,fat_size
        CALL compare32
        JP NC,bad_chain
        LD HL,fat_start
        LD DE,lba
        CALL copy32
        LD HL,lba
        LD DE,temp32
        CALL add32
        CALL read_sector
        LD A,(cluster)
        AND 127
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        LD DE,BUF
        ADD HL,DE
        LD DE,cluster
        CALL copy32
        LD A,(cluster+3)
        AND 15
        LD (cluster+3),A
        LD HL,cluster
        LD DE,eoc32
        CALL compare32
        LD A,0
        JP C,not_eoc
        INC A
        LD (chain_end),A
        RET
not_eoc:
        LD (chain_end),A
        LD HL,cluster
        JP validate_cluster
remember_cluster:
        LD A,(seen_count)
        CP 128
        JP NC,bad_chain
        LD B,A
        LD HL,SEEN
        OR A
        JP Z,remember_append
remember_compare:
        PUSH BC
        PUSH HL
        LD DE,cluster
        CALL compare32
        POP HL
        POP BC
        JP Z,bad_chain
        LD DE,4
        ADD HL,DE
        DJNZ remember_compare
remember_append:
        EX DE,HL
        LD HL,cluster
        CALL copy32
        LD A,(seen_count)
        INC A
        LD (seen_count),A
        RET

; ---------- IDE read: one sector, bounded retries, no write commands ----------
read_sector:
        PUSH BC
        PUSH DE
        PUSH HL
        LD A,(active_volume)
        OR A
        JP Z,read_bounds_ok
        LD HL,lba
        LD DE,partition_start
        CALL compare32
        JP C,bad_chain
        LD HL,lba
        LD DE,partition_end
        CALL compare32
        JP NC,bad_chain
read_bounds_ok:
        LD A,3
        LD (read_attempts),A
read_try:
        LD A,(lba+3)
        AND 0xF0
        JP NZ,disk_error
        LD A,(lba+3)
        OR 0xE0
        OUT (0x2E),A
        CALL settle
        XOR A
        LD (post_command),A
        LD (wanted_drq),A
        CALL wait_status
        JP C,read_retry
        LD A,1
        OUT (0x2A),A
        LD A,(lba)
        OUT (0x2B),A
        LD A,(lba+1)
        OUT (0x2C),A
        LD A,(lba+2)
        OUT (0x2D),A
        LD A,0x20
        OUT (0x2F),A
        CALL settle
        LD A,1
        LD (post_command),A
        LD A,8
        LD (wanted_drq),A
        CALL wait_status
        JP C,read_retry
        LD HL,BUF
        LD BC,0x0028
        INIR
        LD B,0
        INIR
        XOR A
        LD (wanted_drq),A
        CALL wait_status
        JP NC,read_ok
read_retry:
        LD A,(read_attempts)
        DEC A
        LD (read_attempts),A
        JP NZ,read_try
        JP disk_error
read_ok:
        POP HL
        POP DE
        POP BC
        RET
wait_status:
        LD BC,0x8000
wait_loop:
        IN A,(0x26)
        LD (last_status),A
        CP 0xFF
        JP Z,wait_fail
        OR A
        JP Z,wait_next
        BIT 7,A
        JP NZ,wait_next
        LD A,(post_command)
        OR A
        JP Z,wait_drq_check
        LD A,(last_status)
        AND 0x21
        JP NZ,wait_fail
wait_drq_check:
        LD A,(last_status)
        AND 8
        LD D,A
        LD A,(wanted_drq)
        CP D
        RET Z
wait_next:
        DEC BC
        LD A,B
        OR C
        JP NZ,wait_loop
wait_fail:
        SCF
        RET
settle:
        IN A,(0x26)
        IN A,(0x26)
        IN A,(0x26)
        IN A,(0x26)
        RET

; ---------- unsigned little-endian helpers ----------
copy32:
        LD BC,4
        LDIR
        RET
zero32:
        XOR A
        LD (HL),A
        INC HL
        LD (HL),A
        INC HL
        LD (HL),A
        INC HL
        LD (HL),A
        RET
nonzero32:
        LD A,(HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        RET
increment32:
        LD B,4
increment_loop:
        INC (HL)
        RET NZ
        INC HL
        DJNZ increment_loop
        RET
add_word:
        LD A,(HL)
        ADD A,E
        LD (HL),A
        INC HL
        LD A,(HL)
        ADC A,D
        LD (HL),A
        INC HL
        LD A,(HL)
        ADC A,0
        LD (HL),A
        INC HL
        LD A,(HL)
        ADC A,0
        LD (HL),A
        RET
add32:
        LD B,4
        OR A
add32_loop:
        LD A,(DE)
        ADC A,(HL)
        LD (HL),A
        INC HL
        INC DE
        DJNZ add32_loop
        RET
subtract32:
        LD B,4
        OR A
subtract32_loop:
        LD A,(DE)
        LD C,A
        LD A,(HL)
        SBC A,C
        LD (HL),A
        INC HL
        INC DE
        DJNZ subtract32_loop
        RET
compare32:
        INC HL
        INC HL
        INC HL
        INC DE
        INC DE
        INC DE
        LD B,4
compare32_loop:
        LD A,(DE)
        LD C,A
        LD A,(HL)
        CP C
        RET NZ
        DEC HL
        DEC DE
        DJNZ compare32_loop
        RET
table_address:
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        LD DE,TABLE
        ADD HL,DE
        RET
stack_address:
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        LD DE,directory_stack
        ADD HL,DE
        RET

; ---------- monitor console and error handling ----------
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
        JP NZ,puts_char
        CALL newline
        JP puts
puts_char:
        CALL putc
        JP puts
print_name:
        PUSH HL
        PUSH BC
        LD B,8
name_base:
        LD A,(HL)
        INC HL
        CP 0x20
        CALL NZ,putc
        DJNZ name_base
        LD A,(HL)
        CP 0x20
        JP Z,name_done
        LD A,0x2E
        CALL putc
        LD B,3
name_extension:
        LD A,(HL)
        INC HL
        CP 0x20
        CALL NZ,putc
        DJNZ name_extension
name_done:
        POP BC
        POP HL
        RET
decimal:
        PUSH BC
        PUSH DE
        LD C,0
        CP 100
        JP C,decimal_tens
        SUB 100
        LD E,A
        LD A,0x31
        CALL putc
        LD A,E
        INC C
decimal_tens:
        LD D,0
decimal_subtract:
        CP 10
        JP C,decimal_remainder
        SUB 10
        INC D
        JP decimal_subtract
decimal_remainder:
        LD E,A
        LD A,D
        OR C
        JP Z,decimal_units
        LD A,D
        ADD A,0x30
        CALL putc
decimal_units:
        LD A,E
        ADD A,0x30
        CALL putc
        POP DE
        POP BC
        RET
bad_mbr:
        LD HL,mbr_error_text
        JP show_error
bad_bpb:
        LD HL,bpb_error_text
        JP show_error
bad_chain:
        LD HL,chain_error_text
        JP show_error
bad_type:
        LD HL,type_error_text
        JP show_error
bad_header:
        LD HL,header_error_text
        JP show_error
disk_error:
        LD HL,disk_error_text
        JP show_error
too_deep:
        LD HL,depth_error_text
        JP show_error
no_cpm:
        LD HL,cpm_error_text
        LD A,(pending_cpm)
        CP 2
        JP NZ,show_error
        LD HL,basic_error_text
show_error:
        LD SP,0x2BF0
        XOR A
        OUT (0xE3),A
        CALL newline
        CALL puts
        CALL newline
        LD HL,error_keys_text
        CALL puts
        LD A,2
        LD (menu_ready),A
error_keys:
        CALL 0x001B
        CP 0x51
        JP Z,0
        CP 0x52
        JP Z,mount
        JP error_keys

title: DEFM "GIDE FILE MANAGER / FAT32"
        DB 13
        DEFM "========================================"
        DB 13
        DEFM "FOLDER: "
        DB 0
page_text: DEFM "PAGE "
        DB 0
count_text: DEFM "    ITEMS "
        DB 0
dir_text: DEFM "  <DIR>"
        DB 0
keys_text: DEFM "1-9 A-C SELECT   N NEXT  V PREVIOUS"
        DB 13
        DEFM "U UP  R RESCAN  P CP/M  Q MONITOR"
        DB 13,0
limit_text: DEFM "SHOWING FIRST 128 ITEMS"
        DB 13,0
loading_text: DEFM "LOADING "
        DB 0
error_keys_text: DEFM "R REMOUNT  Q MONITOR"
        DB 13,0
mbr_error_text: DEFM "NO VALID FAT32 PARTITION"
        DB 0
bpb_error_text: DEFM "INVALID OR UNSUPPORTED FAT32 VOLUME"
        DB 0
chain_error_text: DEFM "INVALID OR CYCLIC FILE CHAIN"
        DB 0
type_error_text: DEFM "MACHINE-CODE MZT/MZF FILES ONLY"
        DB 0
header_error_text: DEFM "INVALID MZT SIZE, LOAD OR ENTRY ADDRESS"
        DB 0
disk_error_text: DEFM "IDE READ FAILED"
        DB 0
depth_error_text: DEFM "MAXIMUM FOLDER DEPTH IS 8"
        DB 0
cpm_error_text: DEFM "CPM3.MZF NOT FOUND IN ROOT"
        DB 0
root_name: DEFM "ROOT       "
basic_error_text: DEFM "GIDEBW.MZF NOT FOUND IN ROOT"
        DB 0
basic_name: DEFM "GIDEBW  MZF"
cpm_name: DEFM "CPM3    MZF"
two32: DB 2,0,0,0
eoc32: DB 0xF8,0xFF,0xFF,0x0F
fat32_minimum: DB 0xF5,0xFF,0,0
partition_start: DEFS 4
partition_size: DEFS 4
partition_end: DEFS 4
fat_start: DEFS 4
fat_size: DEFS 4
data_start: DEFS 4
root_cluster: DEFS 4
dir_cluster: DEFS 4
cluster: DEFS 4
max_cluster: DEFS 4
total_sectors: DEFS 4
temp32: DEFS 4
lba: DEFS 4
reserved: DW 0
directory_budget: DW 0
entry_pointer: DW 0
table_pointer: DW 0
display_pointer: DW 0
stage_pointer: DW 0
remaining: DW 0
copy_count: DW 0
payload_size: DW 0
payload_end: DW 0
destination: DW 0
execution: DW 0
selected: DEFS 32
folder_name: DEFS 11
directory_stack: DEFS 128
active_volume: DB 0
fat_count: DB 0
fat_flags: DB 0
spc: DB 0
cluster_shift: DB 0
work_count: DB 0
mount_attempts: DB 0
read_attempts: DB 0
post_command: DB 0
wanted_drq: DB 0
last_status: DB 0
within_cluster: DB 0
chain_end: DB 0
entries_left: DB 0
count: DB 0
page: DB 0
slot: DB 0
display_index: DB 0
truncated: DB 0
depth: DB 0
seen_count: DB 0
menu_ready: DB 0
pending_cpm: DB 0
selection: DB 0
need_sort: DB 0
page_base: DB 0
grid_row: DB 0
grid_column: DB 0
cell_index: DB 0
cell_written: DB 0
cell_pointer: DW 0
actions_open: DB 0
action_selection: DB 0
path_index: DB 0
sort_left: DW 0
sort_right: DW 0
sort_changed: DB 0
sort_pairs: DB 0
cursor_next: DB 0
paint_colour: DB 0
paint_column: DB 0
last_key: DB 0
trampoline_bytes:
; Builder appends the independently assembled F000h trampoline here.
