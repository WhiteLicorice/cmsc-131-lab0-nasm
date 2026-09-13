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

# PROG names a program stem, and a stem is one word made of letters, digits,
# underscores, and hyphens. Anything else stops make here, before any recipe
# runs. The check exists for clean: an older recipe removed $(PROG) itself,
# so PROG=pack.asm deleted the source file. The recipe now removes only the
# files this Makefile generates, and this check makes sure PROG can never
# spell a source file, a path, or a shell fragment.
#
# The test uses make's own substitution, not the shell. A value with shell
# characters in it therefore never reaches a shell.
ifneq ($(words $(PROG)),1)
  $(error PROG must be one word with no spaces. Got: "$(PROG)")
endif
ifneq ($(suffix $(PROG)),)
  $(error PROG must be a bare stem with no extension. Use PROG=pack, not PROG=$(PROG))
endif
ifneq ($(findstring /,$(PROG))$(findstring \,$(PROG)),)
  $(error PROG must be a name in this directory, not a path. Got: $(PROG))
endif
ifeq ($(PROG),Makefile)
  $(error PROG must not be Makefile)
endif
STEM_CHARS := a b c d e f g h i j k l m n o p q r s t u v w x y z               A B C D E F G H I J K L M N O P Q R S T U V W X Y Z               0 1 2 3 4 5 6 7 8 9 _ -
PROG_LEFTOVER := $(PROG)
$(foreach c,$(STEM_CHARS),$(eval PROG_LEFTOVER := $$(subst $(c),,$$(PROG_LEFTOVER))))
ifneq ($(PROG_LEFTOVER),)
  $(error PROG may hold only letters, digits, underscores, and hyphens. Got: $(PROG))
endif

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

# The captured output lives here for the length of one check, then goes away.
OUTPUT := $(PROG).check.out

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
#
# The output is captured to a file first, and the program's status is read
# before the comparison runs. An older recipe piped the program straight into
# diff, and a pipeline reports the status of its last command alone. A program
# that printed the right bytes and then died therefore passed the check. The
# capture closes that hole: a nonzero status fails the check on its own, and
# the message says so.
check: $(BIN)
	@./$(BIN) $(STDIN) > $(OUTPUT); \
	status=$$?; \
	if [ $$status -ne 0 ]; then \
	    echo "FAIL: $(PROG) exited with status $$status."; \
	    echo "      The output was:"; \
	    sed -n '1,20p' $(OUTPUT) | sed 's/^/      /'; \
	    rm -f $(OUTPUT); \
	    exit 1; \
	fi; \
	if diff -u --strip-trailing-cr --label "$(PROG).expected" --label "what $(PROG) printed" $(PROG).expected $(OUTPUT); then \
	    echo "OK: $(PROG) matches $(PROG).expected"; \
	    rm -f $(OUTPUT); \
	else \
	    rm -f $(OUTPUT); \
	    exit 2; \
	fi

# clean removes what this Makefile generates and nothing else: the objects,
# the executables, and the capture file check leaves behind on a failure.
# $(BIN) is $(PROG) plus the platform's executable suffix, and PROG has
# been checked above, so this line can never name a source file.
clean:
	rm -f *.obj *.o *.exe $(BIN) $(OUTPUT)

.PHONY: run replay check clean
