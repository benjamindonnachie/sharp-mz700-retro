draw:
        XOR A
        LD (menu_ready),A
        LD A,(need_sort)
        OR A
        CALL NZ,sort_catalogue
        XOR A
        LD (need_sort),A
        LD A,(pending_cpm)
        OR A
        JP Z,draw_normal
        JP find_cpm
draw_normal:
        XOR A
        OUT (0xE3),A
        LD A,0x16
        CALL putc
        LD HL,0xD800
        LD DE,0xD801
        LD BC,999
        LD (HL),0x71
        LDIR
        LD HL,tui_title
        CALL puts
        CALL print_path
        CALL newline
        LD HL,tui_items
        CALL puts
        LD A,(count)
        CALL decimal
        LD HL,tui_page
        CALL puts
        LD A,(selection)
        LD B,0
page_divide:
        CP 24
        JP C,page_divided
        SUB 24
        INC B
        JP page_divide
page_divided:
        LD C,A
        LD A,(selection)
        SUB C
        LD (page_base),A
        LD A,B
        LD (page),A
        INC A
        CALL decimal
        LD A,0x2F
        CALL putc
        LD A,(count)
        OR A
        JP Z,one_page
        DEC A
        LD B,1
page_count_loop:
        CP 24
        JP C,page_count_done
        SUB 24
        INC B
        JP page_count_loop
one_page:
        LD B,1
page_count_done:
        LD A,B
        CALL decimal
        CALL newline
        CALL newline
        XOR A
        LD (grid_row),A
grid_loop:
        XOR A
        LD (grid_column),A
        CALL draw_cell
        LD A,1
        LD (grid_column),A
        CALL draw_cell
        LD A,(grid_row)
        INC A
        LD (grid_row),A
        CP 12
        JP NZ,grid_loop
        LD HL,tui_line
        CALL puts
        LD A,(actions_open)
        OR A
        JP NZ,draw_actions
        LD A,(count)
        OR A
        JP Z,draw_empty
        LD HL,tui_selected
        CALL puts
        JP draw_normal_help
draw_empty:
        LD HL,tui_empty
        CALL puts
draw_normal_help:
        CALL newline
        CALL newline
        LD HL,tui_help
        CALL puts
        JP draw_finished
draw_actions:
        LD HL,tui_action_title
        CALL puts
        LD HL,tui_actions
        CALL puts
        LD A,(action_selection)
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        LD DE,0xDAF8            ; row 19, eight attributes per action
        ADD HL,DE
        LD (HL),0x17
        LD D,H
        LD E,L
        INC DE
        LD BC,7
        LDIR
        LD HL,tui_action_help
        CALL puts
draw_finished:
        CALL draw_selected_title
        LD A,(last_key)
        OR A
        CALL NZ,key_pause
        LD A,1
        LD (menu_ready),A
keys:
        CALL 0x001B
        OR A
        JP Z,key_released
        LD C,A
        LD A,(last_key)
        CP C
        JP NZ,key_new
        LD A,C
        CP 0x11
        JP C,keys
        CP 0x15
        JP NC,keys
key_new:
        LD A,C
        LD (last_key),A
        CP 0x20
        JP Z,toggle_actions
        LD B,A
        LD A,(actions_open)
        OR A
        LD A,B
        JP NZ,action_keys
        CP 0x66                 ; monitor GETKY Return, not ASCII CR
        JP Z,open_selection
        CP 13
        JP Z,open_selection
        CP 0x60                 ; Sharp DEL / host Backspace
        JP Z,up
        CP 8
        JP Z,up
        CP 0x12
        JP Z,cursor_up
        CP 0x11
        JP Z,cursor_down
        CP 0x14
        JP Z,cursor_left
        CP 0x13
        JP Z,cursor_right
        JP keys
key_released:
        XOR A
        LD (last_key),A
        JP keys
toggle_actions:
        LD A,(actions_open)
        XOR 1
        LD (actions_open),A
        XOR A
        LD (action_selection),A
        JP draw
action_keys:
        CP 0x60
        JP Z,toggle_actions
        CP 8
        JP Z,toggle_actions
        CP 0x14
        JP Z,action_left
        CP 0x13
        JP Z,action_right
        CP 0x66
        JP Z,action_enter
        CP 13
        JP Z,action_enter
        JP keys
action_left:
        LD A,(action_selection)
        OR A
        JP Z,keys
        DEC A
        JP action_set
action_right:
        LD A,(action_selection)
        CP 4
        JP Z,keys
        INC A
