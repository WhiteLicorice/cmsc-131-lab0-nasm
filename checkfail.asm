;
; checkfail.asm - the regression fixture for the check target.
;
; This program prints exactly what skel.expected holds. Then it returns a
; nonzero status from main.
;
; `make PROG=checkfail check` must fail. The failure message must name the
; exit status. A check that compares output alone accepts this program,
; because the output matches. That was the defect this fixture guards
; against.
;
; The continuous integration workflow runs this fixture, so the hole cannot
; open again without a red build.
;

%include "asm_io.inc"

segment .data
hello_msg db "Hello, world!", 0

segment .bss

segment .text
        global  _asm_main
_asm_main:
        enter   0,0
        pusha

        mov     eax, hello_msg
        call    print_string
        call    print_nl
        call    print_nl

        popa
        mov     eax, 1                  ; a nonzero status, on purpose
        leave
        ret
