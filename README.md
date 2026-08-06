<!--no-pdf-->

# CMSC 131 reference project

A working NASM project you can compare against when your own setup misbehaves.
It's also what every command printed in the bootcamp manuals gets checked
against, rather than trusted on sight.

It builds on Windows and on Linux from the same sources. macOS can't run it
natively, for reasons given below.

## Try it

```bash
make check
```

That assembles `skel.asm`, compiles the C driver, links them, runs the result,
and compares what came out against `skel.expected`. Success looks like:

```
OK: skel matches skel.expected
```

On Windows the binary is called `mingw32-make`. Block 1 has you alias it to
`make`, so the command above works under either name.

Point it at a different program with `PROG`:

```bash
make PROG=lab1 check
```

### Programs that read input

`skel` reads nothing, so `check` just runs it. A program that calls `read_int`
needs somewhere to read from, and a `check` that leaves it reading the keyboard
hangs rather than failing. So when `$(PROG).input` exists, `check` feeds it on
stdin:

```bash
make PROG=convert check      # runs ./convert.exe < convert.input
```

`replay` is how you look at that run. It performs the same run `check`
performs and stops there, comparing nothing:

```bash
make PROG=convert replay
```

What comes back is the contents of `convert.expected`. It reads like a
transcript of you typing at the program:

```
Enter a number: 42
You typed: 42
```

That takes arranging. A file on stdin holds nothing corresponding to the `42`
on the first line, because when you type at a terminal it's the terminal that
prints your keystrokes back, and no part of that echo passes through the
program. Redirect stdin and the echo goes away with the keyboard, leaving the
prompt to share a line with `You typed:` while the number appears nowhere at
all.

So `read_int` and `read_char` echo for themselves when nobody else will. Each
asks `isatty` whether stdin is a terminal and prints what it just read if the
answer is no. That's the third addition to Carter's files. It's what makes
`$(PROG).expected` an ordinary transcript rather than a puzzle, at the price of
a routine named `read_` that prints, which the manuals explain once in Block 2.

Generate a `.expected` with `replay` rather than by hand, then check it against
a run you trust before committing it.

`readback` keeps that honest. It calls `read_char` twice and `read_int` once,
and `make PROG=readback check` compares the result against a fixture holding
the echo. Continuous integration runs it, since `skel` reads nothing and would
notice none of this breaking on Linux.

## Contents

| File | Origin | Purpose |
|---|---|---|
| `asm_io.asm` | Paul Carter's pcasm library, with two additions | I/O routines and the `dump_regs` family of macros |
| `asm_io.inc` | Paul Carter's pcasm library, with one addition | Macro and `extern` declarations every program includes |
| `cdecl.h`, `driver.c` | Paul Carter's pcasm library | C entry point that calls `asm_main` |
| `skel.asm` | Paul Carter's pcasm library | Skeleton program, prints `Hello, world!` |
| `skel.expected` | this repository | Expected stdout for `skel.asm` |
| `readback.asm` | this repository | A program that reads, so CI exercises `read_int` and `read_char` |
| `readback.input`, `readback.expected` | this repository | Its stdin and the transcript it should produce |
| `Makefile` | this repository | Builds on either platform |
| `.vscode/tasks.json` | this repository | Optional editor wrapper that shells out to the Makefile |
| `.github/workflows/test.yml` | this repository | Proves the Linux build on every push |

Carter's files are his. Each addition to them is marked in place with a comment
saying so. There are three: the two platform ones described below, and the echo
described above.

The whole repository is under CC BY-NC-SA 4.0, because Carter's code is and
its ShareAlike condition reaches anything adapted from it. See
[LICENSE](LICENSE).

## How one source tree builds on two platforms

Three things differ between Windows and Linux. The `Makefile` absorbs all three
by switching on the platform it detects.

The object format is one. Windows wants COFF objects, so `-f win32`. Linux
wants ELF, so `-f elf32`.

Symbol decoration is the second. It's the one that would otherwise reach into
every file you write. Windows C puts a leading underscore on the names it
exports. Linux C doesn't, so the entry point is `_asm_main` on one platform and
`asm_main` on the other. Rather than keep two spellings of every program,
`asm_io.inc` remaps the name when `ELF_TYPE` is defined. You write
`global _asm_main` and `_asm_main:` everywhere. The assembler emits
whichever the platform needs. That's one of the additions to Carter's files.