action_set:
        LD (cursor_next),A
        LD A,(action_selection)
        LD E,0x71
        CALL paint_action
        LD A,(cursor_next)
        LD (action_selection),A
        LD E,0x17
        CALL paint_action
        CALL key_pause
        JP keys
action_enter:
        XOR A
        LD (actions_open),A
        LD A,(action_selection)
        OR A
        JP Z,cpm
        DEC A
        JP Z,basic
        DEC A
        JP Z,rescan
        DEC A
        JP Z,up
        JP 0
cursor_up:
        LD A,(selection)
        CP 2
        JP C,keys
        SUB 2
        JP cursor_set
cursor_down:
        LD A,(selection)
        ADD A,2
        JP cursor_check
cursor_left:
        LD A,(selection)
        BIT 0,A
        JP Z,keys
        DEC A
        JP cursor_set
cursor_right:
        LD A,(selection)
        BIT 0,A
        JP NZ,keys
        INC A
cursor_check:
        LD B,A
        LD A,(count)
        CP B
        JP C,keys
        JP Z,keys
        LD A,B
cursor_set:
        LD (cursor_next),A
        LD B,A
        LD A,(page_base)
        LD C,A
        LD A,B
        SUB C
        JP C,cursor_new_page
        CP 24
        JP NC,cursor_new_page
        LD A,(selection)
        LD E,0x71
        CALL paint_selection
        LD A,(cursor_next)
        LD (selection),A
        LD E,0x17
        CALL paint_selection
        CALL draw_selected_title
        CALL key_pause
        JP keys
cursor_new_page:
        LD A,(cursor_next)
        LD (selection),A
        JP draw
open_selection:
        LD A,(selection)
        JP select_index

draw_cell:
        LD A,(grid_row)
        ADD A,A
        LD B,A
        LD A,(grid_column)
        ADD A,B
        LD B,A
        LD A,(page_base)
        ADD A,B
        LD (cell_index),A
        XOR A
        LD (cell_written),A
        LD A,(cell_index)
        LD B,A
        LD A,(count)
        CP B
        JP C,cell_padding
        JP Z,cell_padding
        LD A,0x20
cell_prefix:
        CALL cell_putc
        LD A,0x20
        CALL cell_putc
        LD A,(cell_index)
        CALL table_address
        LD (cell_pointer),HL
        CALL entry_title
        LD B,17
cell_basename:
        LD A,(HL)
        OR A
        JP Z,cell_type
        INC HL
        CALL cell_putc
        DJNZ cell_basename
cell_type:
        LD HL,(cell_pointer)
        LD DE,11
        ADD HL,DE
        BIT 4,(HL)
        LD A,0x2F
        CALL NZ,cell_putc
cell_padding:
        LD A,(cell_written)
        CP 20
        JP NC,cell_colour
        LD A,0x20
        CALL cell_putc
        JP cell_padding
cell_colour:
        LD A,(selection)
        LD B,A
        LD A,(cell_index)
        CP B
        JP NZ,cell_done
        LD B,A
        LD A,(count)
        CP B
        JP Z,cell_done
        JP C,cell_done
        LD A,(grid_row)
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL               ; row * 8
        LD D,H
        LD E,L
        ADD HL,HL
        ADD HL,HL               ; row * 32
        ADD HL,DE               ; row * 40, the physical screen stride
        LD DE,0xD8C8            ; grid begins at row 5
        ADD HL,DE
        LD A,(grid_column)
        OR A
        JP Z,cell_colour_fill
        LD DE,20
        ADD HL,DE
cell_colour_fill:
        LD (HL),0x17
        LD D,H
        LD E,L
        INC DE
        LD BC,19
        LDIR
cell_done:
        RET
cell_putc:
        PUSH AF
        LD A,(cell_written)
        INC A
        LD (cell_written),A
        POP AF
        JP putc

; Cursor motion within a page changes attributes only. Avoiding a complete
; ROM text redraw keeps the real 3.55 MHz machine responsive to key repeat.
paint_selection:
        LD B,A
        LD A,E
        LD (paint_colour),A
        LD A,(page_base)
        LD C,A
        LD A,B
        SUB C
        LD B,A
        AND 1
        LD (paint_column),A
        LD A,B
        SRL A
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL               ; row * 8
        LD D,H
        LD E,L
        ADD HL,HL
        ADD HL,HL               ; row * 32
        ADD HL,DE               ; row * 40, the physical screen stride
        LD DE,0xD8C8
        ADD HL,DE
        LD A,(paint_column)
        OR A
        JP Z,paint_cell_fill
        LD DE,20
        ADD HL,DE
