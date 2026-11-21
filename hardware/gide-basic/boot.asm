; Cold-only GIDE mount; discarded before BASIC's user RAM is initialised.
boot_entry:
        LD (driver_stack),SP
        LD A,1
        LD (booting),A
        LD A,5
        LD (init_attempts),A
        CALL initialise
        LD A,1
        LD (mounted),A
        XOR A
        LD (booting),A
        RET
boot_error:
        XOR A
        LD (mounted),A
        LD (booting),A
        LD SP,(driver_stack)
        RET
bad_mbr:
bad_bpb:
no_fat32:
init_error:
        JP boot_error
fat_selected:
        LD HL,root_cluster
        LD DE,dir_cluster
        CALL copy32
        LD HL,cwd_path
        LD (HL),47
        INC HL
        LD (HL),0
        RET