Linking is the third. Windows needs `-Wl,-subsystem,console` to say this is a
command-line program. Linux needs `-no-pie`, because gcc has defaulted to
position-independent executables since Ubuntu 17.10, while the absolute
addressing this course teaches can't be relocated that way. Leave it out and
the link fails with `relocation R_386_32 ... can not be used when making a PIE
object`, which tells you very little unless you already knew this paragraph.

The other platform addition is a `.note.GNU-stack` section in both
`asm_io.inc` and `asm_io.asm`. Without it, binutils 2.39 and later warn on
every link that the missing section implies an executable stack. `asm_io.asm`
needs its own copy because it doesn't include `asm_io.inc`. The `%define` that
respells `_isatty` as `isatty` under ELF sits in that same block, since the
echo calls a C function and the decoration rule above reaches it too.

### Why the platform check asks twice

The `Makefile` checks the `OS` environment variable *and* `uname`. That looks
redundant and isn't. A `make` built for MSYS2 or Cygwin reports `OS` as empty
even while running on Windows. You can acquire one of those by accident,
for instance by installing MSYS2's `make` package alongside the `mingw32-make`
this course uses. With only the `OS` check, such a `make` picks the Linux
branch on a Windows machine. The build then fails several steps later with an
error pointing nowhere near the cause. This was hit during validation, not
predicted.

## Validation record

**Windows, 2026-08-05.** Windows 11 Home, build 26200. Run from Git Bash with
`C:\msys64\mingw32\bin` on `PATH`.

| Check | Result |
|---|---|
| `mingw32-make` from clean | assembles, compiles, links without error |
| `mingw32-make check` from clean | `OK: skel matches skel.expected`, exit 0 |
| `mingw32-make clean` | removes `*.obj`, `*.o`, `*.exe`, and the binary |
| `check` again after `clean` | rebuilds and passes |
| the same four through the `make` alias | all pass, `run` prints `Hello, world!` |
| MSYS2-built `make` picks the Windows branch | passes after the `uname` fix above |

**Windows, 2026-08-06.** Same machine, covering the `check` change that feeds
`$(PROG).input` on stdin.

| Check | Result |
|---|---|
| `make check` with no `.input` present | `OK: skel matches skel.expected`, exit 0, unchanged from before |
| `make PROG=x check` with an `.input` present | reads the file, passes, exit 0 |
| a `read_int` program run with its input redirected | prints no echo of the typed digits, so the prompt and the next output share a line |

That last row was why `$(PROG).expected` files here used to hold output with
no typed digits in them. It surprised the person writing this and it surprised
students, and four manuals ended up carrying a paragraph apologising for it.
The echo added on 2026-08-07 is what closed it, so the row records a behaviour
this repository no longer has.

**Windows, 2026-08-06, gdb.** Block 4 rests entirely on the debugger, and none
of what it claims had been run. All of it was, against `broken.exe`, a COFF
binary carrying no debug information, under GNU gdb 17.2.

| Check | Result |
|---|---|
| `break _asm_main` | `Function "_asm_main" not defined.`, which is the message Block 4 quotes |
| `break asm_main` | resolves, `Breakpoint 1 at 0x401604` |
| `run` | stops with `Thread 1 hit Breakpoint 1 ... in asm_main ()` |
| `x/5i $eip` | prints Intel operand order after `set disassembly-flavor intel` |
| `info registers edx` at entry | `0x30000`, so the garbage Block 4 promises is there |
| `si` | advances one instruction |
| `ni` | advances one instruction, stepping over rather than into |
| running on to the fault | `SIGFPE`, and `x/1i $eip` names `div ebx` |
| registers at the fault | `eax` 1000, `ebx` 7, `edx` dirty, which is the diagnosis Block 4 asks students to reach |
| a `.gdbinit` beside the program | declined, with the `auto-load safe-path` paragraph, and the flavor stays `att` |
| `~/.gdbinit` | loaded, flavor becomes `intel` |

