"""Aegyo sound design: crystal singing bowls (modal synthesis + stereo convolution reverb).

Run:  tools/.venv/bin/python tools/make_sounds.py Aegyo/Resources/Sounds
Needs numpy + scipy (tools/.venv). Writes 48 kHz stereo .caf files:
  missyou.caf  ~4.5 s  notification chime when she receives "miss you"
  ring.caf     ~28 s   call-style ringtone (CallKit loops it)
  sent.caf     ~1.6 s  soft in-app confirmation when you tap the gem
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 48000
rng = np.random.default_rng(7)


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else 0) + (int(name[-1]) - 4) * 12
    return 440.0 * 2 ** (semis / 12)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def crystal_bowl(f0, seconds, amp=1.0, brightness=1.0, beat=0.9):
    """Struck crystal bowl. Each mode is a detuned pair -> slow, soothing beating ("wah-wah").
    Returns stereo array (n, 2)."""
    t = t_axis(seconds)
    # (ratio, gain, decay seconds) - crystal bowls are close to harmonic with gentle inharmonicity
    modes = [
        (1.000, 1.00, 9.0),
        (2.005, 0.30 * brightness, 4.5),
        (3.017, 0.10 * brightness, 2.6),
        (4.041, 0.05 * brightness, 1.6),
        (5.98, 0.022 * brightness, 0.9),
    ]
    out = np.zeros((t.size, 2))
    for i, (ratio, g, dec) in enumerate(modes):
        f = f0 * ratio
        split = beat * (1 + 0.35 * i)  # beating speed grows with partial
        env = np.exp(-t / dec)
        ph = rng.uniform(0, 2 * np.pi, 2)
        a = np.sin(2 * np.pi * (f - split / 2) * t + ph[0])
        b = np.sin(2 * np.pi * (f + split / 2) * t + ph[1])
        pan = 0.5 + 0.18 * (-1) ** i
        out[:, 0] += g * env * (a * (1 - pan) + b * pan)
        out[:, 1] += g * env * (a * pan + b * (1 - pan))
    # felt mallet: soft 4 ms attack plus a tiny low-passed "tok"
    attack = np.clip(t / 0.004, 0, 1) ** 2
    out *= attack[:, None]
    tok = rng.standard_normal(int(0.025 * SR)) * np.exp(-np.arange(int(0.025 * SR)) / (0.004 * SR))
    tok = sosfilt(butter(2, min(f0 * 3, 6000), "low", fs=SR, output="sos"), tok) * 0.12
    out[: tok.size] += tok[:, None]
    return out * amp


def glass_ting(f0, seconds=2.0, amp=0.25):
    """Small high glass bell - the 'sparkle'."""
    t = t_axis(seconds)
    sig = np.zeros(t.size)
    for ratio, g, dec in [(1.0, 1.0, 1.1), (2.756, 0.25, 0.45), (5.404, 0.08, 0.2)]:
        sig += g * np.exp(-t / dec) * np.sin(2 * np.pi * f0 * ratio * t)
    sig *= np.clip(t / 0.002, 0, 1)
    return np.stack([sig, sig], 1) * amp


def rubbed_hum(f0, seconds, amp=0.12, swell=3.0):
    """Rim-rubbed bowl drone: pure tone, slow swell, gentle vibrato. Stays under everything."""
    t = t_axis(seconds)
    vib = 0.25 * np.sin(2 * np.pi * 0.23 * t)
    sig = np.sin(2 * np.pi * f0 * t + vib) + 0.18 * np.sin(2 * np.pi * 2 * f0 * t + 2 * vib)
    env = (1 - np.exp(-t / swell)) * (0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t - 1.2))
    left = sig * env
    right = np.roll(sig, int(0.011 * SR)) * env
    return np.stack([left, right], 1) * amp


def reverb_ir(seconds=3.4, rt60=3.0):
    """Synthetic hall: decorrelated stereo noise, exponential decay, darker as it decays."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    decay = np.exp(-6.91 * t / rt60)
    ir = np.zeros((n, 2))
    for ch in range(2):
        noise = rng.standard_normal(n)
        bright = sosfilt(butter(2, 7000, "low", fs=SR, output="sos"), noise)
        dark = sosfilt(butter(2, 1800, "low", fs=SR, output="sos"), noise)
        mix = np.exp(-t / 0.6)
        ir[:, ch] = (bright * mix + dark * (1 - mix)) * decay
    pre = int(0.022 * SR)
    ir = np.vstack([np.zeros((pre, 2)), ir])
    return ir / np.sqrt(np.sum(ir ** 2, 0))


