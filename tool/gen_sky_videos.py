"""Generate looping weather sky MP4s for the wardrobe outdoor band."""

from __future__ import annotations

import random
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sky"
W, H = 720, 270
FRAMES = 72  # 6s @ 12fps — smooth enough, small files


def soft_disk(h: int, w: int, cy: float, cx: float, ry: float, rx: float, amp: float) -> np.ndarray:
    y = np.arange(h, dtype=np.float32)[:, None]
    x = np.arange(w, dtype=np.float32)[None, :]
    d = ((y - cy) / max(ry, 1.0)) ** 2 + ((x - cx) / max(rx, 1.0)) ** 2
    return amp * np.exp(-d * 2.15)


def make_cloud_strip(width: int, height: int, seed: int, density: int, tone: tuple[int, int, int]) -> Image.Image:
    rng = random.Random(seed)
    alpha = np.zeros((height, width), dtype=np.float32)
    for _ in range(density):
        cx = rng.uniform(0, width)
        cy = rng.uniform(height * 0.12, height * 0.88)
        rx = rng.uniform(width * 0.05, width * 0.14)
        ry = rng.uniform(height * 0.14, height * 0.4)
        amp = rng.uniform(0.4, 0.98)
        alpha += soft_disk(height, width, cy, cx, ry, rx, amp)
        for _k in range(rng.randint(2, 5)):
            ox = rng.uniform(-rx, rx)
            oy = rng.uniform(-ry * 0.55, ry * 0.55)
            alpha += soft_disk(
                height,
                width,
                cy + oy,
                cx + ox,
                ry * rng.uniform(0.35, 0.75),
                rx * rng.uniform(0.35, 0.75),
                amp * rng.uniform(0.25, 0.7),
            )
    haze = np.linspace(0.12, 0.5, height, dtype=np.float32)[:, None]
    alpha = np.clip(alpha * 0.88 + haze * 0.22, 0, 1)
    rgb = np.zeros((height, width, 3), dtype=np.uint8)
    rgb[:, :, 0] = tone[0]
    rgb[:, :, 1] = tone[1]
    rgb[:, :, 2] = tone[2]
    a = (alpha * 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, a]), "RGBA")
    return img.filter(ImageFilter.GaussianBlur(radius=3.5))


def add_sun(frame: Image.Image) -> Image.Image:
    overlay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    cx, cy = int(W * 0.78), int(H * 0.28)
    for r, a in ((70, 28), (42, 55), (22, 110), (10, 200)):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 236, 160, a))
    return Image.alpha_composite(frame.convert("RGBA"), overlay).convert("RGB")


def add_rain(frame: Image.Image, t: int, rng: random.Random) -> Image.Image:
    overlay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for i in range(70):
        x = (i * 47 + t * 9) % W
        y0 = (i * 29 + t * 17) % H
        draw.line((x, y0, x - 2, y0 + 12), fill=(210, 225, 235, 110), width=1)
    return Image.alpha_composite(frame.convert("RGBA"), overlay).convert("RGB")


def render_clip(name: str, base_rgb: tuple[int, int, int], clouds: Image.Image, *, sunny: bool = False, rainy: bool = False) -> None:
    frames_dir = OUT / f"_frames_{name}"
    if frames_dir.exists():
        shutil.rmtree(frames_dir)
    frames_dir.mkdir(parents=True)

    strip = clouds
    strip_w = strip.width
    loop_w = strip_w // 2  # first half equals travel distance for seamless loop
    assert strip_w >= W * 2

    rain_rng = random.Random(99)
    for i in range(FRAMES):
        x = int((i / FRAMES) * loop_w)
        crop = strip.crop((x, 0, x + W, H))
        base = Image.new("RGB", (W, H), base_rgb)
        # subtle vertical sky gradient
        grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(grad)
        for y in range(H):
            a = int(40 * (y / max(H - 1, 1)))
            gdraw.line((0, y, W, y), fill=(255, 255, 255, a) if not rainy else (0, 0, 0, a // 2))
        composed = Image.alpha_composite(base.convert("RGBA"), crop)
        composed = Image.alpha_composite(composed, grad).convert("RGB")
        if sunny:
            composed = add_sun(composed)
        if rainy:
            composed = add_rain(composed, i, rain_rng)
            # slightly darken
            arr = (np.asarray(composed).astype(np.float32) * 0.92).clip(0, 255).astype(np.uint8)
            composed = Image.fromarray(arr)
        composed.save(frames_dir / f"f{i:03d}.png")

    mp4 = OUT / f"{name}.mp4"
    cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-framerate",
        "12",
        "-i",
        str(frames_dir / "f%03d.png"),
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "baseline",
        "-level",
        "3.0",
        "-crf",
        "28",
        "-movflags",
        "+faststart",
        "-an",
        str(mp4),
    ]
    subprocess.check_call(cmd)
    shutil.rmtree(frames_dir)
    print(f"wrote {mp4} ({mp4.stat().st_size} bytes)")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Wide strips (2x viewport) for seamless horizontal drift
    light = make_cloud_strip(W * 2, H, seed=7, density=24, tone=(255, 252, 248))
    heavy = make_cloud_strip(W * 2, H, seed=19, density=32, tone=(236, 240, 244))
    storm = make_cloud_strip(W * 2, H, seed=33, density=36, tone=(168, 178, 190))
    light.save(OUT / "_clouds_light.png")
    heavy.save(OUT / "_clouds_heavy.png")
    storm.save(OUT / "_clouds_storm.png")

    render_clip("sunny", (79, 163, 232), light, sunny=True)
    render_clip("cloudy", (143, 163, 178), heavy)
    render_clip("rainy", (58, 75, 90), storm, rainy=True)

    # cleanup helper textures
    for p in OUT.glob("_*.png"):
        p.unlink(missing_ok=True)
    print("done")


if __name__ == "__main__":
    main()