Two notes for whoever revises Block 4. gdb 17.2 names
`~/.config/gdb/gdbinit` in that refusal message rather than `~/.gdbinit`, but
both files are read and the manual's instruction works as written. And the
`edx` value differs per run, so the specific number in the manual's sample
session is an illustration rather than something a student will match.

One way this was reached is worth recording, because the same trap is waiting
for students. The `mingw32` gdb exited 127 with
`error while loading shared libraries: ?: cannot open shared object file`,
naming no file. Its import table asked for `libpython3.14.dll` while the
installed package provided `libpython3.12.dll`, so the debugger was newer than
the Python it links against. `pacman -Syu` to completion fixed it, bringing
`mingw-w64-i686-python` to 3.14.6-2. Block 1 carries this as a pitfall.

Toolchain observed:

```
NASM version 2.16.03 compiled on Apr 17 2024
gcc.exe (Rev5, Built by MSYS2 project) 15.1.0
gcc -dumpmachine -> i686-w64-mingw32
GNU Make 4.4.1
```

**Cross-format checks, 2026-08-05, run on Windows.** NASM can emit ELF objects
from a Windows host, so the half of the Linux path that's pure assembly was
checked here rather than left to CI. `skel.asm` and `asm_io.asm` both assemble
under `-f elf32 -d ELF_TYPE`. The resulting `skel` object exports `asm_main`
with no underscore while the COFF object exports `_asm_main`, which is the
remap working. `asm_io.asm` refers to `printf`, `scanf`, and `putchar`
undecorated under ELF and to `_printf`, `_scanf`, and `_putchar` under COFF.
Both ELF objects carry `.note.GNU-stack`.

**Linux, 2026-08-05, by continuous integration.**
`.github/workflows/test.yml` installs `nasm` and `gcc-multilib` on
`ubuntu-latest`, runs `make check`, rebuilds from clean, and fails the run if
the linker mentions an executable stack. It went green on the first push, with
every step passing and the check reporting `OK: skel matches skel.expected`.
This is the proof for the parts of the Linux build no machine here can
exercise, meaning the link step and running the binary.

The commands it ran, which are the platform switches doing their job:

```
nasm -f elf32 -d ELF_TYPE skel.asm -o skel.obj
nasm -f elf32 -d ELF_TYPE asm_io.asm -o asm_io.obj
gcc -m32 -c driver.c -o driver.o
gcc -m32 skel.obj asm_io.obj driver.o -o skel -no-pie
```

Toolchain observed:

```
NASM version 2.16.01
gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
```

**Linux, 2026-08-06, by hand.** Ubuntu 24.04.3 LTS on x86_64, a machine that
had no `nasm` and no 32-bit libraries on it. Everything below was run as a
student would run it, from the block download archives rather than from a
clone.

Block 1's Linux instructions were executed as printed. `apt install -y nasm`
and `apt install -y gcc-multilib gdb make` both worked on a clean system,
giving NASM 2.16.01 and gcc 13.3.0. Then the project was built by hand the way
Part 7 asks, with the `Makefile` and the four-line `asm_io` addition taken out
of the manual text rather than copied from here, so what was tested is what a
student types.

| Check | Result |
|---|---|
| `make run` after the hand build | `Hello, world!`, and the Linux branch chose `-f elf32 -d ELF_TYPE` and `-no-pie` |
| linker warnings about an executable stack | none, so the `.note.GNU-stack` addition does its job |
| `make check` | `OK: skel matches skel.expected` |
| `make clean` then `check` again | rebuilds and passes |
| blocks 2, 3, 5, 6 and 7, each solution against its fixture | all five report `OK` |
| block 4, unfixed | dies with signal 8, `Floating point exception` |
| block 4, one instruction added | `OK` |
| block 8's exit check against its fixture | `OK` |
| all five starter files | assemble untouched |
| `b1_doctor.sh` | reports `linux` and passes all eight checks |
| the validation scripts | run under `python3` |

The same `.expected` files were used on both platforms, unchanged. Nothing in
the fixtures is per-platform, which is the point of `--strip-trailing-cr` in
the `check` recipe.

