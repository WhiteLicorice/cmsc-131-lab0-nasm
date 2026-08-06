# CMSC 131 build.
#
# Usage:
#   make              build the program (default: skel)
#   make run          build, then run it
#   make replay       build, then run it the way check does, with no diff
#   make check        build, run against PROG.input if it exists, and diff
#                     the output against PROG.expected
#   make clean        delete build output
#
# Point it at a different program with PROG:
#   make PROG=lab1 run
#
# On Windows the binary is called mingw32-make. Block 1 has you alias it to
# make, so every command above works under either name.

# Windows sets OS=Windows_NT in the environment and a native make imports it.
# That alone isn't enough. A make built for MSYS2 or Cygwin reports OS as
# empty even on Windows, and such a make is easy to end up with by accident,
# so asking uname as well is what stops this file from quietly picking the
# Linux branch on a Windows machine and failing several steps later.
UNAME := $(shell uname -s 2>/dev/null)

ifeq ($(OS),Windows_NT)
  PLATFORM := windows
else ifneq (,$(findstring MINGW,$(UNAME)))
  PLATFORM := windows
else ifneq (,$(findstring MSYS,$(UNAME)))
  PLATFORM := windows
else ifneq (,$(findstring CYGWIN,$(UNAME)))
  PLATFORM := windows
else
  PLATFORM := $(UNAME)
endif

NASM := nasm
CC   := gcc

ifeq ($(PLATFORM),windows)
  # COFF objects, and the linker needs telling this is a console program
  # rather than a windowed one.
  ASFLAGS := -f win32
  LDFLAGS := -Wl,-subsystem,console
  EXE     := .exe
else
  # ELF objects. -d ELF_TYPE reaches asm_io.inc and asm_io.asm, where it
  # strips the leading underscore that C uses on Windows but not here.
  #
  # -no-pie matters: gcc has defaulted to position-independent executables
  # since Ubuntu 17.10, and the absolute addressing in this course's assembly
  # cannot be relocated that way. Without it the link fails with
  # "relocation R_386_32 ... can not be used when making a PIE object".
  ASFLAGS := -f elf32 -d ELF_TYPE
  LDFLAGS := -no-pie
  EXE     :=
endif

CFLAGS := -m32

PROG ?= skel
BIN  := $(PROG)$(EXE)

$(BIN): $(PROG).obj asm_io.obj driver.o
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

%.obj: %.asm
	$(NASM) $(ASFLAGS) $< -o $@

driver.o: driver.c cdecl.h
	$(CC) $(CFLAGS) -c $< -o $@

run: $(BIN)
	./$(BIN)

# check feeds $(PROG).input on stdin when that file exists. Every program that
# calls read_int needs it: without a file to read from, the program waits on a
# keyboard that isn't there and check hangs instead of failing. skel has no
# .input, so it runs exactly as it always did.
#
# $(wildcard) is make's own test rather than the shell's, which keeps this one
# line working the same way under Git Bash and under a Linux shell.
STDIN := $(if $(wildcard $(PROG).input),< $(PROG).input,)

# replay is the same run check performs, with the comparison left off, so the
# bytes check reads can be read by a person. They should match a run you typed
# at yourself: read_int and read_char print what they read when stdin is not a
# terminal, which puts back the echo a keyboard would have supplied. replay is
# how you look at that rather than take it on faith.
replay: $(BIN)
	@./$(BIN) $(STDIN)

# --strip-trailing-cr matters on Windows: the .exe emits Windows line endings
# (\r\n) while $(PROG).expected is stored with Unix ones (\n). Without it
# every line differs invisibly and check fails on output that is actually
# correct. It is harmless everywhere else.
#
# The two --label flags name the sides of the diff. Without them the second
# side prints as -, which is what diff calls stdin, and a student reading a
# failure has to work out which half came from where.
check: $(BIN)
	@./$(BIN) $(STDIN) | diff -u --strip-trailing-cr --label "$(PROG).expected" --label "what $(PROG) printed" $(PROG).expected - && echo "OK: $(PROG) matches $(PROG).expected"

clean:
	rm -f *.obj *.o *.exe $(PROG)

.PHONY: run replay check clean
