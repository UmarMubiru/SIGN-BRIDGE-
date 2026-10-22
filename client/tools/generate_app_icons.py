"""Generate SignBridge desktop and Android launcher icons from the logo."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "assets" / "images" / "signbridge_logo.png"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
BACKGROUND = (7, 28, 39, 255)


def mark_from_logo() -> Image.Image:
    logo = Image.open(LOGO).convert("RGBA")
    # The supplied artwork places the hand-and-bridge mark above the wordmark.
    alpha = logo.getchannel("A").crop((0, 0, logo.width, int(logo.height * 0.65)))
    bbox = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No opaque logo artwork found in {LOGO}")
    return logo.crop(bbox)


def fit_mark(mark: Image.Image, size: int, fraction: float) -> Image.Image:
    width = max(1, round(size * fraction))
    height = max(1, round(width * mark.height / mark.width))
    resized = mark.resize((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((size - width) // 2, (size - height) // 2))
    return canvas


def main() -> None:
    mark = mark_from_logo()

    # Windows receives a transparent square icon with the mark kept intact.
    windows = fit_mark(mark, 1024, 0.82)
    WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
    windows.save(
        WINDOWS_ICON,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    # Legacy Android launchers use square raster assets with a solid background.
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in densities.items():
        icon = Image.new("RGBA", (size, size), BACKGROUND)
        icon.alpha_composite(fit_mark(mark, size, 0.76))
        output = ANDROID_RES / f"mipmap-{density}" / "ic_launcher.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        icon.save(output, optimize=True)

    # Adaptive foreground artwork stays within Android's central safe zone.
    foreground = fit_mark(mark, 432, 0.65)
    output = ANDROID_RES / "drawable-nodpi" / "signbridge_launcher_foreground.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    foreground.save(output, optimize=True)

    print(f"Generated Windows icon: {WINDOWS_ICON}")
    print(f"Generated Android launcher icons under: {ANDROID_RES}")


if __name__ == "__main__":
    main()