**gdb on Linux, same day.** Block 4's session was walked against the ELF
binary as well as the COFF one. `break _asm_main` fails and `break asm_main`
resolves, exactly as on Windows, though for a different reason: here the
`asm_io.inc` remap has already stripped the underscore before the assembler
sees it. `edx` again holds garbage at entry, `0xffffccc0` this time, and the
fault lands on `div ebx` with a divisor of 7.

One Linux-only wrinkle worth knowing. Ubuntu's gdb asks whether to enable
`debuginfod` the first time it starts. It is harmless and answering `n` is
right for this course. Block 4 says so.

**Windows from nothing, 2026-08-06.** The gap this file has carried since it
was written. MSYS2 and devkitPro were uninstalled and their folders deleted,
NASM was removed, and Block 1 was then walked from Part 3 through Part 8 as
printed rather than from memory. Strawberry Perl stayed on the machine
deliberately, because `C:\Strawberry\c\bin` supplies an `x86_64-w64-mingw32`
gcc from the machine `Path`, which is the hazard Part 4 warns about sitting on
the machine by accident.

| Check | Result |
|---|---|
| `winget install --id MSYS2.MSYS2 --exact` | installed from a PowerShell that was not elevated, with no approval prompt |
| `pacman -Syu` | two runs needed, the first stopping after `msys2-runtime` with `warning: terminate other MSYS2 programs before proceeding` |
| `pacman -S --needed mingw-w64-i686-toolchain` | 42 packages, nothing asked beyond the group default |
| a mirror answering 404 partway through a download | pacman moved to another mirror and finished, on both runs |
| the NASM installer, run at its default location | lands in `C:\Users\<you>\AppData\Local\bin\NASM`, as Part 3 says |
| Part 4's verify | `i686-w64-mingw32`, `GNU Make 4.4.1`, `GNU gdb (GDB) 17.2` |
| Part 5's `make` alias, starting from no `~/.bashrc` at all | the file is created and a new interactive shell answers `make --version` |
| Part 7 built by hand, `Makefile` and the `asm_io` addition taken from the manual text | `Hello, world!` |
| Part 8 | `OK: skel matches skel.expected`, then `clean`, then `check` again |
| blocks 2, 3, 5, 6 and 7, each carried-forward solution against its fixture | all five `OK` |
| block 4 unfixed, stdin redirected | exits `0xC0000095` having printed nothing at all |
| block 4 fixed | `OK: broken matches broken.expected` |
| block 4's whole gdb session under gdb 17.2 | unchanged from the record above, `edx` dirty at `0x30000`, fault on `div ebx` |
| block 8 against `exitcheck.expected` | `OK` |
| all five starter files | assemble untouched |
| both checkers | every check passes |
| the validation scripts | run under `python` |

Block 8's program was written to run that check and then thrown away. Nothing
resembling a solution to the exit check belongs in `b8/dist`, because the
generator copies that folder into the student bundle.

Three things the walk found, all of them now fixed in Block 1.

**The MSYS2 install needs no administrator.** The manual said Windows would
ask for approval. It doesn't. `icacls C:\` shows
`NT AUTHORITY\Authenticated Users:(AD)`, the right to add a subdirectory, so
any signed-in user may create `C:\msys64`, which is all the installer does
there. The measurements, all taken on this machine:

- winget's own log launches the installer directly, with no elevation step
- the session running it reported `IsInRole(Administrator)` as false
- `C:\msys64` came out owned by an ordinary user account

A managed machine can have that right removed,
and there the install does stop, so Block 1 now describes that as the
exception rather than the rule.

**Part 4 step 4 could not fix the ordering it promised to fix.** Windows
composes a process `PATH` as the machine list followed by the user list. Step
4 sends the student to *User variables*, which puts `C:\msys64\mingw32\bin`
after every system entry, so a 64-bit gcc already in the system list still
wins. Measured here with the stale entries stripped, `gcc` resolved to
`C:\Strawberry\c\bin` and `gcc -dumpmachine` answered `x86_64-w64-mingw32`,
with MSYS2 added under *User variables*, which is where the manual said to add
it. There is no user-level fix. Block 1 now explains the two lists and says that moving the
folder to the top of the system list is the one step in the block needing an
administrator.

