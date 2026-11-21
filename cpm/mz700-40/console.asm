; SPDX-License-Identifier: GPL-3.0-or-later
; Keep the attributes initialised by the Sharp ROM; no BIOS colour choice.
; Native banked 40-column VRAM, original Sharp font, software cursor and scroll.
console_init:
        XOR A
        LD (escape_state),A
        LD (terminal_error),A
        LD (cursor_drawn),A
        LD A,1
        LD (cursor_visible),A
        CALL clear_screen
        RET

console_output:
        PUSH BC
        PUSH DE
        PUSH HL
        CALL hide_cursor
        LD A,C
        CALL output_character
        CALL update_cursor
        POP HL
        POP DE
        POP BC
        RET

output_character:
        LD D,A
        LD A,(escape_state)
        OR A
        LD A,D
        JP NZ,escape_character
        CP 27
        JR Z,begin_escape
        CP 12                   ; form feed
        JP Z,clear_screen
        CP 26                   ; ADM3A clear
        JP Z,clear_screen
        CP 13
        JR Z,carriage_return
        CP 10
        JP Z,line_feed
        CP 8
        JR Z,backspace
        CP 127
        JR Z,backspace
        CP 9
        JR Z,tab
        CP 30                   ; ADM3A home
        JP Z,home
        CP 32
        RET C                   ; other controls, including BEL, ignored
        PUSH AF
        CALL screen_address
        POP AF
        CALL draw_character
        LD A,(cursor_column)
        INC A
        CP 40
        JR Z,wrap_line
        LD (cursor_column),A
        RET
begin_escape:
        LD A,1
        LD (escape_state),A
        RET
carriage_return:
        XOR A
        LD (cursor_column),A
        RET
backspace:
        LD A,(cursor_column)
        OR A
        RET Z
        DEC A
        LD (cursor_column),A
        RET
wrap_line:
        XOR A
        LD (cursor_column),A
line_feed:
        LD A,(cursor_row)
        INC A
        CP 25
        JR Z,scroll_up
        LD (cursor_row),A
        RET
scroll_up:
        ; Linear stock VRAM: 40 characters per row, 25 rows.
        LD HL,0xD028
        LD DE,0xD000
        LD BC,960
        CALL mmio_copy
        LD HL,0xD828
        LD DE,0xD800
        LD BC,960
        CALL mmio_copy
        LD HL,960
        LD BC,40
        JP blank_cells

tab:
        LD A,(cursor_column)
        AND 7
        LD B,A
        LD A,8
        SUB B
        LD B,A
next_tab_space:
        PUSH BC
        LD A,32
        CALL output_character
        POP BC
        DJNZ next_tab_space
        RET

home:
        XOR A
        LD (cursor_column),A
        LD (cursor_row),A
        RET
clear_screen:
        CALL home
        XOR A
        LD (cursor_drawn),A
        LD HL,0xD000
        CALL mmio_write
        LD DE,0xD001
        LD BC,2047
        CALL mmio_copy
        RET
clear_eol:
        CALL logical_position
        PUSH HL
        LD A,(cursor_column)
        LD B,A
        LD A,40
        SUB B
        LD C,A
        LD B,0
        POP HL
        JP blank_cells
clear_eos:
        CALL logical_position
        PUSH HL
        EX DE,HL
        LD HL,1000
        OR A
        SBC HL,DE
        LD B,H
        LD C,L
        POP HL
blank_cells:
        LD A,B
        OR C
        RET Z
        PUSH BC
        PUSH HL
        CALL physical_address_screen
        XOR A
        CALL mmio_write
        POP HL
        INC HL
        POP BC
        DEC BC
        JR blank_cells

