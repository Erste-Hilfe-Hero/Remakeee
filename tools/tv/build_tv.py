#!/usr/bin/env python3
"""Wraps the Godot web export into a Samsung TV (Tizen) web app.

Usage: python3 tools/tv/build_tv.py build/web build/tv [version]
Writes build/tv/ (unsigned app folder) and build/chimora-tv-unsigned.wgt.
Sign on a PC with Tizen Studio: tizen package -t wgt -s <profile> -- build/tv
"""
import os, re, shutil, subprocess, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
version = sys.argv[3] if len(sys.argv) > 3 else "1.0.0"
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
shutil.rmtree(out, ignore_errors=True)
shutil.copytree(src, out)

idx = os.path.join(out, "index.html")
html = open(idx, encoding="utf-8").read()
# The browser test version shows a "Test version" band; the TV app is the real game.
html = re.sub(r"<style>#chimora-test-band.*?</script>", "", html, flags=re.S)
shell = open(os.path.join(root, "tools/tv/tv_shell.js"), encoding="utf-8").read()
html = html.replace("<head>", "<head><script>" + shell + "</script><style>body{cursor:none}</style>", 1)
open(idx, "w", encoding="utf-8").write(html)

icon = Image.open(os.path.join(root, "art/icon/icon_1024.png")).convert("RGBA")
tile = Image.new("RGBA", (512, 423), (16, 20, 34, 255))
small = icon.resize((400, 400), Image.LANCZOS)
tile.paste(small, (56, 11), small)
tile.save(os.path.join(out, "tv_icon.png"))

open(os.path.join(out, "config.xml"), "w", encoding="utf-8").write(f"""<?xml version="1.0" encoding="UTF-8"?>
<widget xmlns="http://www.w3.org/ns/widgets" xmlns:tizen="http://tizen.org/ns/widgets" id="http://chimora.de/tv" version="{version}" viewmodes="maximized">
  <tizen:application id="ChimoraTV1.Chimora" package="ChimoraTV1" required_version="8.0"/>
  <content src="index.html"/>
  <feature name="http://tizen.org/feature/screen.size.normal.1080.1920"/>
  <icon src="tv_icon.png"/>
  <name>Chimora</name>
  <author href="https://play.nyrathen.com" email="lords.azz6@gmail.com">German Dream Games</author>
  <access origin="*" subdomains="true"/>
  <tizen:profile name="tv-samsung"/>
  <tizen:privilege name="http://tizen.org/privilege/internet"/>
  <tizen:privilege name="http://tizen.org/privilege/tv.inputdevice"/>
  <tizen:privilege name="http://tizen.org/privilege/application.launch"/>
  <tizen:setting screen-orientation="landscape" context-menu="disable" background-support="disable" encryption="disable" install-location="auto" hwkey-event="enable"/>
</widget>
""")

wgt = os.path.join(os.path.dirname(os.path.abspath(out)), "chimora-tv-unsigned.wgt")
if os.path.exists(wgt):
    os.remove(wgt)
subprocess.check_call(["zip", "-qr", wgt, "."], cwd=out)
print(wgt)
