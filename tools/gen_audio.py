#!/usr/bin/env python3
"""Synthesises every sound in Dead Signal into audio/ (no recorded samples, no deps).

    python3 tools/gen_audio.py            # everything
    python3 tools/gen_audio.py sfx        # just the effects (fast)
    python3 tools/gen_audio.py music      # just the two music loops (~1 min)

Deterministic: same files every run. 22.05 kHz mono 16-bit WAV, which suits the
lo-fi 90s MIDI-rack sound the requirements ask for.

Music  audio/music/level.wav   100 BPM E-phrygian industrial loop (heartbeat intro,
                               chugging distorted 'MIDI guitar', clanking metal snare)
       audio/music/boss.wav    138 BPM relentless loop for the WARDEN fight
SFX    audio/sfx/<name>_<n>.wav  (n = variant, picked at random in game)
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
TAU = math.tau
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')


# ------------------------------------------------------------------ helpers ---

def zeros(sec):
    return [0.0] * int(sec * SR)


def write(path, x, peak=0.89):
    m = max(1e-6, max(abs(v) for v in x))
    g = peak / m
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v * g)) * 32767)) for v in x))


def lp(x, fc):
    a = 1.0 - math.exp(-TAU * fc / SR)
    s = 0.0
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        s += a * (v - s)
        out[i] = s
    return out


def hp(x, fc):
    lo = lp(x, fc)
    return [v - l for v, l in zip(x, lo)]


def svf_bp(x, fc_fn, q=0.5):
    """Chamberlin state-variable band-pass with a per-sample cutoff function of u (0..1)."""
    n = len(x)
    lo = bp = 0.0
    out = [0.0] * n
    for i, v in enumerate(x):
        f = 2.0 * math.sin(math.pi * min(fc_fn(i / n), SR * 0.16) / SR)
        lo += f * bp
        hi = v - lo - q * bp
        bp += f * hi
        out[i] = bp
    return out


def mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = [0.0] * n
    for p, g in parts:
        for i, v in enumerate(p):
            out[i] += v * g
    return out


def drive(x, k):
    return [math.tanh(v * k) for v in x]


def crush(x, bits):
    q = float(2 ** (bits - 1))
    return [round(v * q) / q for v in x]


def noise(rng, n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def env_ar(n, attack, release):
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    return [min(1.0, i / a, (n - i) / r) for i in range(n)]


# ---------------------------------------------------------------- sfx bits ---

def thump(sec, f_hi, f_lo, rate, decay):
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += (f_lo + (f_hi - f_lo) * math.exp(-t * rate)) / SR
        out[i] = math.sin(TAU * ph) * math.exp(-t * decay)
    return out


def decay_noise(rng, sec, rate, attack=0.0):
    n = int(sec * SR)
    a = max(1, int(attack * SR))
    return [rng.uniform(-1, 1) * math.exp(-(i / SR) * rate) * min(1.0, i / a) for i in range(n)]


def metal(sec, f0, ratios, rate, rng=None):
    n = int(sec * SR)
    out = [0.0] * n
    for k, r in enumerate(ratios):
        f = f0 * r
        d = rate * (1.0 + k * 0.45)
        amp = 1.0 / (1.0 + k * 0.6)
        for i in range(n):
            t = i / SR
            out[i] += math.sin(TAU * f * t) * math.exp(-t * d) * amp
    if rng:
        click = decay_noise(rng, 0.01, 400)
        for i, v in enumerate(click):
            out[i] += v * 0.6
    return out


def gunshot(rng, sec, crack_rate, body_rate, thump_rate, low):
    crack = hp(decay_noise(rng, sec, crack_rate), 1800)
    body = lp(decay_noise(rng, sec, body_rate), 1100 * low)
    th = thump(sec, 170 * low, 45 * low, 40, thump_rate)
    room = lp(decay_noise(rng, sec, 7.0, 0.01), 700)
    return drive(mix((crack, 0.9), (body, 1.1), (th, 1.3), (room, 0.25)), 2.2)


def zap(sec, f_hi, f_lo, rate, buzz, decay):
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = f_lo + (f_hi - f_lo) * math.exp(-t * rate)
        ph += f / SR
        m = math.sin(TAU * ph * 2.01) * 2.5
        s = math.sin(TAU * ph + m)
        sq = 1.0 if math.sin(TAU * ph) > 0 else -1.0
        out[i] = (s * (1 - buzz) + sq * buzz) * math.exp(-t * decay) * min(1.0, t / 0.003)
    return out


def whoosh(rng, sec, f_lo, f_hi, q=0.6):
    n = int(sec * SR)
    src = noise(rng, n)
    band = svf_bp(src, lambda u: f_lo + (f_hi - f_lo) * math.sin(math.pi * u) ** 2, q)
    return [v * math.sin(math.pi * i / n) ** 1.5 for i, v in enumerate(band)]


def explosion(rng, sec=1.6, low=1.0):
    n = int(sec * SR)
    out = [0.0] * n
    s1 = s2 = 0.0
    for i in range(n):
        t = i / SR
        fc = 150 + 3800 * math.exp(-t * 3.2)
        a = 1.0 - math.exp(-TAU * fc * low / SR)
        s1 += a * (rng.uniform(-1, 1) - s1)
        s2 += a * (s1 - s2)
        out[i] = s2 * 2.2 * min(1.0, t / 0.004) * math.exp(-t * 2.6)
    sub = thump(sec, 90 * low, 32 * low, 6, 3.5)
    crackle = [0.0] * n
    for _ in range(90):
        p = int(rng.uniform(0.02, 0.8) ** 1.5 * SR)
        a = rng.uniform(0.2, 0.7) * math.exp(-p / SR * 3)
        for j in range(min(60, n - p)):
            crackle[p + j] += rng.uniform(-a, a) * math.exp(-j / 12)
    return drive(mix((out, 1.0), (sub, 1.4), (hp(crackle, 1500), 0.6)), 1.8)


def voice(rng, sec, f0_fn, formants, rough=0.3, breath=0.2, env=None, gurgle=0.0):
    """Glottal pulse train through three moving formant filters (zombie / human sounds).
    f0_fn(u) -> Hz; formants: list of three functions u -> (freq, gain)."""
    n = int(sec * SR)
    src = [0.0] * n
    ph = 0.0
    cyc = 0
    wob = 0.0
    for i in range(n):
        u = i / n
        t = i / SR
        wob += (rng.uniform(-1, 1) * 0.02 - wob * 0.002)
        f = f0_fn(u) * (1.0 + wob * 0.6 + 0.012 * math.sin(TAU * 5.3 * t))
        ph += f / SR
        if ph >= 1.0:
            ph -= 1.0
            cyc += 1
        r = rough(u) if callable(rough) else rough
        amp = 1.0 - r * 0.7 * (cyc % 2) - r * 0.3 * (cyc % 3 == 0)
        pulse = (1.0 - 2.0 * ph) * amp
        b = breath(u) if callable(breath) else breath
        src[i] = pulse + rng.uniform(-1, 1) * b
        if gurgle:
            src[i] *= 1.0 - gurgle * u * (0.5 + 0.5 * math.sin(TAU * (8 + 4 * math.sin(t * 3)) * t))
    out = [0.0] * n
    for fn in formants:
        band = svf_bp(src, lambda u, fn=fn: fn(u)[0], 0.18)
        for i in range(n):
            out[i] += band[i] * fn(i / n)[1]
    e = env or env_ar(n, 0.05, 0.2)
    return [v * e[i] for i, v in enumerate(out)]


def lerp_fn(*pts):
    """Piecewise-linear function of u from (u, value) points."""
    def f(u):
        for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
            if u <= u1:
                k = (u - u0) / max(1e-9, u1 - u0)
                return v0 + (v1 - v0) * k
        return pts[-1][1]
    return f


def formant(fp, gp=1.0):
    g = gp if callable(gp) else (lambda u: gp)
    return lambda u: (fp(u), g(u))


def beeps(rng, notes, wave_mix=0.5, bits=6):
    """notes: list of (start_s, dur_s, f_start, f_end, amp)."""
    end = max(s + d for s, d, *_ in notes) + 0.05
    out = zeros(end)
    for s, d, f0, f1, a in notes:
        ph = 0.0
        i0 = int(s * SR)
        n = int(d * SR)
        for i in range(n):
            u = i / n
            ph += (f0 + (f1 - f0) * u) / SR
            sn = math.sin(TAU * ph)
            sq = 1.0 if sn > 0 else -1.0
            e = min(1.0, i / 60, (n - i) / 200)
            out[i0 + i] += (sn * (1 - wave_mix) + sq * wave_mix) * e * a
    return crush(lp(out, 5000), bits)


def make_sfx():
    out = {}
    R = random.Random

    out['rifle'] = [gunshot(R(1), 0.32, 90, 30, 22, 1.0), gunshot(R(2), 0.32, 80, 28, 22, 0.95)]
    out['shotgun'] = [gunshot(R(3), 0.75, 60, 11, 9, 0.75)]
    out['heavy_shot'] = [mix((gunshot(R(4), 0.3, 70, 26, 20, 0.8), 1.0), (zap(0.18, 900, 250, 25, 0.6, 18), 0.35))]
    out['laser'] = [mix((zap(0.3, 2000, 300, 18, 0.15, 10), 1.0), (zap(0.25, 220, 90, 10, 0.8, 14), 0.25)),
                    mix((zap(0.3, 2200, 320, 17, 0.15, 10), 1.0), (zap(0.25, 230, 95, 10, 0.8, 14), 0.25))]
    out['enemy_bolt'] = [zap(0.22, 3000, 600, 25, 0.55, 14)]
    out['grenade_launch'] = [mix((thump(0.3, 140, 55, 14, 14), 1.0), (lp(decay_noise(R(5), 0.3, 30), 600), 0.6))]
    out['explosion'] = [explosion(R(6)), explosion(R(7), 1.6, 0.85)]

    out['swing'] = [whoosh(R(8), 0.3, 350, 1700), whoosh(R(9), 0.28, 400, 1900)]
    hum = [math.copysign(1, math.sin(TAU * 70 * i / SR)) * 0.5 + math.sin(TAU * 140 * i / SR) * 0.5 for i in range(int(0.45 * SR))]
    crackle = [v if rng_v > 0.93 else 0.0 for v, rng_v in zip(noise(R(10), len(hum)), noise(R(11), len(hum)))]
    w = whoosh(R(12), 0.45, 200, 1000, 0.5)
    out['swing_heavy'] = [mix((w, 1.0), ([h * math.sin(math.pi * i / len(hum)) for i, h in enumerate(lp(hum, 900))], 0.25), (hp(crackle, 2000), 0.5))]
    n = int(0.5 * SR)
    saw = []
    ph = 0.0
    for i in range(n):
        u = i / n
        t = i / SR
        f = 65 + 55 * math.sin(min(1.0, u * 3) * math.pi / 2)
        ph = (ph + f / SR) % 1.0
        teeth = 0.6 + 0.4 * (1 if math.sin(TAU * 31 * t) > 0 else -1)
        saw.append((2 * ph - 1) * teeth)
    out['chainblade'] = [[v * e for v, e in zip(lp(drive(mix((saw, 1.0), (hp(noise(R(13), n), 1500), 0.3)), 4.0), 3000), env_ar(n, 0.02, 0.12))]]
    out['melee_hit'] = [drive(mix((thump(0.3, 95, 40, 20, 18), 1.2), (lp(decay_noise(R(14), 0.3, 25), 800), 1.0),
                                  (hp(decay_noise(R(15), 0.08, 50), 2500), 0.5)), 2.0)]
    out['impact_flesh'] = [mix((lp(decay_noise(R(16), 0.14, 45), 1500), 1.0), (thump(0.14, 150, 90, 30, 40), 0.5)),
                           mix((lp(decay_noise(R(17), 0.14, 40), 1300), 1.0), (thump(0.14, 140, 80, 30, 40), 0.5))]
    out['impact_metal'] = [metal(0.35, 1300, [1, 1.47, 2.09, 2.56, 3.1], 14, R(18)),
                           metal(0.35, 1650, [1, 1.52, 2.17, 2.7, 3.3], 15, R(19))]

    # ---- biological: mutated researchers -----------------------------------
    uh = [formant(lerp_fn((0, 520), (0.5, 420), (1, 650)), 1.0),
          formant(lerp_fn((0, 1000), (0.5, 820), (1, 1100)), 0.6),
          formant(lambda u: 2450, 0.25)]
    groans = []
    for k, (f_a, f_b, sec) in enumerate([(98, 78, 1.6), (88, 70, 1.9), (110, 84, 1.4)]):
        rr = R(20 + k)
        fn = lerp_fn((0, f_a * 0.9), (0.25, f_a), (0.6, f_a * 0.95), (1, f_b))
        n = int(sec * SR)
        groans.append(voice(rr, sec, fn, uh, rough=0.55, breath=0.3, env=env_ar(n, 0.18, 0.5)))
    out['zombie_groan'] = groans
    aa = [formant(lambda u: 760, 1.0), formant(lambda u: 1250, 0.7), formant(lambda u: 2600, 0.3)]
    out['zombie_snarl'] = [voice(R(30), 0.6, lerp_fn((0, 170), (0.3, 190), (1, 120)), aa, rough=0.85, breath=0.65,
                                 env=env_ar(int(0.6 * SR), 0.02, 0.25)),
                           voice(R(31), 0.55, lerp_fn((0, 150), (0.3, 175), (1, 110)), aa, rough=0.9, breath=0.7,
                                 env=env_ar(int(0.55 * SR), 0.02, 0.25))]
    out['zombie_hurt'] = [voice(R(32), 0.32, lerp_fn((0, 150), (1, 105)), uh, rough=0.6, breath=0.35, env=env_ar(int(0.32 * SR), 0.01, 0.15)),
                          voice(R(33), 0.3, lerp_fn((0, 165), (1, 115)), aa, rough=0.6, breath=0.35, env=env_ar(int(0.3 * SR), 0.01, 0.15))]
    oo = [formant(lerp_fn((0, 700), (0.6, 450), (1, 320)), 1.0), formant(lerp_fn((0, 1150), (1, 700)), 0.6), formant(lambda u: 2400, 0.2)]
    out['zombie_death'] = [voice(R(34), 1.7, lerp_fn((0, 140), (0.2, 125), (1, 52)), oo, rough=lerp_fn((0, 0.4), (1, 1.0)),
                                 breath=lerp_fn((0, 0.3), (1, 0.6)), env=env_ar(int(1.7 * SR), 0.02, 0.6), gurgle=0.9)]

    # ---- the marine ---------------------------------------------------------
    grunt = [formant(lambda u: 600, 1.0), formant(lambda u: 1080, 0.55), formant(lambda u: 2500, 0.2)]
    out['player_hurt'] = [voice(R(40), 0.28, lerp_fn((0, 125), (1, 96)), grunt, rough=0.25, breath=0.35, env=env_ar(int(0.28 * SR), 0.01, 0.12)),
                          voice(R(41), 0.26, lerp_fn((0, 118), (1, 92)), grunt, rough=0.3, breath=0.3, env=env_ar(int(0.26 * SR), 0.01, 0.12))]
    out['player_death'] = [voice(R(42), 1.2, lerp_fn((0, 135), (0.3, 120), (1, 68)), aa, rough=lerp_fn((0, 0.2), (1, 0.8)),
                                 breath=0.4, env=env_ar(int(1.2 * SR), 0.02, 0.7))]

    # ---- robotic: servo-skulls, security heavies, the WARDEN ---------------
    chats = []
    for k in range(4):
        rr = R(50 + k)
        t = 0.0
        notes = []
        for j in range(rr.randint(4, 7)):
            d = rr.uniform(0.04, 0.09)
            f0 = rr.choice([660, 880, 990, 1180, 1320, 1580, 1760, 2100])
            f1 = f0 * rr.choice([1, 1, 1, 0.7, 1.4])
            notes.append((t, d, f0, f1, rr.uniform(0.6, 1.0)))
            t += d + rr.uniform(0.01, 0.04)
        chats.append(beeps(rr, notes))
    out['robot_chatter'] = chats
    out['robot_alert'] = [beeps(R(60), [(0, 0.07, 900, 900, 1), (0.08, 0.07, 1350, 1350, 1), (0.16, 0.14, 1800, 2200, 1)], 0.7)]
    rr = R(61)
    notes = []
    t = 0.0
    while t < 0.2:
        notes.append((t, 0.016, rr.uniform(200, 1300), rr.uniform(200, 1300), 1.0))
        t += 0.017
    out['robot_hurt'] = [mix((beeps(rr, notes, 0.9, 4), 0.8), (hp(decay_noise(rr, 0.22, 25), 1200), 0.4))]
    n = int(1.0 * SR)
    pd = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 40 + 900 * math.exp(-t * 3.5)
        ph += f * (1 + 0.15 * t * math.sin(TAU * 13 * t)) / SR
        stut = 1.0 if t < 0.6 or math.sin(TAU * 18 * t) > 0 else 0.2
        pd.append((1 if math.sin(TAU * ph) > 0 else -1) * math.exp(-t * 2.0) * stut)
    sparks = [0.0] * n
    rr = R(62)
    for _ in range(40):
        p = int(rr.uniform(0, 0.8) * SR)
        for j in range(min(40, n - p)):
            sparks[p + j] += rr.uniform(-1, 1) * math.exp(-j / 8)
    out['robot_death'] = [mix((crush(lp(pd, 3500), 5), 0.6), (hp(sparks, 2500), 0.5), (lp(decay_noise(rr, 0.4, 20), 900), 0.8))]

    n = int(1.6 * SR)
    kl = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 520 if int(t / 0.4) % 2 == 0 else 390
        ph = (ph + f / SR) % 1.0
        kl.append((2 * ph - 1) * (0.75 + 0.25 * math.sin(TAU * 7 * t)))
    out['boss_alarm'] = [[v * e for v, e in zip(drive(lp(kl, 2200), 2.5), env_ar(n, 0.02, 0.15))]]
    n = int(1.1 * SR)
    ch = []
    ph = 0.0
    for i in range(n):
        u = i / n
        ph += (180 + 1500 * u ** 2.2) / SR
        trem = 0.7 + 0.3 * math.sin(TAU * (4 + 30 * u) * i / SR)
        ch.append((math.sin(TAU * ph) * 0.6 + (2 * (ph % 1) - 1) * 0.4) * trem * (0.2 + 0.8 * u))
    out['boss_charge'] = [lp(ch, 4000)]
    n = int(1.8 * SR)
    lz = []
    rr = R(63)
    for i in range(n):
        t = i / SR
        b = (2 * ((75 * t) % 1) - 1) * 0.6 + (2 * ((151 * t) % 1) - 1) * 0.4
        am = 0.75 + 0.25 * math.sin(TAU * 30 * t)
        lz.append(b * am + math.sin(TAU * 2400 * t + 2 * math.sin(TAU * 7 * t)) * 0.15 + rr.uniform(-0.2, 0.2))
    out['boss_laser'] = [[v * e for v, e in zip(drive(lp(lz, 2500), 1.8), env_ar(n, 0.04, 0.2))]]
    out['boss_shot'] = [mix((zap(0.12, 1000, 480, 30, 0.3, 25), 1.0))]

    # ---- abilities, gear and the facility ----------------------------------
    pul = whoosh(R(70), 0.7, 3000, 200, 0.4)
    out['pulse'] = [drive(mix((thump(0.7, 200, 45, 8, 5), 1.3), (pul, 0.9), (hp(crackle[:int(0.7 * SR)] if len(crackle) >= int(0.7 * SR) else crackle, 2000), 0.4)), 1.6)]
    n = int(0.9 * SR)
    oc = []
    ph = 0.0
    for i in range(n):
        u = i / n
        ph += (150 + 800 * u ** 1.6) / SR
        oc.append((2 * (ph % 1) - 1) * (0.2 + 0.8 * u) * min(1.0, (n - i) / 300))
    ping = [0.0] * int(0.75 * SR) + metal(0.5, 1760, [1, 2.0, 3.01], 6)
    out['overcharge'] = [mix((drive(lp(oc, 2500), 2.0), 0.8), (ping, 0.4))]
    out['stim'] = [mix((hp([v * min(1.0, i / 200) * math.exp(-i / SR * 6) for i, v in enumerate(noise(R(71), int(0.45 * SR)))], 3000), 0.8),
                       (metal(0.08, 2600, [1, 1.6], 60, R(72)), 0.5))]
    out['dodge'] = [mix((whoosh(R(73), 0.24, 250, 1100, 0.7), 1.0), ([0.0] * int(0.05 * SR) + metal(0.12, 900, [1, 1.7, 2.6], 35, R(74)), 0.15))]
    rel = zeros(0.55)
    for at, m in [(0.0, metal(0.1, 1900, [1, 1.9], 50, R(75))), (0.14, lp(decay_noise(R(76), 0.12, 25, 0.02), 1800)),
                  (0.34, mix((metal(0.15, 1200, [1, 1.5, 2.3], 35, R(77)), 1.0), (thump(0.15, 160, 80, 30, 30), 0.6)))]:
        for i, v in enumerate(m):
            if int(at * SR) + i < len(rel):
                rel[int(at * SR) + i] += v
    out['reload'] = [rel]
    pk = zeros(0.3)
    for at, f in [(0.0, 2100), (0.07, 2800)]:
        for i, v in enumerate(metal(0.22, f, [1, 1.5, 2.2], 22)):
            if int(at * SR) + i < len(pk):
                pk[int(at * SR) + i] += v
    out['pickup'] = [pk]
    n = int(1.0 * SR)
    hiss = hp(noise(R(78), n), 2500)
    hiss = [v * min(1.0, i / 400) * math.exp(-i / SR * 3.0) for i, v in enumerate(hiss)]
    srv = [math.sin(TAU * (300 + 200 * i / n) * i / SR) * 0.3 * math.sin(math.pi * min(1.0, i / (0.75 * n))) for i in range(n)]
    clunk = [0.0] * int(0.75 * SR) + mix((thump(0.25, 110, 50, 20, 18), 1.2), (metal(0.25, 420, [1, 1.9, 2.7], 20, R(79)), 0.4))
    out['door'] = [mix((hiss, 0.7), (srv, 0.5), (clunk, 1.0))]
    n = int(0.6 * SR)
    creak = []
    ph = 0.0
    for i in range(n):
        u = i / n
        ph = (ph + (85 + 30 * math.sin(TAU * 3 * u)) / SR) % 1.0
        creak.append((2 * ph - 1) * math.sin(math.pi * u))
    out['crate'] = [mix((metal(0.2, 700, [1, 1.8, 2.9], 30, R(80)), 0.6), (thump(0.2, 120, 60, 25, 25), 0.8), ([0.0] * int(0.1 * SR) + lp(creak, 900), 0.35))]
    out['terminal'] = [beeps(R(81), [(0, 0.06, 1200, 1200, 1), (0.09, 0.09, 1600, 1600, 1)], 0.6, 7)]
    n = int(1.5 * SR)
    bell = [0.0] * n
    for f, at in [(329.63, 0.0), (493.88, 0.08), (783.99, 0.16)]:
        i0 = int(at * SR)
        for i in range(n - i0):
            t = i / SR
            mod = math.sin(TAU * f * 1.4 * t) * 2.0 * math.exp(-t * 3)
            bell[i0 + i] += math.sin(TAU * f * t + mod) * math.exp(-t * 2.2) * min(1.0, t / 0.005)
    out['levelup'] = [bell]
    return out


# ------------------------------------------------------------------- music ---

def note(name):
    names = {'C': -9, 'C#': -8, 'Db': -8, 'D': -7, 'D#': -6, 'Eb': -6, 'E': -5, 'F': -4, 'F#': -3, 'Gb': -3,
             'G': -2, 'G#': -1, 'Ab': -1, 'A': 0, 'A#': 1, 'Bb': 1, 'B': 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + (octave - 4) * 12) / 12)


class Track:
    def __init__(self, bpm, bars, seed):
        self.s16 = 60.0 / bpm / 4
        self.bar = self.s16 * 16
        self.length = self.bar * bars
        self.n = int(self.length * SR)
        self.dry = [0.0] * (self.n + 3 * SR)
        self.wet = [0.0] * (self.n + 3 * SR)
        self.rng = random.Random(seed)

    def at(self, bar, step):
        return int((bar * 16 + step) * self.s16 * SR)

    def put(self, i0, samples, gain=1.0, send=0.0):
        d, w = self.dry, self.wet
        for i, v in enumerate(samples):
            j = i0 + i
            if j >= len(d):
                break
            d[j] += v * gain
            if send:
                w[j] += v * gain * send

    # ---- instruments ----
    def kick(self, i0, amp=1.0):
        n = int(0.32 * SR)
        out = [0.0] * n
        ph = 0.0
        rng = self.rng
        for i in range(n):
            t = i / SR
            ph += (45 + 115 * math.exp(-t * 30)) / SR
            out[i] = math.tanh(2.2 * (math.sin(TAU * ph) * math.exp(-t * 8) + rng.uniform(-1, 1) * math.exp(-t * 400) * 0.3))
        self.put(i0, out, amp)

    def snare(self, i0, amp=1.0, send=0.35):
        n = int(0.32 * SR)
        rng = self.rng
        out = [0.0] * n
        s = 0.0
        for i in range(n):
            t = i / SR
            nz = rng.uniform(-1, 1)
            s += 0.2 * (nz - s)
            gate = 1.0 if t < 0.24 else max(0.0, 1 - (t - 0.24) / 0.05)
            clang = (math.sin(TAU * 540 * t) + math.sin(TAU * 863 * t) * 0.8 + math.sin(TAU * 1311 * t) * 0.6) * math.exp(-t * 16)
            out[i] = (math.sin(TAU * 185 * t) * math.exp(-t * 25) * 0.6 + (nz - s) * math.exp(-t * 9) * 0.9 + clang * 0.22) * gate
        self.put(i0, [math.tanh(1.6 * v) for v in out], amp, send)

    def hat(self, i0, amp=0.3, open_=False):
        n = int((0.25 if open_ else 0.05) * SR)
        rng = self.rng
        rate = 13 if open_ else 75
        out = [0.0] * n
        s = 0.0
        for i in range(n):
            nz = rng.uniform(-1, 1)
            s += 0.55 * (nz - s)
            out[i] = (nz - s) * math.exp(-i / SR * rate)
        self.put(i0, out, amp)

    def clank(self, i0, amp=0.5, f=220.0, send=0.5):
        self.put(i0, metal(0.6, f, [1, 2.31, 3.89, 5.43, 7.1], 7, self.rng), amp * 0.5, send)

    def bass(self, i0, dur, f, amp=0.5, bright=0.4):
        n = int(dur * SR)
        out = [0.0] * n
        p1 = p2 = 0.0
        s1 = s2 = 0.0
        rel = min(n, int(0.015 * SR))
        for i in range(n):
            t = i / SR
            p1 = (p1 + f / SR) % 1.0
            p2 = (p2 + f * 1.007 / SR) % 1.0
            x = (2 * p1 - 1) + (2 * p2 - 1)
            fc = 180 + bright * 1600 * math.exp(-t * 12)
            a = min(1.0, TAU * fc / SR)
            s1 += a * (x - s1)
            s2 += a * (s1 - s2)
            e = min(1.0, i / 60, (n - i) / rel)
            out[i] = math.tanh(2.5 * s2) * e
        self.put(i0, out, amp)

    def guitar(self, i0, dur, f, amp=0.4, mute=True):
        n = int(dur * SR)
        out = [0.0] * n
        ps = [0.0, 0.0, 0.0, 0.0]
        fs = [f, f * 1.004, f * 1.5, f * 2.0]
        s1 = s2 = 0.0
        a = min(1.0, TAU * (750 if mute else 2300) / SR)
        rel = min(n, int(0.02 * SR))
        for i in range(n):
            t = i / SR
            x = 0.0
            for k in range(4):
                ps[k] = (ps[k] + fs[k] / SR) % 1.0
                x += 2 * ps[k] - 1
            y = math.tanh(x * 3.0)
            s1 += a * (y - s1)
            s2 += a * (s1 - s2)
            e = (math.exp(-t * 14) if mute else math.exp(-t * 0.9)) * min(1.0, i / 40, (n - i) / rel)
            out[i] = s2 * e
        self.put(i0, out, amp, 0.08)

    def pad(self, i0, dur, freqs, amp=0.18):
        n = int(dur * SR)
        out = [0.0] * n
        osc = []
        for f in freqs:
            osc += [f * 0.996, f * 1.004]
        ph = [0.0] * len(osc)
        s1 = 0.0
        a = TAU * 850 / SR
        att = int(0.9 * SR)
        rel = int(0.9 * SR)
        for i in range(n):
            x = 0.0
            for k, f in enumerate(osc):
                ph[k] = (ph[k] + f / SR) % 1.0
                x += 2 * ph[k] - 1
            s1 += a * (x - s1)
            out[i] = s1 * min(1.0, i / att, (n - i) / rel) * (0.85 + 0.15 * math.sin(TAU * 0.3 * i / SR))
        self.put(i0, out, amp / len(osc) * 2, 0.4)

    def lead(self, i0, dur, f, amp=0.25, res=0.22, sq=False):
        n = int(dur * SR)
        out = [0.0] * n
        ph = 0.0
        lo = bp = 0.0
        for i in range(n):
            t = i / SR
            vib = 1.0 + (0.006 * math.sin(TAU * 5.5 * t) if t > 0.2 else 0.0)
            ph = (ph + f * vib / SR) % 1.0
            x = (1.0 if ph < 0.5 else -1.0) if sq else 2 * ph - 1
            fc = 280 + 2600 * math.exp(-t * 5)
            ff = 2.0 * math.sin(math.pi * min(fc, 3000) / SR)
            lo += ff * bp
            hi = x - lo - res * bp
            bp += ff * hi
            e = min(1.0, i / 100, (n - i) / 400)
            out[i] = math.tanh(1.5 * lo) * e
        self.put(i0, out, amp, 0.45)

    def beep(self, i0, f, amp=0.15):
        n = int(0.09 * SR)
        self.put(i0, [math.sin(TAU * f * i / SR) * min(1.0, i / 50, (n - i) / 300) for i in range(n)], amp, 0.6)

    def riser(self, i0, dur, amp=0.25):
        n = int(dur * SR)
        src = noise(self.rng, n)
        band = svf_bp(src, lambda u: 300 + 4500 * u ** 2, 0.5)
        self.put(i0, [v * (i / n) ** 2 for i, v in enumerate(band)], amp, 0.3)

    # ---- finish ----
    def render(self):
        wet = reverb(self.wet)
        full = [d + w * 0.32 for d, w in zip(self.dry, wet)]
        n = self.n
        out = full[:n]
        for i in range(n, len(full)):   # fold the tail onto the start: seamless loop
            out[i - n] += full[i]
        out = [math.tanh(1.3 * v) for v in out]
        return out


def reverb(x):
    combs = [1116, 1188, 1277, 1356, 1422]
    combs = [int(c * SR / 44100) for c in combs]
    out = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        damp = 0.0
        for i, v in enumerate(x):
            y = buf[idx]
            damp = y * 0.6 + damp * 0.4
            buf[idx] = v + damp * 0.8
            idx = (idx + 1) % d
            out[i] += y
    for d in (int(556 * SR / 44100), int(441 * SR / 44100)):
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(out):
            b = buf[idx]
            y = -v + b
            buf[idx] = v + b * 0.5
            idx = (idx + 1) % d
            out[i] = y
    return [v * 0.2 for v in out]


TRIADS = {'E': ('E3', 'G3', 'B3'), 'F': ('F3', 'A3', 'C4'), 'G': ('G3', 'B3', 'D4'), 'Bb': ('Bb2', 'D3', 'F3'),
          'C': ('C3', 'E3', 'G3'), 'D': ('D3', 'F3', 'A3')}


def level_track():
    """100 BPM. A: heartbeat + monitor beep. B: full band. C: lead melody. D: halftime + tritone."""
    tr = Track(100, 16, 1)
    roots = ['E', 'E', 'F', 'E',  'E', 'E', 'G', 'F',  'E', 'F', 'G', 'F',  'E', 'Bb', 'E', 'F']
    s = tr.s16
    for b, r in enumerate(roots):
        sec = b // 4
        bass_f = note(r + '1') if r != 'Bb' else note('Bb0')
        gtr_f = note(r + '2') if r != 'Bb' else note('Bb1')
        tr.pad(tr.at(b, 0), tr.bar + 0.6, [note(x) for x in TRIADS[r]], 0.22 if sec == 0 else 0.13)
        if sec == 0:
            tr.kick(tr.at(b, 0), 0.9)
            tr.kick(tr.at(b, 3), 0.6)
            tr.beep(tr.at(b, 0), note('E6'), 0.12 if b < 3 else 0.0)
            if b % 2 == 1:
                tr.clank(tr.at(b, 8), 0.5, 180)
            for st in (4, 12):
                tr.hat(tr.at(b, st), 0.15)
            for st in range(0, 16, 2):
                tr.bass(tr.at(b, st), s * 1.3, bass_f, 0.35, 0.15)
            if b == 3:
                tr.riser(tr.at(b, 0), tr.bar, 0.25)
        elif sec in (1, 2):
            for st in (0, 3, 6, 10, 11):
                tr.kick(tr.at(b, st), 1.0)
            for st in (4, 12):
                tr.snare(tr.at(b, st), 0.8)
            for st in range(0, 16, 2):
                tr.hat(tr.at(b, st), 0.22 if st % 4 else 0.3)
            tr.hat(tr.at(b, 14), 0.2, True)
            tr.clank(tr.at(b, 7), 0.35, 240)
            for st in range(16):
                if st % 4 in (0, 2, 3):
                    tr.bass(tr.at(b, st), s * 0.9, bass_f, 0.45, 0.5)
            if sec == 1:
                for st in (0, 3, 6, 10, 11):
                    tr.guitar(tr.at(b, st), s * 1.2, gtr_f, 0.5, True)
                tr.guitar(tr.at(b, 14), s * 2, gtr_f * (1.5 if b % 2 else 1.0), 0.35, False)
            else:
                tr.guitar(tr.at(b, 0), s * 7, gtr_f, 0.38, False)
                for st in (8, 10, 11, 14):
                    tr.guitar(tr.at(b, st), s * 1.2, gtr_f, 0.5, True)
        else:
            tr.kick(tr.at(b, 0), 1.0)
            tr.kick(tr.at(b, 7), 0.8)
            tr.kick(tr.at(b, 10), 0.9)
            tr.snare(tr.at(b, 8), 1.0, 0.6)
            for st in range(16):
                tr.hat(tr.at(b, st), 0.12 + 0.06 * (st % 2 == 0))
            for st in (0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14):
                tr.guitar(tr.at(b, st), s * 1.0, gtr_f, 0.45, True)
                tr.bass(tr.at(b, st), s * 0.9, bass_f, 0.4, 0.45)
            tr.clank(tr.at(b, 0), 0.5, 150)
            if b == 15:
                tr.riser(tr.at(b, 0), tr.bar, 0.3)
                for k, st in enumerate((12, 13, 14, 15)):
                    tr.snare(tr.at(b, st), 0.4 + 0.15 * k, 0.4)
    # lead melody over section C (bars 8..11), phrygian: the flat second does the work
    melody = [[('E4', 0, 6), ('F4', 6, 2), ('G4', 8, 6), ('F4', 14, 2)],
              [('E4', 0, 12), ('D4', 12, 4)],
              [('E4', 0, 6), ('F4', 6, 2), ('Bb4', 8, 6), ('A4', 14, 2)],
              [('G4', 0, 8), ('F4', 8, 8)]]
    for k, bar in enumerate(melody):
        for nm, st, ln in bar:
            tr.lead(tr.at(8 + k, st), s * ln, note(nm), 0.3)
    return tr.render()


def boss_track():
    """138 BPM, four-on-the-floor, 16th-note chugs, tritone shifts and a siren lead."""
    tr = Track(138, 16, 2)
    roots = ['E', 'E', 'F', 'E', 'E', 'E', 'Bb', 'F', 'C', 'C', 'D', 'D', 'E', 'F', 'E', 'Bb']
    s = tr.s16
    for b, r in enumerate(roots):
        bass_f = note(r + '1') if r != 'Bb' else note('Bb0')
        gtr_f = note(r + '2') if r != 'Bb' else note('Bb1')
        if b % 4 == 0:
            tr.pad(tr.at(b, 0), tr.bar * 4 + 0.5, [note('E3'), note('G3'), note('Bb3')], 0.12)
        for st in (0, 4, 8, 12):
            tr.kick(tr.at(b, st), 1.0)
        tr.kick(tr.at(b, 14), 0.7)
        for st in (4, 12):
            tr.snare(tr.at(b, st), 0.85)
        for st in range(16):
            tr.hat(tr.at(b, st), 0.2 if st % 2 else 0.12)
        tr.clank(tr.at(b, 2 if b % 2 else 10), 0.4, 260 if b % 2 else 200)
        for st in range(16):
            tr.bass(tr.at(b, st), s * 0.85, bass_f, 0.42 if st else 0.5, 0.65)
        for st in (0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 14, 15):
            tr.guitar(tr.at(b, st), s * 0.95, gtr_f, 0.45, True)
        for st in (4, 12):
            tr.guitar(tr.at(b, st), s * 2, gtr_f * 1.5, 0.3, False)
        if b >= 8:
            for k in range(4):
                tr.lead(tr.at(b, k * 4), s * 4, note('E5') if k % 2 == 0 else note('Bb4'), 0.2, 0.5, True)
        if b == 15:
            tr.riser(tr.at(b, 0), tr.bar, 0.3)
    return tr.render()


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if which in ('all', 'sfx'):
        for name, variants in make_sfx().items():
            for k, x in enumerate(variants):
                write(os.path.join(ROOT, 'sfx', f'{name}_{k + 1}.wav'), x)
            print(f'sfx  {name} x{len(variants)}')
    if which in ('all', 'music'):
        write(os.path.join(ROOT, 'music', 'level.wav'), level_track(), 0.8)
        print('music level')
        write(os.path.join(ROOT, 'music', 'boss.wav'), boss_track(), 0.8)
        print('music boss')


if __name__ == '__main__':
    main()
