; Sequential data files retain BASIC's native 1024-byte record buffering.
; OPEN plans free clusters without allocating them. Only CLOSE links the
; chain and publishes the directory entry. Maximum planned payload 30 KiB.
seq_begin:
        LD HL,0
        LD (save_length),HL
        LD HL,128
        LD (save_total),HL
        XOR A
        LD (save_header+18),A
        LD (save_header+19),A
        LD (write_cluster_index),A
        LD (within_cluster),A
seq_begin_buffer:
        CALL seq_clear
        LD HL,save_header
        LD DE,BUF
        LD BC,128
        LDIR
        LD (file_pointer),DE
        XOR A
        RET
seq_clear:
        LD HL,BUF
        LD DE,BUF+1
        LD BC,511
        LD (HL),0
        LDIR
        LD HL,BUF
        LD (file_pointer),HL
        RET
seq_append:
        LD A,(save_pending)
        OR A
        JP Z,io_error
        LD HL,(save_length)
        LD DE,(caller_count)
        ADD HL,DE
        JP C,io_error
        LD DE,30721
        OR A
        SBC HL,DE
        JP NC,io_error
seq_append_byte:
        LD HL,(caller_count)
        LD A,H
        OR L
        JP Z,seq_appended
        DEC HL
        LD (caller_count),HL
        LD HL,(caller_pointer)
        LD A,(HL)
        INC HL
        LD (caller_pointer),HL
        LD HL,(file_pointer)
        LD (HL),A
        INC HL
        LD (file_pointer),HL
        LD A,H
        OR L
        CALL Z,seq_flush
        LD HL,(save_length)
        INC HL
        LD (save_length),HL
        JP seq_append_byte
seq_appended:
        LD A,(seq_operation)
        AND 4
        JP NZ,seq_close
        XOR A
        RET
seq_flush:
        LD A,(write_cluster_index)
        CALL load_plan_cluster
        CALL cluster_lba
        LD A,(within_cluster)
        LD E,A
        LD D,0
        LD HL,(lba)
        ADD HL,DE
        LD (lba),HL
        JR NC,seq_flush_address
        LD HL,(lba+2)
        INC HL
        LD (lba+2),HL
seq_flush_address:
        CALL write_sector
        LD A,(within_cluster)
        INC A
        LD B,A
        LD A,(spc)
        CP B
        LD A,B
        JR NZ,seq_flush_next
        LD HL,write_cluster_index
        INC (HL)
        XOR A
seq_flush_next:
        LD (within_cluster),A
        JP seq_clear
seq_close:
        LD HL,(file_pointer)
        LD DE,BUF
        OR A
        SBC HL,DE
        CALL NZ,seq_flush
        ; Replace the provisional header length after flushing the last data.
        XOR A
        CALL load_plan_cluster
        CALL cluster_lba
        CALL read_sector
        LD HL,(save_length)
        LD (BUF+18),HL
        CALL write_sector
        LD HL,(save_length)
        LD DE,128
        ADD HL,DE
        LD (save_total),HL
        DEC HL
        LD A,(cluster_shift)
        ADD A,9
        LD B,A
seq_close_divide:
        SRL H
        RR L
        DJNZ seq_close_divide
        INC L
        LD A,(save_clusters)
        PUSH HL
        CALL plan_address
        POP BC
        LD A,C
        LD (save_clusters),A
        PUSH HL
        CALL plan_address
        EX DE,HL
        POP HL
        LD A,(dir_grow)
        OR A
        JP Z,seq_close_plan
        ; Move the reserved directory-extension cluster behind the used file.
        CALL copy32
        LD A,(save_clusters)
        CALL load_plan_cluster
        CALL cluster_lba
        CALL seq_clear
        LD A,(spc)
        LD B,A
seq_zero_directory:
        CALL write_sector
        LD HL,lba
        CALL increment32
        DJNZ seq_zero_directory
seq_close_plan:
        LD A,(dir_grow)
        LD B,A
        LD A,(save_clusters)
        ADD A,B
        LD (plan_count),A
        CALL invalidate_fsinfo
        XOR A
        LD (seq_active),A
        LD (write_cluster_index),A
        JP save_chain_loop
