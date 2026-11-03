#!/usr/bin/env python3
"""Fail if any native library inside an AAB/APK is not 16 KB page aligned.

Google Play requires 16 KB page-size support for apps with native code.
Checks every lib/**/*.so: each ELF PT_LOAD segment must have p_align >= 0x4000.
Usage: python3 tools/check_16kb.py build/android/Chimora.aab
"""
import struct
import sys
import zipfile

PAGE = 0x4000
PT_LOAD = 1


def load_aligns(data: bytes) -> list[int]:
    if data[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    is64 = data[4] == 2
    endian = "<" if data[5] == 1 else ">"
    if is64:
        phoff, = struct.unpack_from(endian + "Q", data, 0x20)
        phentsize, phnum = struct.unpack_from(endian + "HH", data, 0x36)
    else:
        phoff, = struct.unpack_from(endian + "I", data, 0x1C)
        phentsize, phnum = struct.unpack_from(endian + "HH", data, 0x2A)
    aligns = []
    for i in range(phnum):
        off = phoff + i * phentsize
        p_type, = struct.unpack_from(endian + "I", data, off)
        if p_type != PT_LOAD:
            continue
        if is64:
            p_align, = struct.unpack_from(endian + "Q", data, off + 0x30)
        else:
            p_align, = struct.unpack_from(endian + "I", data, off + 0x1C)
        aligns.append(p_align)
    return aligns


def main(path: str) -> int:
    bad = 0
    checked = 0
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if not name.endswith(".so"):
                continue
            checked += 1
            aligns = load_aligns(z.read(name))
            ok = all(a >= PAGE for a in aligns)
            print(f"{'OK  ' if ok else 'FAIL'} {name} p_align={[hex(a) for a in aligns]}")
            bad += 0 if ok else 1
    if checked == 0:
        print("No native libraries found", file=sys.stderr)
        return 1
    if bad:
        print(f"{bad} librar{'y is' if bad == 1 else 'ies are'} not 16 KB aligned", file=sys.stderr)
        return 1
    print(f"All {checked} native libraries are 16 KB aligned")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
