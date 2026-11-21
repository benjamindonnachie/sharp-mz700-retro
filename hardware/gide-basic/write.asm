; GPL-3.0-or-later. FAT32 SAVE and explicitly confirmed replacements.
; New data and FAT chains precede directory publication. A replacement
; reuses its validated directory slot, then frees the old chain. Every
; sector write is read back and compared.
save_prepare:
        XOR A
        LD (save_pending),A
        LD (seq_active),A
        LD HL,save_header
        LD DE,save_header+1
        LD BC,127
        LD (HL),A
        LDIR
        LD HL,(caller_pointer)
        LD DE,save_header
        LD BC,18
        LDIR
        INC HL
        INC HL
        LD BC,6
        LDIR
        LD A,(save_header)
        CP 2
        JP NZ,save_type_three
        LD A,5
        JP save_type_ready
save_type_three:
        CP 3
        JP NZ,save_type_one
        LD A,4
        JP save_type_ready
save_type_one:
        CP 1
        JP NZ,io_error
save_type_ready:
        LD (save_header),A
        LD HL,(save_header+18)
        LD A,H
        OR L
        JP NZ,save_length_ready
        ; Native WOPEN uses a data header with an initially unknown length.
        LD A,(save_header)
        CP 4
        JP NZ,io_error
        LD A,1
        LD (seq_active),A
        LD HL,30720
save_length_ready:
        LD (save_length),HL
        LD DE,128
        ADD HL,DE
        JP C,io_error
        LD (save_total),HL
        LD HL,save_name
        LD DE,save_name+1
        LD BC,10
        LD (HL),32
        LDIR
        LD HL,save_header+1
        LD DE,save_name
        LD B,8
save_name_loop:
        LD A,(HL)
        CP 13
        JP Z,save_name_done
        OR A
        JP Z,save_name_done
        CALL 0x396C
        CP 97
        JP C,save_upper
        CP 123
        JP NC,save_upper
        SUB 32
save_upper:
        CP 65
        JP C,save_digit
        CP 91
        JP C,save_name_char
save_digit:
        CP 48
        JP C,save_punctuation
        CP 58
        JP C,save_name_char
save_punctuation:
        CP 95
        JP Z,save_name_char
        CP 45
        JP NZ,save_bad_name
save_name_char:
        LD (DE),A
        INC DE
        INC HL
        DJNZ save_name_loop
        LD A,(HL)
        CP 13
        JP Z,save_name_done
        OR A
        JP NZ,save_bad_name
save_name_done:
        LD A,B
        CP 8
        JP Z,save_bad_name
        LD HL,save_extension
        LD DE,save_name+8
        LD BC,3
        LDIR
        CALL scan_save_directory
        CALL replace_confirm
        LD HL,dir_cluster
        LD DE,save_dir
        CALL copy32
        LD HL,(save_total)
        DEC HL
        LD A,(cluster_shift)
        ADD A,9
        LD B,A
save_cluster_divide:
        SRL H
        RR L
        DJNZ save_cluster_divide
        INC HL
        LD A,H
        OR A
        JP NZ,io_error
        LD A,L
        CP 63
        JP NC,io_error
        LD (save_clusters),A
        LD B,A
        LD A,(dir_grow)
        ADD A,B
        LD (plan_needed),A
        XOR A
        LD (scan_mode),A
        CALL scan_free_clusters
        LD A,1
        LD (save_pending),A
        LD A,(seq_active)
        OR A
        JP NZ,seq_begin
        XOR A
        RET
save_bad_name:
        LD HL,bad_name_text
        JP save_message_error
save_exists:
        LD HL,exists_text
        JP save_message_error
save_full:
        LD HL,full_text
save_message_error:
        LD A,(HL)
        OR A
        JP Z,io_error
        PUSH HL
        CALL 0x0012
        POP HL
        INC HL
        JP save_message_error

