; Resident BASIC hooks occupy verified unused bytes in the UniCard patch.
        ORG 0x3C50
name_hook: LD A,0
        JP gateway
header_hook: LD A,1
        JP gateway
read_hook: LD A,2
        JP gateway
chdir_hook: LD A,3
        JP gateway
cwd_hook: LD A,4
        JP gateway
save_header_hook: LD A,5
        JP gateway
save_data_hook:
        LD (seq_operation),A
        LD A,6
        JP gateway
free_hook:
        PUSH AF
        LD A,7
        CALL gateway
        JR C,free_hook_failed
        LD BC,(0x3D80)
        POP AF
        RET
free_hook_failed:
        INC SP
        INC SP
        RET
header_error:
        POP HL
        POP BC
        EI
        SCF
        RET
select_hook:
        OR A
        JR NZ,select_position
        LD (0x38C0),A
select_position:
        LD A,H
        CP 0x28
        JR NZ,select_done
        LD A,L
        OR A
        JR Z,cwd_hook
select_done:
        XOR A
        RET
gateway:
        DI
        LD (saved_stack),SP
        OUT (0xE1),A
        LD SP,STACK_TOP
        PUSH BC
        PUSH DE
        PUSH HL
        PUSH IX
        PUSH IY
        CALL DRIVER_ENTRY
        POP IY
        POP IX
        POP HL
        POP DE
        POP BC
        LD SP,(saved_stack)
        OUT (0xE1),A
        EI
        RET
saved_stack: DW 0
