#!/usr/bin/env python3
"""Plan item 3956: banned names must not hide in file metadata either.

Reads the text fields of PNG files (tEXt, zTXt, iTXt chunks), the comment header of OGG files
and the INFO list of WAV files under art/, audio/ and store/, and fails if one matches the
pattern from tools/ip_check.sh (passed in IP_PATTERN, base64-free at this point).
Usage: IP_PATTERN='...' python3 tools/ip_meta_check.py"""
import os, re, struct, subprocess, sys, zlib

def png_texts(data):
    pos, out = 8, []
    while pos + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"tEXt":
            out.append(body.replace(b"\0", b" "))
        elif kind == b"zTXt":
            key, _, rest = body.partition(b"\0")
            try:
                out.append(key + b" " + zlib.decompress(rest[1:]))
            except zlib.error:
                out.append(key)
        elif kind == b"iTXt":
            parts = body.split(b"\0", 5)
            text = parts[-1] if len(parts) == 6 else body
            if len(parts) == 6 and parts[1][:1] == b"\1":
                try:
                    text = zlib.decompress(text)
                except zlib.error:
                    pass
            out.append(b" ".join(parts[:1] + parts[3:5] + [text]))
        if kind == b"IEND":
            break
        pos += 12 + length
    return out

def ogg_texts(data):
    """Vendor string and user comments of the Vorbis or Opus comment header."""
    head = data[:65536]
    for magic in (b"\x03vorbis", b"OpusTags"):
        i = head.find(magic)
        if i < 0:
            continue
        pos, out = i + len(magic), []
        try:
            n = struct.unpack("<I", head[pos:pos + 4])[0]
            out.append(head[pos + 4:pos + 4 + n])
            pos += 4 + n
            count = struct.unpack("<I", head[pos:pos + 4])[0]
            pos += 4
            for _ in range(min(count, 1000)):
                n = struct.unpack("<I", head[pos:pos + 4])[0]
                out.append(head[pos + 4:pos + 4 + n])
                pos += 4 + n
        except struct.error:
            pass
        return out
    return []

def wav_texts(data):
    i = data.find(b"LIST")
    out = []
    while i >= 0:
        size = struct.unpack("<I", data[i + 4:i + 8])[0] if i + 8 <= len(data) else 0
        out.append(data[i + 8:i + 8 + size])
        i = data.find(b"LIST", i + 8 + size)
    return out

READERS = {".png": png_texts, ".ogg": ogg_texts, ".wav": wav_texts}

def main():
    pattern = os.environ.get("IP_PATTERN", "")
    if not pattern:
        sys.exit("IP_PATTERN is not set (run through tools/ip_check.sh)")
    rx = re.compile(pattern.replace("(?i)", ""), re.I)
    files = subprocess.run(["git", "ls-files", "--", "art", "audio", "store"], capture_output=True, text=True,
                           check=True).stdout.split()
    bad = 0
    for f in files:
        reader = READERS.get(os.path.splitext(f)[1].lower())
        if reader is None or not os.path.exists(f):
            continue
        with open(f, "rb") as fh:
            data = fh.read()
        for raw in reader(data):
            text = raw.decode("utf-8", "replace")
            if rx.search(text):
                print("::error::%s: banned name in file metadata" % f)
                bad += 1
                break
    if bad:
        sys.exit(1)
    print("metadata of %d files OK" % len(files))

if __name__ == "__main__":
    main()