; Complete raw directory scan, including hidden/system entries, before any
; write. Save a deleted/end slot, but keep scanning live entries for matches.
scan_save_directory:
        XOR A
        LD (replace_pending),A
        LD (slot_found),A
        LD (dir_grow),A
        LD (slot_end),A
        LD (terminator_needed),A
        LD (visible_count),A
        CALL begin_directory
save_dir_loop:
        LD HL,(entry_pointer)
        LD A,(HL)
        OR A
        JP Z,save_dir_end
        CP 0xE5
        JP Z,save_deleted
        LD DE,save_name
        LD B,8
save_compare_base:
        LD A,(DE)
        CP (HL)
        JP NZ,save_count_entry
        INC HL
        INC DE
        DJNZ save_compare_base
        LD A,(HL)
        CP 77
        JP NZ,save_count_entry
        INC HL
        LD A,(HL)
        CP 90
        JP NZ,save_count_entry
        INC HL
        LD A,(HL)
        CP 70
        JP Z,replace_found
        CP 84
        JP Z,replace_found
save_count_entry:
        LD HL,(entry_pointer)
        LD A,(HL)
        CP 46
        JP Z,save_dir_next
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        AND 0x0E
        JP NZ,save_dir_next
        LD A,(visible_count)
        INC A
        LD (visible_count),A
        CP 64
        JP C,save_dir_next
        CP 65
        JP NC,save_full
        LD A,(replace_pending)
        OR A
        JP Z,save_full
        JP save_dir_next
save_deleted:
        LD A,(slot_found)
        OR A
        CALL Z,capture_slot
save_dir_next:
        LD HL,(entry_pointer)
        LD DE,32
        ADD HL,DE
        LD (entry_pointer),HL
        LD A,(entries_left)
        DEC A
        LD (entries_left),A
        JP NZ,save_dir_loop
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
        JP NZ,save_dir_read
        LD HL,cluster
        LD DE,dir_tail
        CALL copy32
        CALL next_cluster
        LD A,(chain_end)
        OR A
        JP NZ,save_directory_eoc
        CALL remember_cluster
        CALL cluster_lba
        XOR A
        LD (within_cluster),A
save_dir_read:
        CALL read_sector
        LD HL,BUF
        LD (entry_pointer),HL
        LD A,16
        LD (entries_left),A
        JP save_dir_loop
save_directory_eoc:
        LD A,(slot_found)
        OR A
        RET NZ
        LD A,1
        LD (dir_grow),A
        ; next_cluster left the original EOC value in cluster.
        LD HL,cluster
        LD DE,dir_link_old
        CALL copy32
        RET
save_dir_end:
        LD A,(slot_found)
        OR A
        RET NZ
        CALL capture_slot
        LD A,1
        LD (slot_end),A
        LD HL,(dir_slot_offset)
        LD DE,480
        OR A
        SBC HL,DE
        RET NZ
        ; Preserve termination when consuming the last entry in a sector.
        LD A,(within_cluster)
        INC A
        LD B,A
        LD A,(spc)
        CP B
        JP NZ,terminator_next_sector
        CALL next_cluster
        LD A,(chain_end)
        OR A
        RET NZ
        CALL remember_cluster
        CALL cluster_lba
        JP terminator_record
terminator_next_sector:
        LD HL,lba
        CALL increment32
terminator_record:
        LD HL,lba
        LD DE,terminator_lba
        CALL copy32
        LD A,1
        LD (terminator_needed),A
        RET
capture_slot:
        LD HL,lba
        LD DE,dir_slot_lba
        CALL copy32
        LD HL,(entry_pointer)
        LD DE,BUF
        OR A
        SBC HL,DE
        LD (dir_slot_offset),HL
        LD A,1
        LD (slot_found),A
        RET

; Read the FAT entry for alloc_cursor. Never follow a zero/free entry as a
; chain. The original upper four reserved bits are retained by fat_set.
fat_address:
        LD HL,alloc_cursor
        CALL fat_address_for
        LD (fat_offset),HL
        LD HL,lba
        LD DE,fat_lba
        JP copy32
fat_address_for:
        PUSH HL
        CALL validate_cluster
        POP HL
        PUSH HL
        LD DE,temp32
        CALL copy32
        LD B,7
