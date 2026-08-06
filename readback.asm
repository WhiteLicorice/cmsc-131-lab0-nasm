;
; file: readback.asm
; A program that reads, so that continuous integration has something to run
; which exercises read_char and read_int. skel reads nothing, and without this
; the echo those two routines perform on a redirected stdin could break on
; Linux without any build here noticing.
;

%include "asm_io.inc"

segment .data
letter_prompt   db  "Type a letter: ", 0
number_prompt   db  "Type a number: ", 0
letter_label    db  "letter: ", 0
number_label    db  "number: ", 0

segment .bss

segment .text
        global  _asm_main
_asm_main:
        enter   0,0
        pusha

        mov     eax, letter_prompt
        call    print_string
        call    read_char
        mov     ebx, eax                ; keep the letter
        call    read_char               ; and swallow the Enter after it

        mov     eax, number_prompt
        call    print_string
        call    read_int
        mov     esi, eax

        mov     eax, letter_label
        call    print_string
        mov     eax, ebx
        call    print_char
        call    print_nl

        mov     eax, number_label
        call    print_string
        mov     eax, esi
        call    print_int
        call    print_nl

        popa
        mov     eax, 0
        leave
        ret
