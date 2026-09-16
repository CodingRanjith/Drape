import math
import os
import struct
import wave

sr = 44100
dur = 2.35
n = int(sr * dur)
samples = [0.0] * n


def env(t, a, d, s, r, hold):
    if t < a:
        return t / a if a > 0 else 1.0
    t2 = t - a
    if t2 < d:
        return 1.0 - (1.0 - s) * (t2 / d)
    t3 = t2 - d
    if t3 < hold:
        return s
    t4 = t3 - hold
    if t4 < r:
        return s * (1.0 - t4 / r)
    return 0.0


seed = 24681357


def noise():
    global seed
    seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
    return (seed / 0x7FFFFFFF) * 2.0 - 1.0


whoosh = [0.0] * n
lp = 0.0
hp_prev = 0.0
for i in range(n):
    t = i / sr
    center = 0.18 + 0.55 * math.sin(math.pi * min(1.0, t / 0.85))
    x = noise()
    alpha = 0.08 + 0.35 * center
    lp = lp + alpha * (x - lp)
    hp = lp - hp_prev * 0.92
    hp_prev = lp
    e = math.exp(-((t - 0.42) ** 2) / (2 * 0.18**2))
    e2 = math.exp(-((t - 0.22) ** 2) / (2 * 0.10**2)) * 0.55
    whoosh[i] = (hp * 0.55 + lp * 0.2) * (e + e2) * 0.55

partials = [
    (523.25, 1.00, 0.55),
    (659.25, 0.72, 0.62),
    (783.99, 0.58, 0.70),
    (1046.5, 0.28, 0.78),
    (1318.5, 0.14, 0.85),
]
chime_start = 0.38
for i in range(n):
    t = i / sr
    if t < chime_start:
        continue
    tc = t - chime_start
    s = 0.0
    for f, amp, delay in partials:
        td = tc - delay * 0.02
        if td < 0:
            continue
        attack = min(1.0, td / 0.035)
        decay = math.exp(-td * (2.2 + f / 1800.0))
        vib = 1.0 + 0.0025 * math.sin(2 * math.pi * 5.2 * td)
        phase = 2 * math.pi * f * vib * td
        tone = (
            math.sin(phase)
            + 0.18 * math.sin(2 * phase)
            + 0.06 * math.sin(3 * phase)
        )
        s += tone * amp * attack * decay
    if tc < 1.1:
        spark = (
            noise()
            * math.exp(-tc * 3.5)
            * 0.035
            * (0.5 + 0.5 * math.sin(2 * math.pi * 18 * tc))
        )
        s += spark
    samples[i] += s * 0.34

for i in range(n):
    t = i / sr
    pad = math.sin(2 * math.pi * 130.81 * t) * 0.5 + math.sin(
        2 * math.pi * 196.0 * t
    ) * 0.25
    pe = math.exp(-((t - 0.7) ** 2) / (2 * 0.45**2)) * 0.12
    samples[i] += pad * pe

for i in range(n):
    samples[i] += whoosh[i]

out = []
peak = 1e-9
for i, v in enumerate(samples):
    t = i / sr
    master = env(t, 0.02, 0.15, 1.0, 0.55, 1.4)
    if t > dur - 0.35:
        master *= (dur - t) / 0.35
    val = v * master
    peak = max(peak, abs(val))
    out.append(val)

norm = 0.88 / peak
pcm = []
for v in out:
    x = max(-1.0, min(1.0, v * norm))
    pcm.append(int(x * 32767))

path = os.path.join(
    os.path.dirname(__file__), "..", "assets", "brand", "splash_chime.wav"
)
path = os.path.abspath(path)
os.makedirs(os.path.dirname(path), exist_ok=True)
with wave.open(path, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(b"".join(struct.pack("<h", s) for s in pcm))
print("wrote", path, "seconds", dur)
