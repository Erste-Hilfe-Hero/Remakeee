"""Chimora's music (plan area 6, items 2443 to 2456, 2475): chord charts and motifs written for
this game, synthesized as four channels (bass, chords, melody, drums). Every song can also be
written as four stems of exactly the same length for the in-game MusicDirector.

The game's leitmotif opens the lighthouse song and returns, changed, in every place song.
"""
from __future__ import annotations

import random

import numpy as np

from synth import NOTE_INDEX, env, freq, midi, noise, pulse, secs, sweep, triangle

CHORD_SHAPES = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
                "sus4": [0, 5, 7], "sus2": [0, 2, 7], "dim": [0, 3, 6], "add9": [0, 4, 7, 14]}
STEMS = ["bass", "chords", "melody", "drums"]
# Song channel -> stem name.
CHANNEL_STEM = {"bass": "bass", "harm": "chords", "lead": "melody", "drums": "drums"}
SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def chord_tones(sym: str) -> tuple[int, list[int]]:
    root = sym[0]
    rest = sym[1:]
    if rest[:1] in ("#", "b"):
        root += rest[0]
        rest = rest[1:]
    return NOTE_INDEX[root], CHORD_SHAPES[rest]


def note_name(m: int) -> str:
    return "%s%d" % (SHARP_NAMES[m % 12], m // 12 - 1)


# --- Motif text --------------------------------------------------------------------------

def parse_line(text: str) -> list[tuple[int | None, int]]:
    """'E5:4 G5:2 -:2' -> [(midi, steps), ...]; '-' is a rest."""
    out = []
    for tok in text.split():
        name, dur = tok.split(":")
        out.append((None if name == "-" else midi(name), int(dur)))
    return out


def unparse(notes: list[tuple[int | None, int]]) -> str:
    return " ".join("%s:%d" % ("-" if m is None else note_name(m), d) for m, d in notes)


def transpose(line: str, semis: int) -> str:
    return unparse([(None if m is None else m + semis, d) for m, d in parse_line(line)])


def to_minor(line: str, tonic: int) -> str:
    """Major-key line -> natural minor on the same tonic (lowers the 3rd, 6th and 7th)."""
    out = []
    for m, d in parse_line(line):
        if m is not None and (m - tonic) % 12 in (4, 9, 11):
            m -= 1
        out.append((m, d))
    return unparse(out)


def refit(line: str, from_steps: int, to_steps: int) -> str:
    """Re-times a bar written for [from_steps] steps into [to_steps] (e.g. 16 -> 12 for 6/8),
    rounding note starts so the bar still fills exactly."""
    notes = parse_line(line)
    pos, starts = 0, []
    for _, d in notes:
        starts.append(pos)
        pos += d
    starts.append(pos)
    scaled = [round(s * to_steps / from_steps) for s in starts]
    out = []
    for i, (m, _) in enumerate(notes):
        d = scaled[i + 1] - scaled[i]
        if d > 0:
            out.append((m, d))
    return unparse(out)


# The game's leitmotif in D major, four bars (item 2444).
LEITMOTIF = ["D5:4 F#5:2 A5:2 B5:4 A5:4", "F#5:6 E5:2 D5:8", "G5:4 F#5:2 E5:2 F#5:4 A5:4", "E5:6 C#5:2 D5:8"]
LEIT_TONIC = midi("D5")
# Shared three-note Rift motif (item 2456): a semitone up, then a fall of a fifth.
RIFT_MOTIF = [0, 1, -6]


def leitmotif(semis: int = 0, minor: bool = False, steps: int = 16, bars: int = 4) -> list[str]:
    out = []
    for line in LEITMOTIF[:bars]:
        if minor:
            line = to_minor(line, LEIT_TONIC)
        line = transpose(line, semis)
        if steps != 16:
            line = refit(line, 16, steps)
        out.append(line)
    return out


def rift_motif(root: str, steps: int = 16) -> str:
    base = midi(root)
    q = steps // 4
    return unparse([(base + RIFT_MOTIF[0], q), (base + RIFT_MOTIF[1], q), (base + RIFT_MOTIF[2], steps - 2 * q)])


# --- Song ---------------------------------------------------------------------------------

class Song:
    """Four channels on a 16th-note grid: lead, harmony, bass (triangle), drums (noise).
    Each channel has its own buffer so the song can be written as stems."""

    def __init__(self, bpm: int, bars: int, steps_per_bar: int = 16, seed: int = 1, lead_wave: str = "pulse25",
                 harm_duty: float = 0.125, harm_tremolo: float = 0.0, bass_vol: float = 1.0):
        self.bpm = bpm
        self.bars = bars
        self.spb = steps_per_bar
        self.step = 60.0 / bpm / 4.0
        self.total = secs(self.step * steps_per_bar * bars)
        self.ch = {c: np.zeros(self.total) for c in CHANNEL_STEM}
        self.rng = np.random.default_rng(seed)
        self.lead_wave = lead_wave
        self.harm_duty = harm_duty
        self.harm_tremolo = harm_tremolo
        self.bass_vol = bass_vol

    def at(self, step_index: int) -> int:
        return secs(self.step * step_index)

    def note(self, ch: str, m: float, start: int, length: int, vol: float) -> None:
        s = self.at(start)
        n = min(self.at(start + length) - s, self.total - s)
        if n <= 0:
            return
        f = freq(m)
        if ch == "lead":
            if self.lead_wave == "tri":
                w = triangle(f, n) * env(n, decay=0.06, sustain=0.7, release=0.03) * 1.6
            else:
                duty = {"pulse25": 0.25, "pulse12": 0.125, "pulse50": 0.5}[self.lead_wave]
                w = pulse(f, n, duty) * env(n, decay=0.06, sustain=0.55, release=0.03)
        elif ch == "harm":
            w = pulse(f, n, self.harm_duty) * env(n, decay=0.04, sustain=0.35, release=0.02)
        else:
            w = triangle(f, n) * env(n, attack=0.002, decay=0.02, sustain=0.9, release=0.02) * self.bass_vol
        self.ch[ch][s:s + n] += w * vol

    def drum(self, kind: str, start: int, vol: float) -> None:
        s = self.at(start)
        if s >= self.total:
            return
        if kind == "k":
            n = min(secs(0.09), self.total - s)
            w = sweep(160, 45, n, "tri") * env(n, decay=0.06, sustain=0.0, release=0.01)
        elif kind == "s":
            n = min(secs(0.1), self.total - s)
            w = noise(n, 1, self.rng) * env(n, decay=0.07, sustain=0.0, release=0.01)
        elif kind == "w":
            # Wood knock: short, coarse noise with a quick fall (thornridge, item 2450).
            n = min(secs(0.04), self.total - s)
            w = noise(n, 6, self.rng) * env(n, attack=0.001, decay=0.02, sustain=0.0, release=0.005) * 0.8
        else:
            n = min(secs(0.03), self.total - s)
            w = noise(n, 1, self.rng) * env(n, decay=0.02, sustain=0.0, release=0.005) * 0.5
        self.ch["drums"][s:s + n] += w * vol

    def crackle(self, density: float, vol: float) -> None:
        """Sparse ember crackle on the drum channel (cinder_rift, item 2453)."""
        n = self.total
        clicks = self.rng.random(n // 200) < density
        for i in np.nonzero(clicks)[0]:
            s = int(i * 200 + self.rng.integers(0, 200))
            k = min(secs(0.012), n - s)
            if k > 0:
                self.ch["drums"][s:s + k] += noise(k, 1, self.rng) * np.linspace(1, 0, k) * vol

    def finish(self) -> None:
        if self.harm_tremolo > 0.0:
            t = np.arange(self.total) / 22050.0
            self.ch["harm"] *= 0.65 + 0.35 * np.sin(2 * np.pi * self.harm_tremolo * t)

    def stems(self) -> dict[str, np.ndarray]:
        """The four stems scaled together so they add up to render()."""
        mix = sum(self.ch.values())
        k = 0.85 / (np.max(np.abs(mix)) or 1.0)
        return {CHANNEL_STEM[c]: buf * k for c, buf in self.ch.items()}

    def render(self) -> np.ndarray:
        return sum(self.stems().values())


def write_line(song: Song, ch: str, line: str, start_bar: int, vol: float) -> None:
    pos = start_bar * song.spb
    for m, d in parse_line(line):
        if m is not None:
            song.note(ch, m, pos, d, vol)
        pos += d


DRUM_PATTERNS = {
    "none": "................",
    "soft": "k.......h.......",
    "walk": "k...h...k...h...",
    "drive": "k.h.s.h.k.hks.h.",
    "battle": "k.hks.hkk.hks.hs",
    "march": "k...s...k.k.s...",
    "sparse": "k...............",
    "wood": "w..w..w.w...w...",
    "sway": "k.....h.....",
}


def compose(name: str, bpm: int, chords: list[str], motifs: list[str], bass_style: str, arp_style: str,
            drums: str, seed: int, lead_vol: float = 0.32, octave: int = 4, variation: bool = True,
            steps: int = 16, quotes: dict[int, str] | None = None, lead_wave: str = "pulse25",
            harm_duty: float = 0.125, harm_tremolo: float = 0.0, bass_vol: float = 1.0, rest_prob: float = 0.12,
            leaps: bool = False, grace: bool = False, crackle: float = 0.0, stems: bool = False) -> Song:
    """Chords: one symbol per bar. Motifs: hand-written lead lines (one bar each) over the first
    bars; [quotes] puts more written bars anywhere (bar -> line); every other bar gets a seeded
    walk over the bar's chord tones."""
    rng = random.Random(seed)
    song = Song(bpm, len(chords), steps, seed, lead_wave, harm_duty, harm_tremolo, bass_vol)
    spb = steps
    for bar, sym in enumerate(chords):
        root, shape = chord_tones(sym)
        base = 12 * (octave + 1) + root
        b0 = bar * spb
        broot = 12 * 3 + root if root >= 5 else 12 * 4 + root - 12
        if bass_style == "pulse8":
            for i in range(0, spb, 2):
                song.note("bass", broot + (12 if i % 4 == 2 else 0), b0 + i, 2, 0.5)
        elif bass_style == "walk":
            for i, deg in enumerate([0, shape[1], shape[2], shape[1]]):
                song.note("bass", broot + deg, b0 + i * (spb // 4), spb // 4, 0.5)
        elif bass_style == "drone":
            song.note("bass", broot, b0, spb, 0.45)
        elif bass_style == "bounce":
            # Hopping market bass: root, octave, fifth, octave (item 2445).
            for i, deg in enumerate([0, 12, 7, 12, 0, 12, 7, 5]):
                song.note("bass", broot + deg, b0 + i * 2, 1, 0.5)
        elif bass_style == "sway":
            # 6/8: root on the first and fourth eighth (item 2448).
            song.note("bass", broot, b0, spb // 2, 0.5)
            song.note("bass", broot + 7, b0 + spb // 2, spb // 2, 0.45)
        else:  # root-fifth
            song.note("bass", broot, b0, spb // 2, 0.5)
            song.note("bass", broot + 7, b0 + spb // 2, spb // 2, 0.5)
        tones = [base + s for s in shape]
        if arp_style == "up":
            for i in range(spb // 2):
                song.note("harm", tones[i % len(tones)], b0 + i * 2, 2, 0.16)
        elif arp_style == "climb":
            # Rising arpeggio over two octaves, like terraces (item 2446).
            for i in range(spb):
                song.note("harm", tones[i % len(tones)] + 12 * (i // len(tones) % 2), b0 + i, 1, 0.12)
        elif arp_style == "musicbox":
            # Quiet high music-box arpeggio (item 2451).
            for i in range(0, spb, 2):
                song.note("harm", tones[(i // 2) % len(tones)] + 24, b0 + i, 2, 0.09)
        elif arp_style == "pad":
            for m in tones[:3]:
                song.note("harm", m, b0, spb, 0.08)
        elif arp_style == "stab":
            for i in range(2, spb, 4):
                for m in tones[:3]:
                    song.note("harm", m, b0 + i, 1, 0.07)
        elif arp_style == "rolling":
            order = [0, 1, 2, 1] if len(tones) < 4 else [0, 1, 2, 3]
            for i in range(spb):
                song.note("harm", tones[order[i % 4]] + (12 if i >= spb // 2 else 0), b0 + i, 1, 0.12)
        pattern = DRUM_PATTERNS[drums]
        for i, ch in enumerate(pattern[:spb]):
            if ch != ".":
                song.drum(ch, b0 + i, 0.35 if ch not in "h" else 0.25)
    written = dict(enumerate(motifs))
    written.update(quotes or {})
    for bar, line in written.items():
        if bar < len(chords):
            write_line(song, "lead", line, bar, lead_vol)
    if variation:
        rhythms = [[4, 2, 2, 4, 4], [2, 2, 4, 2, 2, 4], [6, 2, 4, 4], [4, 4, 4, 4], [3, 3, 2, 4, 4]]
        if spb == 12:
            rhythms = [[6, 6], [4, 2, 4, 2], [6, 4, 2], [2, 2, 2, 6]]
        prev = None
        for bar in range(len(chords)):
            if bar in written:
                continue
            root, shape = chord_tones(chords[bar])
            pool = sorted({12 * (octave + 2) + root + s + o for s in shape for o in (-12, 0)})
            pos = bar * spb
            for d in rng.choice(rhythms):
                if rng.random() < rest_prob and prev is not None:
                    pos += d
                    continue
                if prev is None:
                    m = rng.choice(pool)
                elif leaps:
                    # Wide intervals: jump a fifth or an octave where the chord allows (item 2447).
                    far = [p for p in pool if abs(p - prev) in (7, 12)] or pool
                    m = rng.choice(far)
                else:
                    m = rng.choice(sorted(pool, key=lambda p: abs(p - prev))[:3])
                if grace and d >= 4 and rng.random() < 0.4:
                    # Short grace note a step above (item 2450).
                    song.note("lead", m + 2, pos, 1, lead_vol * 0.8)
                    song.note("lead", m, pos + 1, d - 1, lead_vol)
                else:
                    song.note("lead", m, pos, d, lead_vol)
                prev = m
                pos += d
    if crackle > 0.0:
        song.crackle(crackle, 0.18)
    song.finish()
    return song


# --- The songs ----------------------------------------------------------------------------

SONGS = {
    "title": dict(bpm=92, chords=["Dm", "Bbmaj7", "F", "C", "Dm", "Bbmaj7", "Gm", "A7"], arp_style="up", bass_style="root-fifth",
                  drums="soft", seed=11, motifs=["D5:6 F5:2 A5:4 G5:4", "F5:6 E5:2 D5:4 C5:4", "C5:4 F5:4 A5:6 G5:2", "E5:8 -:4 G5:4"]),
    "town": dict(bpm=104, chords=["G", "Em", "C", "D", "G", "Em", "Am7", "D7", "C", "D", "Bm", "Em", "C", "D", "G", "G"], arp_style="rolling",
                 bass_style="walk", drums="walk", seed=23, motifs=["B4:4 D5:4 G5:6 F#5:2", "E5:4 G5:2 E5:2 B4:8", "C5:4 E5:4 G5:4 E5:4", "F#5:6 E5:2 D5:8"]),
    "route": dict(bpm=132, chords=["A", "F#m", "D", "E", "A", "F#m", "Bm", "E7", "D", "E", "C#m", "F#m", "D", "E", "A", "E"], arp_style="up",
                  bass_style="pulse8", drums="drive", seed=37, motifs=["A4:2 C#5:2 E5:4 A5:4 G#5:2 F#5:2", "F#5:4 E5:2 C#5:2 A4:8", "D5:2 F#5:2 A5:4 F#5:4 D5:4", "E5:6 G#5:2 B5:8"]),
    "rift": dict(bpm=78, chords=["Em", "Fmaj7", "Em", "Ebmaj7", "Em", "Fmaj7", "Dm", "Edim"], arp_style="pad", bass_style="drone",
                 drums="soft", seed=41, motifs=["E5:8 B4:4 C5:4", "A4:12 -:4"], lead_vol=0.26),
    "battle": dict(bpm=152, chords=["Em", "Em", "C", "D", "Em", "Em", "Am", "B7", "C", "D", "Bm", "Em", "C", "D", "B7", "B7"], arp_style="rolling",
                   bass_style="pulse8", drums="battle", seed=53, motifs=["E5:2 E5:2 G5:2 E5:2 B5:4 A5:4", "G5:2 F#5:2 E5:4 B4:8", "C5:2 E5:2 G5:4 C6:4 B5:4", "A5:4 F#5:4 D5:8"]),
    "warden": dict(bpm=164, chords=["Cm", "Ab", "Bb", "G7", "Cm", "Ab", "Fm", "G7", "Ab", "Bb", "Gm", "Cm", "Ab", "Bb", "G7", "G7"], arp_style="rolling",
                   bass_style="pulse8", drums="battle", seed=67, motifs=["C5:2 Eb5:2 G5:4 C6:4 Bb5:4", "Ab5:4 G5:2 Eb5:2 C5:8", "D5:2 F5:2 Bb5:4 Ab5:4 G5:4", "G5:4 B5:4 D6:8"]),
    # Battle music once your Spirling is low on HP (item 69): faster, tenser, same key as "battle".
    "battle_pinch": dict(bpm=176, chords=["Em", "F", "Em", "F", "C", "B7", "Em", "B7"], arp_style="rolling",
                         bass_style="pulse8", drums="battle", seed=59, motifs=["B5:2 C6:2 B5:2 G5:2 E5:4 F5:4", "E5:2 G5:2 B5:4 D#5:8", "C6:2 B5:2 A5:2 G5:2 E5:8", "D#5:4 F#5:4 B5:8"]),
    "victory": dict(bpm=140, chords=["C", "F", "G", "C"], arp_style="stab", bass_style="root-fifth", drums="march", seed=71, variation=False,
                    motifs=["C5:2 E5:2 G5:2 C6:6 -:4", "A5:2 C6:2 A5:2 F5:6 -:4", "G5:2 B5:2 D6:2 B5:2 G5:4 F5:4", "E5:8 C5:8"]),
}

# One song per map (item 2443), each 60 to 120 s and each quoting the leitmotif (item 2449).
MAP_SONGS = {
    # Calm, D major, triangle melody over a drone; the leitmotif in full (item 2444).
    "lighthouse": dict(bpm=84, chords=["D", "Bm", "G", "A", "D", "Bm", "Em", "A", "G", "A", "F#m", "Bm", "G", "A", "D", "D",
                                       "Bm", "G", "D", "A", "G", "Em", "A", "D"],
                       motifs=leitmotif(), quotes=dict(zip(range(12, 16), leitmotif(0))), arp_style="pad",
                       bass_style="drone", drums="none", seed=101, lead_wave="tri"),
    # Market town, G major, hopping bass, 25 % pulse melody (item 2445).
    "brindlewick": dict(bpm=112, chords=["G", "C", "D", "G", "Em", "C", "Am", "D", "G", "C", "D", "G", "Em", "Am", "D7", "G"] * 2,
                        motifs=["G4:2 B4:2 D5:2 G5:2 E5:4 D5:4", "C5:2 E5:2 G5:4 E5:4 C5:4", "D5:4 F#5:2 A5:2 F#5:4 D5:4", "B4:4 G4:4 B4:4 D5:4"],
                        quotes=dict(zip(range(8, 12), leitmotif(-7))),
                        arp_style="stab", bass_style="bounce", drums="walk", seed=103, lead_wave="pulse25"),
    # Fern terraces, A major, rising arpeggios (item 2446).
    "fernstair": dict(bpm=128, chords=["A", "D", "E", "A", "F#m", "D", "E", "E7", "A", "C#m", "D", "E", "F#m", "Bm", "E", "A"] * 2
                      + ["D", "E", "A", "A"],
                      motifs=["A4:2 C#5:2 E5:2 A5:2 C#6:4 B5:4", "A5:4 F#5:4 D5:4 F#5:4", "E5:2 G#5:2 B5:4 E6:4 B5:4", "A5:8 E5:8"],
                      quotes=dict(zip(range(12, 16), leitmotif(7 - 12))), arp_style="climb", bass_style="pulse8",
                      drums="drive", seed=107),
    # Cliffs, E minor, fifths and octaves, little percussion (item 2447).
    "crowcrest": dict(bpm=120, chords=["Em", "C", "G", "D", "Em", "Am", "B7", "Em", "C", "G", "Am", "B7", "Em", "C", "D", "Em"] * 2,
                      motifs=["E5:4 B5:4 E6:4 B5:4", "A5:4 E5:4 A4:8", "G5:4 D6:4 G5:4 D5:4", "F#5:4 B5:4 F#5:8"],
                      quotes=dict(zip(range(16, 20), leitmotif(2, minor=True))), arp_style="pad", bass_style="root-fifth",
                      drums="sparse", seed=109, leaps=True),
    # Marsh, F mixolydian (E flat), swaying 6/8 (item 2448).
    "saltmarsh": dict(bpm=96, steps=12, chords=["F", "Eb", "Bb", "F", "F", "Eb", "C", "F", "Bb", "Eb", "F", "C"] * 3,
                      motifs=["F5:6 A5:4 C6:2", "Eb5:6 G5:6", "D5:4 F5:2 Bb5:6", "C5:12"],
                      quotes=dict(zip(range(12, 16), leitmotif(3, steps=12))), arp_style="pad", bass_style="sway",
                      drums="sway", seed=113),
    # Village, C major, grace notes and wood knocks (item 2450).
    "thornridge": dict(bpm=100, chords=["C", "F", "G", "C", "Am", "F", "G7", "C", "F", "C", "Dm", "G", "C", "Am", "G7", "C"] * 2,
                       motifs=["C5:4 E5:2 G5:2 E5:4 C5:4", "F5:4 A5:4 G5:4 E5:4", "D5:2 E5:2 F5:4 G5:4 B4:4", "C5:8 G4:8"],
                       quotes=dict(zip(range(8, 12), leitmotif(-2))), arp_style="stab", bass_style="walk",
                       drums="wood", seed=127, grace=True),
    # The map house, B flat major, a quiet music box (item 2451).
    "map_house": dict(bpm=76, chords=["Bb", "Gm", "Eb", "F", "Bb", "Gm", "Cm", "F", "Eb", "F", "Dm", "Gm", "Eb", "F", "Bb", "Bb",
                                      "Gm", "Eb", "F", "Bb"],
                      motifs=["D5:4 F5:4 Bb5:8", "G5:4 F5:4 D5:8"], quotes=dict(zip(range(8, 12), leitmotif(-4))),
                      arp_style="musicbox", bass_style="drone", drums="none", seed=131, lead_wave="tri", lead_vol=0.22,
                      harm_duty=0.125),
    # Rest spring, E flat major, slow chord fields, no drums (item 2452).
    "rest_spring": dict(bpm=70, chords=["Eb", "Cm", "Ab", "Bb", "Eb", "Gm", "Ab", "Bb", "Cm", "Ab", "Eb", "Bb", "Ab", "Bb", "Eb", "Eb",
                                        "Ab", "Eb"],
                        motifs=["G5:8 Bb5:8", "C6:8 G5:8"], quotes=dict(zip(range(4, 8), leitmotif(1))),
                        arp_style="pad", bass_style="drone", drums="none", seed=137, lead_wave="tri", lead_vol=0.24, rest_prob=0.3),
    # Cinder Rift, C minor, low pulse and ember crackle (item 2453).
    "cinder_rift": dict(bpm=84, chords=["Cm", "Ab", "Cm", "G", "Cm", "Fm", "Ab", "G", "Cm", "Ab", "Bb", "G", "Fm", "Ab", "G", "Cm"]
                        + ["Cm", "Ab", "Fm", "G", "Cm", "Ab", "G", "Cm"],
                        motifs=[rift_motif("C5"), "G4:8 -:8"], quotes={**dict(zip(range(8, 12), leitmotif(-2, minor=True))), 16: rift_motif("C5")},
                        arp_style="pad", bass_style="pulse8", drums="soft", seed=139, crackle=0.05, lead_vol=0.26, octave=3),
    # Tide Rift, F sharp minor, a tremolo of 3 Hz in the chord bed (item 2454).
    "tide_rift": dict(bpm=80, chords=["F#m", "D", "F#m", "C#7", "Bm", "D", "C#7", "F#m"] * 3,
                      motifs=[rift_motif("F#5"), "C#5:12 -:4"], quotes={**dict(zip(range(8, 12), leitmotif(4, minor=True))), 16: rift_motif("F#5")},
                      arp_style="pad", bass_style="drone", drums="soft", seed=149, harm_tremolo=3.0, lead_vol=0.26),
    # Murk Hollow, B flat minor, muted bass and long rests (item 2455).
    "murk_hollow": dict(bpm=66, chords=["Bbm", "Gb", "Bbm", "F7", "Ebm", "Gb", "F7", "Bbm", "Bbm", "Gb", "Ebm", "F7",
                                        "Bbm", "Gb", "F7", "Bbm", "Ebm", "Bbm"],
                        motifs=[rift_motif("Bb4"), "-:16"], quotes={**dict(zip(range(6, 10), leitmotif(-4, minor=True))), 12: rift_motif("Bb4")},
                        arp_style="pad", bass_style="drone", drums="sparse", seed=151, bass_vol=0.5, rest_prob=0.45, lead_vol=0.24),
    # Echo Path behind the Cinder Rift (endgame), G minor: the rift motif climbs over a slow pulse.
    "echo_path": dict(bpm=90, chords=["Gm", "Eb", "Gm", "D", "Cm", "Eb", "D", "Gm"] * 3,
                      motifs=[rift_motif("G4"), "D5:8 -:8"], quotes={**dict(zip(range(8, 12), leitmotif(5, minor=True))), 16: rift_motif("G5")},
                      arp_style="climb", bass_style="pulse8", drums="soft", seed=157, lead_vol=0.25),
}
# Tracks that play once (jingles) instead of looping.
ONE_SHOT = {"victory"}