; VT52 ESC A/B/C/D/H/E/J/K/Y, ADM3A ESC= row+32 col+32.
escape_character:
        LD A,(escape_state)
        CP 2
        JR Z,address_row
        CP 3
        JR Z,address_column
        XOR A
        LD (escape_state),A
        LD A,D
        CP 0x59
        JR Z,address_begin
        CP 0x3d
        JR Z,address_begin
        CP 0x45
        JP Z,clear_screen
        CP 0x48
        JP Z,home
        CP 0x4a
        JP Z,clear_eos
        CP 0x4b
        JP Z,clear_eol
        CP 0x41
        JR Z,cursor_up
        CP 0x42
        JR Z,cursor_down
        CP 0x43
        JR Z,cursor_right
        CP 0x44
        JP Z,backspace
        CP 0x65
        JR Z,cursor_on
        CP 0x66
        JR Z,cursor_off
        RET
address_begin:
        LD A,2
        LD (escape_state),A
        RET
address_row:
        LD A,D
        SUB 32
        JR C,bad_row
        CP 25
        JR C,row_ok
bad_row:
        XOR A
row_ok:
        LD (cursor_row),A
        LD A,3
        LD (escape_state),A
        RET
address_column:
        LD A,D
        SUB 32
        JR C,bad_column
        CP 40
        JR C,column_ok
bad_column:
        XOR A
column_ok:
        LD (cursor_column),A
        XOR A
        LD (escape_state),A
        RET
cursor_up:
        LD A,(cursor_row)
        OR A
        RET Z
        DEC A
        LD (cursor_row),A
        RET
cursor_down:
        LD A,(cursor_row)
        CP 24
        RET Z
        INC A
        LD (cursor_row),A
        RET
cursor_right:
        LD A,(cursor_column)
        CP 39
        RET Z
        INC A
        LD (cursor_column),A
        RET
cursor_on:
        LD A,1
        LD (cursor_visible),A
        RET
cursor_off:
        XOR A
        LD (cursor_visible),A
        RET

; Row/column logical index, without touching the CRTC or CPU memory map.
logical_position:
        LD HL,0
        LD DE,40
        LD A,(cursor_row)
        OR A
        JR Z,add_column
        LD B,A
row_times_40:
        ADD HL,DE
        DJNZ row_times_40
add_column:
        LD A,(cursor_column)
        LD E,A
        LD D,0
        ADD HL,DE
        RET
screen_address:
        CALL logical_position
        JP physical_address_screen
 ; Stock display is linear: logical index 0..999 -> D000..D3E7.
physical_address_screen:
        LD DE,0xD000
        ADD HL,DE
        RET
; HL=physical char cell, A=CP/M byte. The original SUC table maps the
; complete byte repertoire into the Sharp character generator codes.
draw_character:
        PUSH HL
        LD E,A
        LD D,0
        LD HL,suc_F3D6
        ADD HL,DE
        LD A,(HL)
        POP HL
        CALL mmio_write
        RET
hide_cursor:
        LD A,(cursor_drawn)
        OR A
        RET Z
        LD HL,(cursor_address)
        LD A,(cursor_saved_character)
        CALL mmio_write
        XOR A
        LD (cursor_drawn),A
        RET
update_cursor:
        ; CONST must retain the scanner's register/flag contract. The safe
        ; MMIO wrappers also retain caller IFF across upper-bank switching.
        PUSH AF
        PUSH BC
        PUSH DE
        PUSH HL
        CALL cursor_tick
cursor_tick_done:
        POP HL
        POP DE
        POP BC
        POP AF
        RET
cursor_tick:
        LD A,(cursor_visible)
        OR A
        JP Z,hide_cursor
        LD HL,0xE002
        CALL mmio_read
        BIT 6,A                 ; Sharp556 blink output; zero displays cursor
        JP NZ,hide_cursor
        LD A,(cursor_drawn)
        OR A
        RET NZ                  ; do not save our own glyph over the character
        CALL screen_address
        LD (cursor_address),HL
        CALL mmio_read
        LD (cursor_saved_character),A
        LD A,0xEF               ; original1Z-013A cursor display glyph
        CALL mmio_write
        LD A,1
        LD (cursor_drawn),A
        RET
cursor_row: DB 0
cursor_column: DB 0
escape_state: DB 0
terminal_error: DB 0
cursor_visible: DB 1
cursor_drawn: DB 0
cursor_address: DW 0
cursor_saved_character: DB 0
console_end: DB 0