paint_cell_fill:
        LD A,(paint_colour)
        LD (HL),A
        LD D,H
        LD E,L
        INC DE
        LD BC,19
        LDIR
        RET
paint_action:
        LD B,A
        LD A,E
        LD (paint_colour),A
        LD A,B
        LD L,A
        LD H,0
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        LD DE,0xDAF8
        ADD HL,DE
        LD A,(paint_colour)
        LD (HL),A
        LD D,H
        LD E,L
        INC DE
        LD BC,7
        LDIR
        RET
key_pause:
        ; About 180 ms at 3.55 MHz. Bound cursor repeat without relying on
        ; RTC settings or making Return/Space repeat as fast as key scans.
        LD BC,24576
key_pause_loop:
        DEC BC
        LD A,B
        OR C
        JR NZ,key_pause_loop
        RET

print_path:
        LD A,(depth)
        OR A
        JP NZ,path_nonroot
        LD A,0x2F
        JP putc
path_nonroot:
        CP 4
        LD A,1
        JP C,path_start
        LD HL,tui_ellipsis
        CALL puts
        LD A,(depth)
        SUB 2
path_start:
        LD (path_index),A
path_parent:
        LD B,A
        LD A,(depth)
        CP B
        JP Z,path_current
        LD A,0x2F
        CALL putc
        LD A,(path_index)
        CALL stack_address
        LD DE,4
        ADD HL,DE
        CALL print_name
        LD A,(path_index)
        INC A
        LD (path_index),A
        JP path_parent
path_current:
        LD A,0x2F
        CALL putc
        LD HL,folder_name
        JP print_name

sort_catalogue:
        LD A,(count)
        CP 2
        RET C
sort_again:
        XOR A
        LD (sort_changed),A
        LD A,(count)
        DEC A
        LD (sort_pairs),A
        LD HL,TABLE
        LD (sort_left),HL
sort_pair:
        LD HL,(sort_left)
        LD DE,32
        ADD HL,DE
        LD (sort_right),HL
        CALL compare_entries
        JP C,sort_next
        JP Z,sort_next
        LD HL,(sort_left)
        LD DE,(sort_right)
        LD B,32
sort_swap:
        LD A,(DE)
        LD C,A
        LD A,(HL)
        LD (DE),A
        LD (HL),C
        INC HL
        INC DE
        DJNZ sort_swap
        LD A,1
        LD (sort_changed),A
sort_next:
        LD HL,(sort_right)
        LD (sort_left),HL
        LD A,(sort_pairs)
        DEC A
        LD (sort_pairs),A
        JP NZ,sort_pair
        LD A,(sort_changed)
        OR A
        JP NZ,sort_again
        RET
compare_entries:
        LD HL,(sort_left)
        LD DE,11
        ADD HL,DE
        LD A,(HL)
        AND 0x10
        LD C,A
        LD HL,(sort_right)
        ADD HL,DE
        LD A,(HL)
        AND 0x10
        CP C                    ; folders first, alphabetic within each group
        RET NZ
        LD HL,(sort_left)
        CALL entry_title
        PUSH HL
        LD HL,(sort_right)
        CALL entry_title
        EX DE,HL
        POP HL
        LD B,117
compare_entry_name:
        LD A,(DE)
        LD C,A
        LD A,(HL)
        CP C
        RET NZ
        OR A
        RET Z
        INC HL
        INC DE
        DJNZ compare_entry_name
        RET

tui_title: DEFM " GIDE FILE MANAGER"
        DB 13
        DEFM "---------------------------------------"
        DB 13
        DEFM " FOLDER: "
        DB 0
tui_line: DEFM "---------------------------------------"
        DB 13,0
tui_items: DEFM " ITEMS: "
        DB 0
tui_page: DEFM "    PAGE "
        DB 0
tui_selected: DEFM " RETURN OPENS THE HIGHLIGHTED ITEM"
        DB 0
tui_empty: DEFM " EMPTY FOLDER"
        DB 0
tui_help: DEFM " CURSORS MOVE    RETURN OPEN"
        DB 13
        DEFM " DEL PARENT      SPACE ACTIONS"
        DB 13,0
tui_action_title: DEFM " CHOOSE AN ACTION:"
        DB 13,0
tui_actions: DEFM " CP/M    BASIC   RESCAN  PARENT  MONITOR"
        DB 0
tui_action_help: DEFM " LEFT/RIGHT SELECT   RETURN CONFIRM"
        DB 13
        DEFM " SPACE CLOSE"
        DB 13,0
tui_ellipsis: DEFM "..."
        DB 0