**The pitfall named the wrong error.** Block 1 quoted
`i386 architecture of input file ... is incompatible`. That message does
appear, but it belongs to a dropped `-m32` on the link line. With `-m32`
present, which is what the printed `Makefile` does, a 64-bit MinGW assembles
and compiles without complaint and then fails at the link with a wall of
`skipping incompatible ... when searching for -lmingw32` lines ending in
`cannot find -lmingw32: No such file or directory`. Nothing in that message
mentions widths. Both now appear in Common Pitfalls as separate entries.

Two smaller corrections went in alongside. There is no directory named
`stable` on nasm.us, so Part 3 now sends the student to **Download** and the
highest plain version number, currently 3.02. And `b1_doctor.ps1` had two
false passes: `Find-Tool` returned `$c.Source` for any command, which is an
empty string for a PowerShell alias rather than a null, so the built-in `diff`
alias for `Compare-Object` was reported as a working `diff`. The bash check
was wrong in the other direction. Git for Windows puts neither
`bash.exe` nor `diff.exe` on `PATH`, so asking `PATH` about them proved
nothing either way, and on a machine with WSL the name `bash` resolves to
`C:\Windows\System32\bash.exe`, which starts Linux. The checker now derives
the Git root from `git.exe` and looks for `bin\bash.exe` and
`usr\bin\diff.exe` underneath it.

**The editor tasks, 2026-08-06.** `.vscode/tasks.json` had never been run,
only its Makefile had. Both of its tasks were replayed on Windows with the
variables VS Code substitutes filled in by hand. The Windows branch was
broken. It named its shell `bash.exe`, and on a machine with WSL that name
belongs to `C:\Windows\System32\bash.exe`, so the task started Linux and
answered `/bin/bash: line 1: mingw32-make: command not found`. It now names
Git Bash by full path.

Dropping the shell block instead looks like the simpler fix. It isn't. Run
`mingw32-make` from PowerShell and
the compile and link succeed, because those are program invocations, while
`clean` dies with `CreateProcess(NULL, rm -f *.obj ...)` and `check` dies with
`'.' is not recognized as an internal or external command`. Both recipes need
a Unix shell. With Git Bash named in full, `Build & Run` prints
`Hello, world!` and `Check` prints `OK: skel matches skel.expected`, both
exiting 0.

The task keeps naming `mingw32-make` explicitly on Windows rather than `make`,
because editor tasks run a non-interactive shell that never reads your
`.bashrc` and so never sees the alias.

**The replay target and the diff labels, 2026-08-06.** Both are new here, so
both were run before anything was written about them. `convert` was built from
Block 2's carried-forward solution against Block 2's fixtures.

| Check | Result |
|---|---|
| `make check` on `skel`, which has no `.input` | `OK: skel matches skel.expected`, exit 0, unchanged |
| `make PROG=convert replay` on a built binary | three lines, byte-identical to `convert.expected` |
| `make PROG=convert check` | `OK`, exit 0 |
| the same check against a `convert.expected` broken on purpose | diff headed `--- convert.expected` and `+++ what convert printed`, exit 2 |
| `make PROG=convert clean` then `check` again | rebuilds and passes |

The labels are the reason for the fourth row. `diff` names stdin `-`, so a
failing check used to head its second column with a single hyphen and leave
the reader to work out which half of the output was theirs.

One thing `replay` does not hide. The first run after a `clean` prints the
four build commands above the program's output, because `make` echoes its
recipes. Run it a second time and only the program's output is left. Worth
knowing before you compare what you see against a fixture.

**The echo in read_int and read_char, 2026-08-07.** The addition itself, and
every fixture in the course regenerated by running a program against it. Each
`.expected` was produced by running the block's carried-forward solution with
its `.input` redirected, never by editing the file, and then compared by that
block's own `check`.