IR = reverb_ir()


def place(buf, sig, at):
    i = int(at * SR)
    j = min(buf.shape[0], i + sig.shape[0])
    buf[i:j] += sig[: j - i]


def master(dry, wet=0.32, tail_fade=1.2):
    wetsig = np.stack([fftconvolve(dry[:, c], IR[:, c])[: dry.shape[0]] for c in range(2)], 1)
    mix = dry * (1 - wet) + wetsig * wet * 2.2
    # gentle low cut (phone speakers) and soft high shelf down via low-pass at 12k
    mix = sosfilt(butter(2, 140, "high", fs=SR, output="sos"), mix, axis=0)
    mix = sosfilt(butter(2, 12000, "low", fs=SR, output="sos"), mix, axis=0)
    # fade out tail
    n = int(tail_fade * SR)
    mix[-n:] *= np.linspace(1, 0, n)[:, None] ** 2
    # soft-knee limiting, then normalise to -1 dBFS
    mix = np.tanh(mix / (np.max(np.abs(mix)) * 0.9))
    return mix / np.max(np.abs(mix)) * 10 ** (-1 / 20)


def write(path, stereo):
    pcm = (np.clip(stereo, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def miss_you():
    dur = 4.6
    buf = np.zeros((int(dur * SR), 2))
    place(buf, rubbed_hum(note("C4"), dur, amp=0.05, swell=0.8), 0)
    place(buf, crystal_bowl(note("G5"), dur, amp=0.85, brightness=0.9), 0.0)
    place(buf, glass_ting(note("D7"), amp=0.10), 0.16)
    place(buf, glass_ting(note("G7"), amp=0.07), 0.31)
    place(buf, crystal_bowl(note("C5"), dur - 0.5, amp=0.45, brightness=0.6, beat=0.6), 0.5)
    return master(buf, wet=0.34, tail_fade=1.6)


def ring():
    dur = 28.0
    buf = np.zeros((int(dur * SR), 2))
    place(buf, rubbed_hum(note("C4"), dur, amp=0.07, swell=2.5), 0)
    phrase = [("G5", 0.0, 0.9), ("D5", 1.5, 0.65), ("E5", 3.6, 0.75)]
    for cycle in range(4):
        base = cycle * 7.0
        for n, at, amp in phrase:
            place(buf, crystal_bowl(note(n), 6.5, amp=amp, brightness=0.8), base + at)
        place(buf, glass_ting(note("B6"), amp=0.05), base + 3.75)
    return master(buf, wet=0.3, tail_fade=2.5)


def sent():
    dur = 1.8
    buf = np.zeros((int(dur * SR), 2))
    place(buf, glass_ting(note("E6"), 1.8, amp=0.5), 0)
    place(buf, glass_ting(note("B6"), 1.5, amp=0.25), 0.07)
    return master(buf, wet=0.35, tail_fade=0.9) * 0.6


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in [("missyou", miss_you), ("ring", ring), ("sent", sent)]:
        wav = os.path.join(out_dir, f"{name}.wav")
        caf = os.path.join(out_dir, f"{name}.caf")
        write(wav, fn())
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@48000", "-c", "2", wav, caf], check=True)
        os.remove(wav)
        print("wrote", caf)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Aegyo/Resources/Sounds")
