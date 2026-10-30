#!/usr/bin/env python3
"""
build.py - build lukOS.img from the acts sources.

    python3 build.py            # builds lukOS.img
    python3 build.py -o x.img   # choose another output name

Steps:
  1. actsc.py   lukos.acts  -> build/kernel.asm   (acts -> assembly)
  2. nasm       kernel.asm  -> build/kernel.bin   (assembly -> machine code)
  3. nasm       boot.asm    -> build/boot.bin     (needs the kernel size)
  4. boot.bin + kernel.bin padded with zeros to 1.44 MB  ->  lukOS.img
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
FLOPPY = 1474560            # 1.44 MB floppy image, what VirtualBox expects


def run(*cmd):
    print("  $", " ".join(os.path.relpath(c, HERE) if os.path.isabs(c) else c for c in cmd))
    r = subprocess.run(cmd, cwd=HERE)
    if r.returncode != 0:
        sys.exit("build failed")


def main():
    out = os.path.join(HERE, "lukOS.img")
    if "-o" in sys.argv:
        out = os.path.abspath(sys.argv[sys.argv.index("-o") + 1])
    os.makedirs(BUILD, exist_ok=True)
    kasm = os.path.join(BUILD, "kernel.asm")
    kbin = os.path.join(BUILD, "kernel.bin")
    bbin = os.path.join(BUILD, "boot.bin")

    print("1/4 compile acts -> assembly")
    run(sys.executable, os.path.join(HERE, "actsc.py"),
        os.path.join(HERE, "lukos.acts"), "-o", kasm)

    print("2/4 assemble kernel")
    run("nasm", "-f", "bin", kasm, "-o", kbin)
    ksize = os.path.getsize(kbin)
    sectors = (ksize + 511) // 512
    print("    kernel: %d bytes = %d sectors" % (ksize, sectors))
    if sectors > 200:       # kernel lives at 0x7E00 and must stay below 0x9FC00
        sys.exit("kernel too big for the simple loader (max 200 sectors)")

    print("3/4 assemble boot sector")
    run("nasm", "-f", "bin", os.path.join(HERE, "boot.asm"),
        "-DKSECTORS=%d" % sectors, "-o", bbin)
    if os.path.getsize(bbin) != 512:
        sys.exit("boot sector is not 512 bytes")

    print("4/4 write disk image")
    with open(bbin, "rb") as f:
        img = f.read()
    with open(kbin, "rb") as f:
        img += f.read()
    img += b"\0" * (sectors * 512 - ksize)        # round kernel up to a sector
    img += b"\0" * (FLOPPY - len(img))
    with open(out, "wb") as f:
        f.write(img)
    print("done: %s (%d bytes)" % (out, len(img)))


if __name__ == "__main__":
    main()
