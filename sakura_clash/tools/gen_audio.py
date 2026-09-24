#!/usr/bin/env python3
"""Procedural sound + music generator for Sakura Clash.

Run from the project root:  python3 tools/gen_audio.py
Writes 16-bit mono WAV files into assets/sfx and assets/music.
Everything is synthesized (no samples), so the output is license-free.
"""
import os
import wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "music")
SR = 44100
rng = np.random.default_rng(1337)


# ----------------------------------------------------------------- helpers
def t_axis(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env_exp(dur, decay, sr=SR, attack=0.002):
    t = t_axis(dur, sr)
    e = np.exp(-t / max(decay, 1e-4))
    if attack > 0:
        e *= np.clip(t / attack, 0, 1)
    return e


def env_adsr(n, a, d, s, r, sr=SR):
    e = np.ones(n) * s
    ia, idd, ir = int(a * sr), int(d * sr), int(r * sr)
    ia = max(ia, 1)
    e[:ia] = np.linspace(0, 1, ia)
    e[ia:ia + idd] = np.linspace(1, s, len(e[ia:ia + idd]))
    if ir > 0:
        e[-ir:] *= np.linspace(1, 0, len(e[-ir:]))
    return e


def noise(n):
    return rng.uniform(-1, 1, n)


def onepole_lp(x, cutoff, sr=SR):
    """Time-varying or fixed one-pole lowpass."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def onepole_hp(x, cutoff, sr=SR):
    return x - onepole_lp(x, cutoff, sr)


def bandpass(x, lo, hi, sr=SR):
    return onepole_lp(onepole_hp(x, lo, sr), hi, sr)


def sweep_sine(f0, f1, dur, sr=SR, curve=2.0):
    t = t_axis(dur, sr)
    k = (t / dur) ** (1.0 / curve) if curve != 1 else t / dur
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph)


def fit(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, secs, sr=SR):
    return np.concatenate([np.zeros(int(secs * sr)), x])


def reverb(x, amount=0.25, room=0.6, sr=SR, tail=0.8):
    """Tiny Schroeder reverb (4 combs + 2 allpasses)."""
    x = np.concatenate([x, np.zeros(int(tail * sr))])
    out = np.zeros_like(x)
    for d, g in ((0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0437, 0.74)):
        n = int(d * sr * (0.6 + room))
        g = g * (0.75 + 0.25 * room)
        y = x.copy()
        # comb: y[i] = x[i] + g*y[i-n], processed blockwise (vectorised per block)
        for s in range(n, len(y), n):
            e = min(s + n, len(y))
            y[s:e] += g * y[s - n:e - n]
        out += y
    out /= 4
    for d, g in ((0.005, 0.7), (0.0017, 0.7)):
        n = max(1, int(d * sr))
        y = np.zeros_like(out)
        buf = np.concatenate([np.zeros(n), out])
        yb = np.zeros(len(out) + n)
        for s in range(0, len(out), n):
            e = min(s + n, len(out))
            yb[s + n:e + n] = -g * buf[s + n:e + n] + buf[s:e] + g * yb[s:e]
        out = yb[n:]
    return x * (1 - amount) + out * amount


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_out(x, secs=0.01, sr=SR):
    n = min(len(x), int(secs * sr))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data)


def save(name, x, peak=0.85, rev=0.0, room=0.5):
    if rev > 0:
        x = reverb(x, rev, room)
    x = fade_out(normalize(x, peak), 0.015)
    # trim trailing silence
    thr = 0.002
    idx = np.nonzero(np.abs(x) > thr)[0]
    if len(idx):
        x = x[: min(len(x), idx[-1] + int(0.02 * SR))]
    write_wav(os.path.join(SFX_DIR, name + ".wav"), x)


# ------------------------------------------------------------- sfx recipes
def whoosh(dur=0.22, lo=400, hi=3000, peak_t=0.35, brightness=1.0):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    env = np.where(t < peak_t, (t / peak_t) ** 1.5, ((1 - t) / (1 - peak_t)) ** 2.2)
    cut = lo + (hi - lo) * np.sin(np.pi * np.clip(t / (peak_t * 2), 0, 1)) * brightness
    x = onepole_lp(noise(n), cut)
    x = onepole_lp(x, cut * 1.3)
    return onepole_hp(x, 150) * env


def thump(f0=110, f1=45, dur=0.25, decay=0.08):
    return sweep_sine(f0, f1, dur, curve=0.5) * env_exp(dur, decay, attack=0.001)


def crack(dur=0.06, cut=5000):
    n = int(dur * SR)
    return onepole_hp(noise(n), cut * 0.25) * env_exp(dur, dur / 4, attack=0.0005)


def metal(freqs, dur=0.9, decay=0.25, amps=None):
    t = t_axis(dur)
    out = np.zeros_like(t)
    amps = amps or [1.0] * len(freqs)
    for i, (f, a) in enumerate(zip(freqs, amps)):
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / (decay / (1 + i * 0.35)))
    return out


def build_sfx():
    os.makedirs(SFX_DIR, exist_ok=True)
    save("swing_l", whoosh(0.16, 600, 4200, 0.3), 0.55)
    save("swing_m", whoosh(0.22, 450, 3400, 0.35), 0.62)
    save("swing_h", mix(whoosh(0.34, 250, 2600, 0.45), 0.4 * whoosh(0.30, 120, 900, 0.5)), 0.7)

    shing = metal([3100, 4650, 6900], 0.35, 0.09, [1, 0.5, 0.3])
    save("slash_l", mix(whoosh(0.15, 900, 6000, 0.25), 0.18 * shing), 0.6, rev=0.12)
    save("slash_h", mix(whoosh(0.3, 500, 5000, 0.35), 0.25 * metal([2300, 3800, 5600], 0.5, 0.14)), 0.7, rev=0.18)

    save("hit_l", mix(thump(160, 70, 0.14, 0.04), 0.55 * crack(0.05, 6000)), 0.8)
    save("hit_m", mix(thump(130, 50, 0.22, 0.06), 0.6 * crack(0.07, 5000), 0.3 * bandpass(noise(4000), 300, 1500) * env_exp(4000 / SR, 0.02)), 0.85)
    save("hit_h", mix(thump(110, 35, 0.45, 0.12), 0.7 * crack(0.10, 4000), 0.5 * onepole_lp(noise(9000), 900) * env_exp(9000 / SR, 0.05)), 0.95, rev=0.2, room=0.8)
    save("hit_slash", mix(thump(150, 60, 0.18, 0.05), 0.8 * crack(0.06, 9000), 0.12 * metal([4200, 6100], 0.25, 0.06)), 0.85)

    save("block", mix(thump(220, 120, 0.12, 0.03), 0.35 * bandpass(noise(3000), 800, 2500) * env_exp(3000 / SR, 0.015)), 0.7)
    save("parry", mix(metal([1250, 3450, 6750, 11100, 2480], 1.3, 0.45, [1, 0.8, 0.5, 0.3, 0.6]), 0.6 * crack(0.04, 8000)), 0.85, rev=0.3, room=0.8)
    shards = np.zeros(int(0.9 * SR))
    for _ in range(26):
        st = int(rng.uniform(0, 0.35) * SR)
        f = rng.uniform(2500, 9000)
        piece = metal([f, f * 1.51], 0.3, rng.uniform(0.03, 0.1))
        shards[st:st + len(piece)] += piece[: len(shards) - st] * rng.uniform(0.2, 0.6)
    save("guard_break", mix(thump(90, 30, 0.5, 0.15), shards, 0.5 * crack(0.2, 3000)), 0.9, rev=0.2)

    save("dash", whoosh(0.2, 300, 2400, 0.2), 0.6)
    save("jump", mix(whoosh(0.16, 300, 1800, 0.25), 0.3 * thump(90, 60, 0.08, 0.03)), 0.5)
    chime = metal([1760, 2640, 3520], 0.6, 0.18, [1, 0.5, 0.3])
    save("double_jump", mix(whoosh(0.22, 500, 3500, 0.3), 0.18 * delay(chime, 0.02)), 0.55, rev=0.25)
    save("land", mix(thump(90, 40, 0.16, 0.05), 0.3 * onepole_lp(noise(3000), 700) * env_exp(3000 / SR, 0.03)), 0.55)
    step = onepole_lp(noise(2000), 900) * env_exp(2000 / SR, 0.01)
    save("step", step, 0.3)

    flap = mix(onepole_lp(noise(int(0.12 * SR)), 700) * env_adsr(int(0.12 * SR), 0.03, 0.03, 0.4, 0.05),
               delay(0.7 * onepole_lp(noise(int(0.1 * SR)), 500) * env_adsr(int(0.1 * SR), 0.02, 0.03, 0.3, 0.05), 0.09))
    save("flap", flap, 0.55)
    save("feather", mix(whoosh(0.12, 1500, 8000, 0.2), whoosh(0.1, 1200, 7000, 0.2) * 0.0), 0.45)
    save("gust", mix(whoosh(0.6, 200, 2000, 0.3), 0.6 * whoosh(0.5, 400, 3000, 0.4)), 0.7, rev=0.15)
    n = int(1.6 * SR)
    tt = np.linspace(0, 1, n)
    wob = 900 + 700 * np.sin(2 * np.pi * 5 * tt)
    tor = onepole_lp(noise(n), wob) * env_adsr(n, 0.15, 0.1, 0.9, 0.4)
    save("tornado", tor, 0.6, rev=0.1)

    n = int(0.35 * SR)
    t = t_axis(0.35)
    buzz = np.sign(np.sin(2 * np.pi * (70 + 40 * rng.standard_normal(n).cumsum() / 200) * t))
    zap = mix(0.5 * buzz * env_exp(0.35, 0.08), crack(0.12, 9000), 0.4 * onepole_hp(noise(n), 3000) * env_exp(0.35, 0.05))
    save("zap", zap, 0.6, rev=0.1)
    n = int(1.8 * SR)
    rumble = onepole_lp(noise(n), 180) * env_adsr(n, 0.02, 0.2, 0.6, 1.2)
    save("thunder", mix(1.2 * crack(0.18, 3500), 0.9 * thump(80, 30, 0.6, 0.2), 1.4 * rumble), 0.95, rev=0.35, room=0.9)

    save("flash_step", mix(0.35 * metal([2600, 5200, 7800], 0.6, 0.16), whoosh(0.12, 2000, 9000, 0.15)), 0.7, rev=0.3)
    hum = sweep_sine(700, 380, 0.5) * env_adsr(int(0.5 * SR), 0.02, 0.1, 0.5, 0.3) * 0.25
    save("crescent", mix(whoosh(0.35, 500, 5000, 0.3), hum, 0.15 * shing), 0.7, rev=0.2)
    save("counter", mix(metal([1900, 3900, 5800], 0.9, 0.3), delay(whoosh(0.2, 800, 6000, 0.3), 0.05)), 0.8, rev=0.3)

    n = int(1.4 * SR)
    t = t_axis(1.4)
    rise = onepole_lp(noise(n), 200 + 5000 * (t / 1.4) ** 2) * (t / 1.4) ** 1.5
    gong = metal([98, 196.5, 262, 350, 523], 2.4, 1.1, [1, 0.6, 0.4, 0.3, 0.2])
    save("ult_start", mix(0.6 * rise, delay(mix(0.9 * gong, 0.6 * thump(70, 35, 0.8, 0.3)), 1.0)), 0.95, rev=0.3, room=0.9)
    save("ult_hit", mix(thump(90, 30, 0.7, 0.2), crack(0.15, 3000), 0.4 * metal([1200, 3100, 5300], 0.8, 0.2)), 0.95, rev=0.3)
    save("ko", mix(thump(70, 25, 1.2, 0.35), 0.8 * crack(0.25, 2500), 0.7 * metal([73, 147, 220, 294], 3.0, 1.4)), 0.95, rev=0.4, room=0.95)

    taiko = mix(thump(95, 55, 0.7, 0.18), 0.25 * onepole_lp(noise(int(0.08 * SR)), 1500) * env_exp(0.08, 0.02))
    save("round", taiko, 0.9, rev=0.35, room=0.9)
    cym = onepole_hp(noise(int(1.4 * SR)), 5000) * env_exp(1.4, 0.35)
    save("fight", mix(taiko, delay(taiko, 0.16), 0.35 * delay(cym, 0.16)), 0.95, rev=0.35, room=0.9)
    sparkle = np.zeros(int(0.8 * SR))
    for i, f in enumerate([1568, 2093, 2637, 3136, 4186]):
        p = metal([f, f * 2.01], 0.5, 0.12)
        st = int(i * 0.045 * SR)
        sparkle[st:st + len(p)] += p[: len(sparkle) - st]
    save("perfect", sparkle, 0.6, rev=0.35)
    save("throw", mix(thump(120, 60, 0.2, 0.06), delay(whoosh(0.3, 300, 2000, 0.4), 0.08)), 0.75)
    save("wall", mix(thump(80, 30, 0.5, 0.14), 0.8 * crack(0.12, 2500), 0.4 * onepole_lp(noise(8000), 500) * env_exp(8000 / SR, 0.08)), 0.9, rev=0.2)
    n = int(0.9 * SR)
    t = t_axis(0.9)
    charge = sweep_sine(180, 620, 0.9, curve=1.0) * (0.3 + 0.7 * t / 0.9) * 0.35 + 0.2 * onepole_lp(noise(n), 400 + 3000 * t / 0.9) * (t / 0.9)
    save("charge", charge * env_adsr(n, 0.05, 0.1, 1, 0.08), 0.5)

    blip = np.sin(2 * np.pi * 880 * t_axis(0.06)) * env_exp(0.06, 0.02)
    save("ui_move", blip, 0.35)
    ok = mix(np.sin(2 * np.pi * 660 * t_axis(0.09)) * env_exp(0.09, 0.04), delay(np.sin(2 * np.pi * 990 * t_axis(0.14)) * env_exp(0.14, 0.06), 0.07))
    save("ui_ok", ok, 0.4, rev=0.2)
    back = mix(np.sin(2 * np.pi * 520 * t_axis(0.08)) * env_exp(0.08, 0.03), delay(np.sin(2 * np.pi * 390 * t_axis(0.12)) * env_exp(0.12, 0.05), 0.06))
    save("ui_back", back, 0.35)


# -------------------------------------------------------------------- music
MSR = 22050


def ks_pluck(freq, dur, bright=0.6, decay=0.996, sr=MSR):
    """Karplus-Strong plucked string (koto-ish), vectorised per period."""
    n = int(dur * sr)
    N = max(2, int(sr / freq))
    buf = rng.uniform(-1, 1, N)
    buf = onepole_lp(buf, 800 + 6000 * bright, sr)
    out = np.zeros(n + N + 1)
    out[:N] = buf
    for s in range(N, n + 1, N):
        e = min(s + N, n + 1)
        prev = out[s - N:e - N]
        prev2 = out[s - N - 1:e - N - 1] if s - N - 1 >= 0 else np.concatenate([[0.0], out[s - N:e - N - 1]])
        out[s:e] = decay * 0.5 * (prev + prev2)
    y = out[:n]
    y *= np.clip(np.arange(n) / (0.002 * sr), 0, 1)
    return y


def flute(freq, dur, sr=MSR):
    n = int(dur * sr)
    t = np.arange(n) / sr
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    ph = 2 * np.pi * freq * np.cumsum(vib) / sr
    tone = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    breath = onepole_lp(rng.uniform(-1, 1, n), freq * 2.5, sr) * 0.18
    return (tone + breath) * env_adsr(n, 0.12, 0.2, 0.8, min(0.3, dur * 0.4), sr)


def drum(kind, sr=MSR):
    if kind == "taiko":
        d = 0.6
        t = np.arange(int(d * sr)) / sr
        f = 50 + 60 * np.exp(-t / 0.03)
        x = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t / 0.18)
        x += 0.2 * onepole_lp(rng.uniform(-1, 1, len(t)), 1200, sr) * np.exp(-t / 0.02)
        return x
    if kind == "shime":
        d = 0.15
        t = np.arange(int(d * sr)) / sr
        f = 300 + 120 * np.exp(-t / 0.01)
        x = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t / 0.04)
        x += 0.35 * onepole_hp(rng.uniform(-1, 1, len(t)), 2000, sr) * np.exp(-t / 0.01)
        return x * 0.6
    if kind == "click":
        d = 0.05
        t = np.arange(int(d * sr)) / sr
        return (np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.006) + 0.3 * onepole_hp(rng.uniform(-1, 1, len(t)), 3000, sr) * np.exp(-t / 0.004)) * 0.35
    if kind == "hat":
        d = 0.08
        t = np.arange(int(d * sr)) / sr
        return onepole_hp(rng.uniform(-1, 1, len(t)), 6000, sr) * np.exp(-t / 0.015) * 0.25
    raise ValueError(kind)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def build_music():
    os.makedirs(MUS_DIR, exist_ok=True)
    bpm = 128
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    n = int(total * MSR)
    pad = int(2.0 * MSR)
    koto = np.zeros(n + pad)
    bass = np.zeros(n + pad)
    drums = np.zeros(n + pad)
    lead = np.zeros(n + pad)

    def put(buf, x, t, gain=1.0):
        s = int(t * MSR)
        e = min(len(buf), s + len(x))
        buf[s:e] += x[: e - s] * gain

    # D hirajoshi-ish: D E F A Bb
    roots = [50, 46, 41, 45]  # D, Bb, F, A (bass)
    chord_tones = {50: [62, 65, 69], 46: [58, 62, 65], 41: [57, 60, 65], 45: [57, 61, 64]}
    # koto arpeggio patterns (16ths), index into chord+scale
    motif = [0, 2, 4, 2, 5, 4, 2, 1, 0, 2, 4, 5, 7, 5, 4, 2]

    for bar in range(bars):
        t0 = bar * 4 * beat
        root = roots[bar % 4]
        intense = bar >= 8
        # bass: root on 1, fifth on 3, octave pickup
        put(bass, ks_pluck(midi(root), beat * 1.8, 0.35, 0.995), t0, 0.9)
        put(bass, ks_pluck(midi(root + 7), beat * 1.2, 0.35, 0.995), t0 + 2 * beat, 0.7)
        put(bass, ks_pluck(midi(root + 12), beat * 0.8, 0.4, 0.994), t0 + 3.5 * beat, 0.5)
        # koto arpeggio
        tones = chord_tones[root] + [t + 12 for t in chord_tones[root]] + [chord_tones[root][0] + 24]
        steps = 16 if intense else 8
        for i in range(steps):
            idx = motif[(i * (16 // steps) + bar) % 16] % len(tones)
            tt = t0 + i * (4 * beat / steps)
            put(koto, ks_pluck(midi(tones[idx]), 0.9, 0.7, 0.993), tt, 0.35 if intense else 0.45)
        # drums
        pattern_taiko = [0, 1.5, 2, 3] if not intense else [0, 0.75, 1.5, 2, 2.5, 3, 3.5]
        for b in pattern_taiko:
            put(drums, drum("taiko"), t0 + b * beat, 0.9)
        for i in range(8):
            put(drums, drum("click" if i % 2 else "shime"), t0 + i * beat / 2, 0.5 if i % 2 else 0.6)
        if intense:
            for i in range(16):
                put(drums, drum("hat"), t0 + i * beat / 4, 0.6 if i % 2 else 0.9)
        if bar % 4 == 3:
            for i in range(4):
                put(drums, drum("shime"), t0 + 3 * beat + i * beat / 4, 0.8)

    # lead melody: long shakuhachi-like tones over bars 4-7 and 12-15
    phr1 = [(74, 1.5), (76, 0.5), (77, 2), (76, 1), (74, 1), (69, 4), (70, 1.5), (69, 0.5), (65, 2), (64, 2), (62, 4)]
    phr2 = [(81, 1.5), (82, 0.5), (81, 2), (77, 1), (76, 1), (74, 4), (77, 1.5), (76, 0.5), (74, 2), (70, 2), (69, 4)]
    for start_bar, phr in ((4, phr1), (12, phr2)):
        tt = start_bar * 4 * beat
        for (m, ln) in phr:
            put(lead, flute(midi(m), ln * beat * 0.98), tt, 0.32)
            tt += ln * beat

    mixd = koto * 0.8 + bass * 0.7 + drums * 0.9 + lead * 0.9
    mixd = reverb(mixd, 0.22, 0.85, MSR, tail=0.0)
    # wrap tail around for a seamless loop
    body = mixd[:n].copy()
    tail = mixd[n:]
    body[: len(tail)] += tail[: len(body)]
    body = normalize(body, 0.8)
    write_wav(os.path.join(MUS_DIR, "battle_theme.wav"), body, MSR)


if __name__ == "__main__":
    build_sfx()
    build_music()
    print("audio generated")
