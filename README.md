# lukOS + acts

**acts** is a tiny programming language I made for you. **lukOS** is a tiny
operating system written in it. It boots, says *Hello, World!*, and gives you a
prompt with `help`, `clear`, `reboot`, `hello`, and three games: `snake`, `tetris` and `flappy`.

```
 your .acts files --actsc.py--> kernel.asm --nasm--> kernel.bin ─┐
                                                                 ├─> lukOS.img
                                       boot.asm --nasm--> boot.bin ─┘
```

## 1. Build it

You need two things: **Python 3** and **NASM**.

| System  | Install NASM                                   |
|---------|------------------------------------------------|
| Linux   | `sudo apt install nasm`                        |
| macOS   | `brew install nasm`                            |
| Windows | download from nasm.us and add it to your PATH  |

Then, in this folder:

```
python3 build.py        # or just:  make
```

Output: **`lukOS.img`** (a 1.44 MB floppy image, like your other .img files).

## 2. Run it in VirtualBox

1. New VM -> Type *Other*, Version *Other/Unknown*. No hard disk needed.
2. Settings -> Storage -> **Floppy Controller** -> add a floppy drive -> choose `lukOS.img`.
3. Settings -> System -> Boot Order: make sure **Floppy** is ticked (and first).
4. Start. (Legacy BIOS mode, which is VirtualBox's default.)

Just rebuild and restart the VM after every change. If you have QEMU, `make run` does it in one step.

## 3. Files

| File          | What it is |
|---------------|------------|
| `lukos.acts`  | the OS: command prompt, `help`, `clear`, `reboot`, `hello` |
| `lib.acts`    | small helpers shared by the games (`printn`, `text`, `numat`, `blank_screen`) |
| `snake.acts`  | Snake: arrows/WASD, ESC quits |
| `tetris.acts` | Tetris: arrows/WASD, SPACE hard drop, P pause, ESC quits |
| `flappy.acts` | Flappy Bird: SPACE/UP/W flaps, ESC quits |
| `actsc.py`    | the **acts compiler** (lexer -> parser -> code generator -> runtime library, heavily commented) |
| `boot.asm`    | the 512-byte boot sector. Must be machine code: the BIOS runs it before anything else exists |
| `build.py`    | runs the whole pipeline and writes `lukOS.img` |

## 4. The acts language

```
// comment               /* block comment */
use "other.acts";        // include a file
const W = 80;            // compile-time constant
var score = 0;           // global variable
var buf[32];             // global array of 32 words
fn add(a, b) { return a + b; }

fn main() {              // every program starts at main()
    var x = add(1, 2);   // local variable
    x += 1;  x++;
    buf[3] = x;
    if x > 3 { print("big\n"); } else if x == 3 { print("three\n"); } else { print("small\n"); }
    while true { if keypending() { break; } }
}
```

* Everything is a **16-bit integer**. A string like `"hi"` or an array name is just the address of its first byte.
* Operators, low to high precedence: `||` `&&` `== != < > <= >=` `|` `^` `&` `<< >>` `+ -` `* / %` unary `- ! ~`.
  (`&` binds tighter than `==`, so `v & 255 == 4` does what it looks like.) Comparisons are signed, `>>` is logical.
* String escapes: `\n \r \t \b \0 \e \\ \" \'`. Char literals: `'A'`.
* Numbers: `42`, `0x2A`.

### Builtin functions (the "standard library", in `actsc.py`)

| Function | Does |
|----------|------|
| `print(str)` `putc(ch)` | write text (`\n` moves to the next line) |
| `getkey()` | wait for a key; returns `(scancode << 8) \| ascii` |
| `keypending()` | 1 if a key is waiting, else 0 |
| `clear()` `cursor(row, col)` `hidecursor()` `showcursor()` | screen control |
| `vpeek(cell)` `vpoke(cell, word)` | read/write a screen cell 0..1999 as `(colour << 8) \| char` |
| `peekb/pokeb(addr[, v])` `peekw/pokew(addr[, v])` | read/write raw memory (byte / word) |
| `streq(a, b)` | 1 if two strings are equal |
| `rand(n)` | random number `0 .. n-1` |
| `ticks()` `wait(n)` | BIOS timer (18.2 ticks per second) |
| `reboot()` `halt()` | restart / stop the machine |

## 5. How it works (so you can change it)

**Boot.** The BIOS loads sector 0 (`boot.asm`) to memory address `0x7C00` and jumps there. The boot sector reads the next few
sectors (the kernel) to `0x7E00` using BIOS `int 13h`, and jumps to it. `build.py` works out how many sectors the kernel
needs and passes it to `boot.asm`.

**Kernel.** `actsc.py` writes the kernel as NASM assembly: a tiny startup stub (sets up segments and stack, then
`call f_main`), then one assembly function per acts function, then the runtime library (`print`, `getkey`, ... are written
in assembly and use BIOS interrupts: `int 10h` screen, `int 16h` keyboard), then data.
Look at `build/kernel.asm` after building to see exactly what your acts code became.

**Code generator.** Deliberately simple: every expression leaves its answer in `AX`. `a + b` becomes "compute a, push it,
compute b, pop a, add". Arguments are pushed on the stack right-to-left; locals live at `[bp-2]`, `[bp-4]`...; parameters
at `[bp+4]`, `[bp+6]`... It generates slow, bulky code, but it is easy to read.

### Ideas for what to build next
* **New builtin:** add an entry to `RUNTIME` plus an assembly routine in `RUNTIME_ASM`. E.g. `time()` using BIOS `int 1Ah`.
* **New command:** add an `else if streq(cmd, "...")` branch to `run()` in `lukos.acts`.
* **New game:** copy `flappy.acts`, give every global a unique prefix (all games share one namespace), `use` it from `lukos.acts`, add a command.
* **Language features:** `for` loops, a `byte` type, local arrays, `else`-less `match`. All in `Parser` and `CodeGen`.
* **Rename the language** (e.g. to "luke"): change the file extension and the name in the docs; the compiler does not care.
* **Later:** write a tiny assembler in Python so you no longer need NASM, or switch to 32-bit protected mode.