| Check | Result |
|---|---|
| `__isatty` resolves at link | yes on COFF. `nm asm_io.obj` shows `U __isatty`, and the C function is `_isatty` |
| `isatty` resolves under ELF | `nasm -f elf32 -d ELF_TYPE` emits `U isatty`, undecorated, so the `%define` in the ELF block does its job |
| `make check` on `skel` | `OK: skel matches skel.expected`, exit 0, unchanged |
| blocks 2, 3, 5, 6 and 7, each solution against its regenerated fixture | all five `OK` |
| block 4 fixed, against its regenerated fixture | `OK` |
| block 4 unfixed, stdin redirected | exits `0xC0000095` having printed nothing, unchanged |
| block 8's throwaway program against `exitcheck.expected` | `OK`, and all seven cases in `b8_validation.py` pass |
| `convert` run directly as `./convert.exe < convert.input` | same transcript, so this is not an artefact of `make` |
| `make PROG=convert replay` | byte-identical to `convert.expected` |
| `make PROG=readback check` | `OK`, exercising `read_char` twice and `read_int` once |
| all five starter files | assemble untouched |
| the `b1` bundle's `asm_io.asm` after `make-bootcamp-bundles.sh` | byte-identical to what the previous bundle shipped, so Carter's original is still reconstructed exactly |

The interactive half needed arranging, because Git Bash here has neither
`script` nor `expect`. A program was given a console as stdin instead, with
its keystrokes written into that console's input buffer by `WriteConsoleInput`
and its stdout redirected to a file. `_isatty(0)` answered 64 under those
conditions and 0 under both a file and a pipe. `convert` read the typed `69`,
computed 156, 341 and 68 from it, and printed no echo of its own, which is the
branch the gate exists to take. Two earlier attempts failed in ways somebody
else would hit too. `winpty` refuses with `stdin is not a tty` when its own
stdin is a pipe, and driving a console window with `SendKeys` types into
whatever holds focus, which on this machine was an editor.

Block 4's gdb session was walked again on the same footing, with a console for
stdin, since that's what a student has. It is unchanged: `break asm_main`
resolves, the run stops there, `continue` reaches `SIGFPE` with `eax` at 1000,
`ebx` at 7 and `edx` dirty at `0x30000`. No echo appears, because the gate sees
a terminal.

The regeneration turned up one disagreement. Block 8's `exitcheck.expected`
did not match the sample run printed in the manual. The manual shows a blank
line between the last reading and the `Packed:` line, while the old fixture
had none, because with no echo the program's own newline closed the
run-together prompt line instead of opening a blank one. They agree now. Every
other manual's sample run matched its regenerated fixture already.

Toolchain observed:

```
NASM version 3.02 compiled on Jun 28 2026
gcc.exe (Rev6, Built by MSYS2 project) 16.1.0
gcc -dumpmachine -> i686-w64-mingw32
GNU Make 4.4.1
GNU gdb (GDB) 17.2
GNU ld (GNU Binutils) 2.47.20260726
git version 2.55.0.windows.2
```

## What wasn't tested

- Debian specifically. Ubuntu 24.04 has now been walked by hand, and the
  `apt` lines in Block 1 were executed rather than read, but Debian's own
  package listings were only read. The package names are the same on both.
- macOS, at all. No Apple hardware was involved. See below.
## macOS

There's no native path. That isn't a gap in the instructions. macOS dropped
the ability to execute 32-bit binaries in Catalina, and Apple Silicon can't run
i386 code at all, including under Rosetta. Nothing in this project can be made
to run natively on a current Mac.

Block 1 has macOS students run an x86_64 Linux virtual machine and follow the
Linux instructions inside it. On Apple Silicon, the fast virtual machine option
is an ARM64 image, which boots quickly and then can't run this course's output
at all. The image has to be x86_64, which means emulation and a slow install.
The build itself is small enough that the emulation barely shows.

## License

CC BY-NC-SA 4.0, inherited from Paul Carter's
[pcasm](https://github.com/pacman128/pcasm) rather than chosen. His code
carries a ShareAlike condition, so the two files adapted from it have to stay
under the same terms, and the rest of the repository follows so that nothing
here is ambiguous about which terms apply to what.

Using this as course material is noncommercial use, so the restriction costs
students nothing. [LICENSE](LICENSE) records who wrote what and what
was changed in Carter's files.

## The line-ending trap

On Windows `skel.exe` writes `\r\n` line endings while `skel.expected` is
stored with `\n`. A plain `diff` then reports every line as different while
showing you two lines that look identical, which is a maddening thing to
debug. The `check` target passes `--strip-trailing-cr` for that reason. Any
per-activity Makefile that compares output must do the same. It's harmless on
Linux, so it stays on both platforms rather than becoming another thing that
varies.