fat_address_shift:
        LD HL,temp32+3
        SRL (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DEC HL
        RR (HL)
        DJNZ fat_address_shift
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
        JP C,bad_chain
        POP HL
        LD A,(HL)
        AND 127
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        RET
fat_get:
        LD A,(fat_cache_valid)
        OR A
        JP Z,fat_load_sector
        LD HL,alloc_cursor
        LD DE,fat_cache_cluster
        LD A,(HL)
        AND 128
        LD C,A
        LD A,(DE)
        CP C
        JP NZ,fat_load_sector
        INC HL
        INC DE
        LD B,3
fat_cached_upper:
        LD A,(DE)
        CP (HL)
        JP NZ,fat_load_sector
        INC HL
        INC DE
        DJNZ fat_cached_upper
        LD A,(alloc_cursor)
        AND 127
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        LD (fat_offset),HL
        LD HL,fat_cache_lba
        LD DE,lba
        CALL copy32
        JP read_fat_value
fat_load_sector:
        CALL fat_address
        CALL read_sector
        LD HL,lba
        LD DE,fat_cache_lba
        CALL copy32
        LD HL,alloc_cursor
        LD DE,fat_cache_cluster
        CALL copy32
        LD A,(fat_cache_cluster)
        AND 128
        LD (fat_cache_cluster),A
        LD A,1
        LD (fat_cache_valid),A
        JP read_fat_value
read_fat_value:
        LD HL,(fat_offset)
        LD DE,BUF
        ADD HL,DE
        LD DE,fat_value
        CALL copy32
        LD A,(fat_value+3)
        AND 15
        LD (fat_value+3),A
        RET
fat_is_zero:
        LD HL,fat_value
        LD A,(HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        INC HL
        OR (HL)
        RET
verify_free_mirror:
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
        CALL fat_is_zero
        JP NZ,io_error
        RET
scan_free_clusters:
        LD HL,two32
        LD DE,alloc_cursor
        CALL copy32
        XOR A
        LD (plan_count),A
        LD HL,0
        LD (free_sectors),HL
free_scan_loop:
        CALL fat_get
        CALL fat_is_zero
        JP NZ,free_scan_next
        CALL verify_free_mirror
        LD A,(scan_mode)
        OR A
        JP NZ,free_count_only
        LD A,(plan_count)
        CALL plan_address
        EX DE,HL
        LD HL,alloc_cursor
        CALL copy32
        LD A,(plan_count)
        INC A
        LD (plan_count),A
        LD B,A
        LD A,(plan_needed)
        CP B
        RET Z
        JP free_scan_next
free_count_only:
        LD A,(spc)
        LD E,A
        LD D,0
        LD HL,(free_sectors)
        ADD HL,DE
        LD (free_sectors),HL
        LD A,H
        OR A
        RET NZ
        LD A,L
        CP 64
        RET NC
free_scan_next:
        LD HL,alloc_cursor
        LD DE,max_cluster
        CALL compare32
        JP Z,free_scan_end
        LD HL,alloc_cursor
        CALL increment32
        JP free_scan_loop
free_scan_end:
        LD A,(scan_mode)
        OR A
        RET NZ
        JP save_full
get_free:
        LD A,1
        LD (scan_mode),A
        CALL scan_free_clusters
        LD HL,(free_sectors)
        LD DE,64
        OR A
        SBC HL,DE
        LD HL,32
        JP NC,free_result_done
        LD HL,(free_sectors)
        SRL H
        RR L
free_result_done:
        LD (FREE_RETURN),HL
        XOR A
        RET
plan_address:
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        LD DE,PLAN
        ADD HL,DE
        RET
load_plan_cluster:
        CALL plan_address
        LD DE,cluster
        JP copy32

; FAT changes must agree with the expected old lower 28 bits in every
; mirrored copy. Changes cover planned free clusters, a directory EOC,
; or reclamation of the validated old file after confirmed replacement.
fat_set:
        CALL check_old_fats
fat_copies_checked:
        CALL fat_address
        XOR A
        LD (fat_copy_index),A
fat_set_copy:
        CALL read_sector
        CALL read_fat_value
        LD HL,fat_value
        LD DE,fat_old
        CALL compare32
        JP NZ,io_error
        LD HL,(fat_offset)
        LD DE,BUF
        ADD HL,DE
        PUSH HL
        LD DE,3
        ADD HL,DE
        LD A,(HL)
        AND 0xF0
        LD B,A
        LD A,(fat_new+3)
        OR B
        LD (HL),A
        POP DE
        LD HL,fat_new
        LD BC,3
        LDIR
        CALL write_sector
        LD A,(fat_flags)
        BIT 7,A
        RET NZ
        LD A,(fat_copy_index)
        INC A
        LD (fat_copy_index),A
        LD B,A
        LD A,(fat_count)
        CP B
        RET Z
        LD HL,lba
        LD DE,fat_size
        CALL add32
        JP fat_set_copy

save_commit:
        LD A,(seq_active)
        OR A
        JP NZ,seq_append
        LD A,(save_pending)
        OR A
        JP Z,io_error
        LD HL,dir_cluster
        LD DE,save_dir
        CALL compare32
        JP NZ,io_error
        LD HL,(caller_count)
        LD DE,(save_length)
        OR A
        SBC HL,DE
        JP NZ,io_error
        LD HL,(caller_pointer)
        LD (save_source),HL
        ADD HL,DE
        JP C,io_error
        LD DE,0xFF00
        OR A
        SBC HL,DE
        JP NC,io_error
        ; Check the plan again before the first disk mutation.
        XOR A
        LD (write_cluster_index),A
save_recheck:
        LD A,(write_cluster_index)
        CALL plan_address
        LD DE,alloc_cursor
        CALL copy32
        CALL fat_get
        CALL fat_is_zero
        JP NZ,io_error
        CALL verify_free_mirror
        LD A,(write_cluster_index)
        INC A
        LD (write_cluster_index),A
        LD B,A
        LD A,(plan_count)
        CP B
        JP NZ,save_recheck
        CALL invalidate_fsinfo
        ; Initialise all allocated file/directory cluster sectors to zero,
        ; then write header+payload while these clusters are still invisible.
        XOR A
        LD (write_cluster_index),A
        LD HL,(save_total)
        LD (save_left),HL
        LD HL,save_header
        LD (write_pointer),HL
save_write_cluster:
        LD A,(write_cluster_index)
        CALL load_plan_cluster
        CALL cluster_lba
        LD A,(spc)
        LD (write_cluster_sectors),A
save_write_sector:
        LD HL,BUF
        LD DE,BUF+1
        LD BC,511
        LD (HL),0
        LDIR
        LD HL,BUF
        LD BC,512
save_fill_byte:
        LD DE,(save_left)
        LD A,D
        OR E
        JP Z,save_sector_filled
        LD DE,(write_pointer)
        LD A,(DE)
        LD (HL),A
        INC DE
        INC HL
        LD (write_pointer),DE
        PUSH HL
        LD HL,(save_left)
        DEC HL
        LD (save_left),HL
        LD DE,(save_length)
        OR A
        SBC HL,DE
        JP NZ,save_still_header
        LD DE,(save_source)
        LD (write_pointer),DE
save_still_header:
        POP HL
        DEC BC
        LD A,B
        OR C
        JP NZ,save_fill_byte
save_sector_filled:
        CALL write_sector
        LD HL,lba
        CALL increment32
        LD A,(write_cluster_sectors)
        DEC A
        LD (write_cluster_sectors),A
        JP NZ,save_write_sector
        LD A,(write_cluster_index)
        INC A
        LD (write_cluster_index),A
        LD B,A
        LD A,(plan_count)
        CP B
        JP NZ,save_write_cluster
        ; Allocate the complete new chain; pre-existing FAT entries are
        ; still unchanged. Mirror each modification and verify it on disk.
        XOR A
        LD (write_cluster_index),A
save_chain_loop:
        LD A,(write_cluster_index)
        CALL plan_address
        LD DE,alloc_cursor
        CALL copy32
        LD HL,fat_old
        CALL zero32
        LD HL,eoc32
        LD DE,fat_new
        CALL copy32
        LD A,(write_cluster_index)
        INC A
        LD B,A
        LD A,(save_clusters)
        CP B
        JP Z,save_chain_set
        JP C,save_chain_set
        LD A,B
        CALL plan_address
        LD DE,fat_new
        CALL copy32
save_chain_set:
        CALL fat_set
        LD A,(write_cluster_index)
        INC A
        LD (write_cluster_index),A
        LD B,A
        LD A,(plan_count)
        CP B
        JP NZ,save_chain_loop
        CALL flush_disk
save_publish:
        LD A,(dir_grow)
        OR A
        JP Z,publish_existing_slot
        LD A,(save_clusters)
        CALL load_plan_cluster
        CALL cluster_lba
        LD HL,lba
        LD DE,dir_slot_lba
        CALL copy32
        LD HL,0
        LD (dir_slot_offset),HL
        CALL publish_entry
        ; Link the initialised directory extension as the final operation.
        LD HL,dir_tail
        LD DE,alloc_cursor
        CALL copy32
        LD HL,dir_link_old
        LD DE,fat_old
        CALL copy32
        LD A,(save_clusters)
        CALL plan_address
        LD DE,fat_new
        CALL copy32
        CALL fat_set
        JP save_done
publish_existing_slot:
        LD A,(terminator_needed)
        OR A
        JP Z,publish_normal
        LD HL,terminator_lba
        LD DE,lba
        CALL copy32
        CALL read_sector
        XOR A
        LD (BUF),A
        CALL write_sector
publish_normal:
        CALL publish_entry
save_done:
        CALL flush_disk
        CALL replace_release
        XOR A
        LD (save_pending),A
        LD (file_open),A
        LD (0x38BF),A
        LD (0x38C0),A
        RET
publish_entry:
        LD HL,dir_slot_lba
        LD DE,lba
        CALL copy32
        CALL read_sector
        LD HL,(dir_slot_offset)
        LD DE,BUF
        ADD HL,DE
publish_check:
        LD A,(dir_grow)
        OR A
        JP NZ,publish_slot_valid
        CALL replace_slot_check
        LD A,(replace_pending)
        OR A
        JP NZ,publish_slot_valid
        LD A,(HL)
        OR A
        JP Z,publish_slot_valid
        CP 0xE5
        JP NZ,io_error
publish_slot_valid:
        PUSH HL
        LD D,H
        LD E,L
        INC DE
        LD BC,31
        LD (HL),0
        LDIR
        POP DE
        PUSH DE
        LD HL,save_name
        LD BC,11
        LDIR
        LD A,0x20
        LD (DE),A
        POP HL
        LD DE,20
        ADD HL,DE
        LD DE,(PLAN+2)
        LD (HL),E
        INC HL
        LD (HL),D
        LD DE,5
        ADD HL,DE
        LD DE,(PLAN)
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD DE,(save_total)
        LD (HL),E
        INC HL
        LD (HL),D
        LD A,(slot_end)
        OR A
        JP Z,publish_sector
        LD HL,(dir_slot_offset)
        LD DE,480
        OR A
        SBC HL,DE
        JP Z,publish_sector
        LD HL,(dir_slot_offset)
        LD DE,BUF+32
        ADD HL,DE
        LD (HL),0
publish_sector:
        JP write_sector

; Unknown free counts/hints force host FAT drivers to recompute them. Only
; valid FSInfo records inside the reserved area are changed, before FAT.
invalidate_fsinfo:
        LD HL,(fsinfo_number)
        LD (fsinfo_target),HL
        CALL invalidate_one_info
        LD HL,(fsinfo_number)
        LD DE,(backup_number)
        LD A,D
        OR E
        RET Z
        INC DE
        LD A,D
        OR E
        RET Z
        DEC DE
        ADD HL,DE
        RET C
        LD (fsinfo_target),HL
invalidate_one_info:
        LD HL,(fsinfo_target)
        LD A,H
        OR L
        RET Z
        LD DE,(reserved)
        OR A
        SBC HL,DE
        RET NC
        LD HL,partition_start
        LD DE,lba
        CALL copy32
        LD HL,lba
        LD DE,(fsinfo_target)
        CALL add_word
        CALL read_sector
        LD HL,(BUF)
        LD DE,0x5252
        OR A
        SBC HL,DE
        RET NZ
        LD HL,(BUF+2)
        LD DE,0x4161
        OR A
        SBC HL,DE
        RET NZ
        LD HL,(BUF+484)
        LD DE,0x7272
        OR A
        SBC HL,DE
        RET NZ
        LD HL,(BUF+486)
        LD DE,0x6141
        OR A
        SBC HL,DE
        RET NZ
        LD HL,(BUF+508)
        LD A,H
        OR L
        RET NZ
        LD HL,(BUF+510)
        LD DE,0xAA55
        OR A
        SBC HL,DE
        RET NZ
        LD HL,BUF+488
        LD DE,BUF+489
        LD BC,7
        LD (HL),255
        LDIR
        JP write_sector

write_sector:
        PUSH BC
        PUSH DE
        PUSH HL
        XOR A
        LD (fat_cache_valid),A
        LD HL,lba
        LD DE,partition_start
        CALL compare32
        JP C,disk_error
        LD HL,lba
        LD DE,partition_end
        CALL compare32
        JP NC,disk_error
        LD A,0x30
        CALL begin_write_transfer
        JP C,disk_error
        LD HL,BUF
        LD BC,0x0028
        OTIR
        LD B,0
        OTIR
        XOR A
        LD (wanted_drq),A
        CALL wait_status
        JP C,disk_error
        ; Verify the original sector buffer in place while draining the
        ; complete readback transfer, including after a mismatched byte.
        LD A,0x20
        CALL begin_write_transfer
        JP C,disk_error
        LD HL,BUF
        LD BC,0x0028
        LD DE,2
verify_sector_byte:
        IN A,(C)
        CP (HL)
        JP Z,verify_byte_equal
        LD D,1
verify_byte_equal:
        INC HL
        DJNZ verify_sector_byte
        DEC E
        JP NZ,verify_sector_byte
        LD A,D
        LD (verify_bad),A
        XOR A
        LD (wanted_drq),A
        CALL wait_status
        JP C,disk_error
        LD A,(verify_bad)
        OR A
        JP NZ,disk_error
        POP HL
        POP DE
        POP BC
        RET
begin_write_transfer:
        LD (write_command),A
        LD A,(lba+3)
        AND 0xF0
        JP NZ,transfer_address_bad
        LD A,(lba+3)
        OR 0xE0
        OUT (0x2E),A
        CALL settle
        XOR A
        LD (post_command),A
        LD (wanted_drq),A
        CALL wait_status
        RET C
        LD A,1
        OUT (0x2A),A
        LD A,(lba)
        OUT (0x2B),A
        LD A,(lba+1)
        OUT (0x2C),A
        LD A,(lba+2)
        OUT (0x2D),A
        LD A,(write_command)
        OUT (0x2F),A
        CALL settle
        LD A,1
        LD (post_command),A
        LD A,8
        LD (wanted_drq),A
        JP wait_status
transfer_address_bad:
        SCF
        RET
flush_disk:
        LD A,(flush_required)
        OR A
        RET Z
        LD A,0xE7
        OUT (0x2F),A
        CALL settle
        LD A,1
        LD (post_command),A
        XOR A
        LD (wanted_drq),A
        CALL wait_status
        JP C,disk_error
        RET
save_extension: DEFM "MZF"
exists_text: DEFM "FILE EXISTS - SAVE REFUSED"
        DB 13,0
bad_name_text: DEFM "SAVE NAME MUST BE 1-8 LETTERS/DIGITS"
        DB 13,0
full_text: DEFM "NO SPACE OR DIRECTORY FULL"
        DB 13,0
