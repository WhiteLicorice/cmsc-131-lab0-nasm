<!--no-pdf-->

# CMSC 131 reference project

A working NASM project you can compare against when your own setup misbehaves,
and the thing every command printed in the bootcamp manuals is checked against
rather than trusted on sight.

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

## Contents

| File | Origin | Purpose |
|---|---|---|
| `asm_io.asm` | Paul Carter's pcasm library, with one addition | I/O routines and the `dump_regs` family of macros |
| `asm_io.inc` | Paul Carter's pcasm library, with one addition | Macro and `extern` declarations every program includes |
| `cdecl.h`, `driver.c` | Paul Carter's pcasm library | C entry point that calls `asm_main` |
| `skel.asm` | Paul Carter's pcasm library | Skeleton program, prints `Hello, world!` |
| `skel.expected` | this repository | Expected stdout for `skel.asm` |
| `Makefile` | this repository | Builds on either platform |
| `.vscode/tasks.json` | this repository | Optional editor wrapper that shells out to the Makefile |
| `.github/workflows/test.yml` | this repository | Proves the Linux build on every push |

Carter's files are his. The two additions to them are marked in place with a
comment saying so, and both are described below.

## How one source tree builds on two platforms

Three things differ between Windows and Linux, and the `Makefile` handles all
three by switching on the platform it detects.

**Object format.** Windows wants COFF objects (`-f win32`), Linux wants ELF
(`-f elf32`).

**Symbol decoration.** Windows C puts a leading underscore on the names it
exports and Linux C doesn't, so the entry point is `_asm_main` on one and
`asm_main` on the other. Rather than make you keep two spellings of every
program, `asm_io.inc` remaps the name when `ELF_TYPE` is defined. You write
`global _asm_main` and `_asm_main:` everywhere, and the assembler emits
whichever one the platform needs. This is the first of the two additions to
Carter's files.

**Linking.** Windows needs `-Wl,-subsystem,console` to say this is a
command-line program. Linux needs `-no-pie`, because gcc has defaulted to
position-independent executables since Ubuntu 17.10 and the absolute
addressing this course teaches cannot be relocated that way. Without it the
link fails with `relocation R_386_32 ... can not be used when making a PIE
object`, which does not obviously mean what it means.

The second addition is a `.note.GNU-stack` section in both `asm_io.inc` and
`asm_io.asm`. Without it, binutils 2.39 and later warn on every link that the
missing section implies an executable stack. `asm_io.asm` needs its own copy
because it doesn't include `asm_io.inc`.

### Why the platform check asks twice

The `Makefile` checks the `OS` environment variable *and* `uname`. That looks
redundant and isn't. A `make` built for MSYS2 or Cygwin reports `OS` as empty
even when it's running on Windows, and it's easy to acquire one of those by
accident, for instance by installing MSYS2's `make` package alongside the
`mingw32-make` this course uses. With only the `OS` check, such a `make` picks
the Linux branch on a Windows machine and the build fails several steps later
with an error that points nowhere near the cause. This was hit during
validation, not predicted.

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

Toolchain observed:

```
NASM version 2.16.03 compiled on Apr 17 2024
gcc.exe (Rev5, Built by MSYS2 project) 15.1.0
gcc -dumpmachine -> i686-w64-mingw32
GNU Make 4.4.1
```

**Cross-format checks, 2026-08-05, run on Windows.** NASM can emit ELF objects
from a Windows host, so the half of the Linux path that is pure assembly was
checked here rather than left to CI. `skel.asm` and `asm_io.asm` both assemble
under `-f elf32 -d ELF_TYPE`. The resulting `skel` object exports `asm_main`
with no underscore while the COFF object exports `_asm_main`, which is the
remap working. `asm_io.asm` refers to `printf`, `scanf`, and `putchar`
undecorated under ELF and to `_printf`, `_scanf`, and `_putchar` under COFF.
Both ELF objects carry `.note.GNU-stack`.

**Linux, by continuous integration.** `.github/workflows/test.yml` installs
`nasm` and `gcc-multilib` on `ubuntu-latest`, runs `make check`, rebuilds from
clean, and fails the run if the linker mentions an executable stack. That
workflow is the proof for the parts of the Linux build this machine cannot
exercise, which is the linking step and running the binary.

## What wasn't tested

- **Linking and running on Linux, locally.** There is no Linux machine in this
  setup. The assembly half was checked here as described above and the rest is
  covered by the workflow, but no one has sat at a Debian box and run this.
- **macOS, at all.** No Apple hardware was involved. See below.
- **A first-time install on a machine that has never had MSYS2.** The toolchain
  here was already present, so this project proves the build works, not that
  the install instructions in Block 1 are complete. Someone has to walk those
  on a clean machine before August 19.
- **The `.vscode/tasks.json` wrapper.** The Makefile it calls is tested. The
  task definition around it isn't. It keeps naming `mingw32-make` explicitly on
  Windows rather than `make`, because editor tasks run a non-interactive shell
  that never reads your `.bashrc` and so never sees the alias.

## macOS

There is no native path, and this isn't a gap in the instructions. macOS
dropped the ability to execute 32-bit binaries in Catalina, and Apple Silicon
can't run i386 code at all, including under Rosetta. Nothing in this project
can be made to run natively on a current Mac.

Block 1 has macOS students run an x86_64 Linux virtual machine and follow the
Linux instructions inside it. The one trap worth repeating here: on Apple
Silicon, the fast virtual machine option is an ARM64 image, which boots quickly
and then cannot run this course's output at all. The image has to be x86_64,
which means emulation and a slow install. The build itself is small enough that
the emulation barely shows.

## The line-ending trap

On Windows `skel.exe` writes `\r\n` line endings while `skel.expected` is
stored with `\n`. A plain `diff` then reports every line as different while
showing you two lines that look identical, which is a maddening thing to
debug. The `check` target passes `--strip-trailing-cr` for that reason. Any
per-activity Makefile that compares output must do the same. It's harmless on
Linux, so it stays on both platforms rather than becoming another thing that
varies.
