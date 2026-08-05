;
; Added for CMSC 131. Not part of Paul Carter's original file.
;
; Windows C decorates the names it exports with a leading underscore and
; Linux C does not, so the same source would otherwise need two spellings of
; the entry point. Remapping it here means you write global _asm_main and
; _asm_main: on both platforms, and this file works out which one the
; assembler should emit. -d ELF_TYPE, which the Makefile passes on Linux, is
; what selects it.
;
; The .note.GNU-stack section tells the linker this object does not want an
; executable stack. Without it, binutils 2.39 and later warn on every link.
;
%ifdef ELF_TYPE
  %define _asm_main asm_main
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

	extern  read_int, print_int, print_string
	extern	read_char, print_char, print_nl
	extern  sub_dump_regs, sub_dump_mem, sub_dump_math, sub_dump_stack

%macro 	dump_regs 1
	push	  dword %1
	call	  sub_dump_regs
%endmacro


;
; usage: dump_mem label, start-address, # paragraphs
%macro  dump_mem 3
	push	 dword %1
	push	 dword %2
	push	 dword %3
	call	 sub_dump_mem
%endmacro

%macro	dump_math 1
	push	 dword %1
	call	 sub_dump_math
%endmacro

%macro  dump_stack 3
	push	 dword %3
        push     dword %2
	push	 dword %1
        call     sub_dump_stack
%endmacro