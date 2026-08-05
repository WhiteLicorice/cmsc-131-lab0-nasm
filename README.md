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

Carter's files are his. Each addition to them is marked in place with a comment
saying so. Both are described below.

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
whichever the platform needs. That's the first addition to Carter's files.

Linking is the third. Windows needs `-Wl,-subsystem,console` to say this is a
command-line program. Linux needs `-no-pie`, because gcc has defaulted to
position-independent executables since Ubuntu 17.10, while the absolute
addressing this course teaches can't be relocated that way. Leave it out and
the link fails with `relocation R_386_32 ... can not be used when making a PIE
object`, which tells you very little unless you already knew this paragraph.

The second addition is a `.note.GNU-stack` section in both `asm_io.inc` and
`asm_io.asm`. Without it, binutils 2.39 and later warn on every link that the
missing section implies an executable stack. `asm_io.asm` needs its own copy
because it doesn't include `asm_io.inc`.

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

## What wasn't tested

- Linux on anything but a GitHub runner. The workflow proves Ubuntu 24.04 on
  `ubuntu-latest`. Nobody has sat at a Debian box and run this by hand. The
  manual's `apt` install line was read against Debian's package listings rather
  than executed on a fresh machine.
- macOS, at all. No Apple hardware was involved. See below.
- A first-time install on a machine that has never had MSYS2. The toolchain
  here was already present, so this project proves the build works, not that
  the install instructions in Block 1 are complete. Someone has to walk those
  on a clean machine before August 19.
- The `.vscode/tasks.json` wrapper. The Makefile it calls is tested. The task
  definition around it isn't. It keeps naming `mingw32-make` explicitly on
  Windows rather than `make`, because editor tasks run a non-interactive shell
  that never reads your `.bashrc` and so never sees the alias.

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
