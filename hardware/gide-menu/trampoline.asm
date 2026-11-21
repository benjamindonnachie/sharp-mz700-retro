; SPDX-License-Identifier: GPL-3.0-or-later
; Copy staged data safely even when destination overlaps the staging area.
; User programs occupy 1000..CFFF; this code lives in shadow RAM at F000.
        ORG 0xF000
start:
        DI
        LD SP,0x0FF0
        LD HL,0x3000
dest_instruction:
        LD DE,0
count_instruction:
        LD BC,0
        LD A,D
        CP 0x30
        JP C,forward
        DEC BC
        ADD HL,BC
        EX DE,HL
        ADD HL,BC
        EX DE,HL
        INC BC
        LDDR
        JP copied
forward:
        LDIR
copied:
        LD A,0xD3
        LD (0xD3E4),A
        LD A,0xE3
        LD (0xD3E5),A
        LD A,0xE9
        LD (0xD3E6),A
        LD SP,0x10F0
        XOR A
        OUT (0xE2),A
exec_instruction:
        LD HL,0
        JP 0xD3E4
program_end:
        DB 0
