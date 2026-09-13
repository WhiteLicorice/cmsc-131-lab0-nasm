;
; readfail.asm - what read_int returns when there is no number to read.
;
; The program asks for two numbers and prints both. readfail.input holds one
; word that is not a number. Both reads fail. Each failed read must return
; 0, print no echo, and leave the program running. The fixture below holds
; that output.
;
; Before this fixture, a failed read returned whatever the stack slot held,
; and echoed it. The number differed from run to run and from platform to
; platform.
;
;       make PROG=readfail check
;

%include "asm_io.inc"

segment .data
first_prompt    db  "First: ", 0
second_prompt   db  "Second: ", 0
got_label       db  "got ", 0

segment .text
        global  _asm_main
_asm_main:
        enter   0,0
        pusha

        mov     eax, first_prompt
        call    print_string
        call    read_int
        mov     esi, eax                ; keep the first value

        mov     eax, second_prompt
        call    print_string
        call    read_int
        mov     edi, eax                ; keep the second value

        mov     eax, got_label
        call    print_string
        mov     eax, esi
        call    print_int
        mov     eax, ' '
        call    print_char
        mov     eax, edi
        call    print_int
        call    print_nl

        popa
        mov     eax, 0
        leave
        ret
