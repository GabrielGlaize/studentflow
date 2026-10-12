#!/usr/bin/env python3
"""Dessine le logo Swikko : un « S » fait de deux flèches courbes qui se
répondent (école ⇄ entreprise, l'aller-retour de l'alternance).

Rendu à 4x puis réduit pour des bords nets. Sortie :
design/app-icon/swikko-logo-source.png (1024 x 1024, fond plein : iOS et
Android arrondissent eux-mêmes les coins).
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 4
SIZE = 1024 * SCALE
PETROL_TOP = (12, 74, 94)
PETROL_BOTTOM = (5, 45, 58)
MINT = (132, 220, 207)
SKY = (166, 217, 247)

OUT = Path(__file__).resolve().parent / "swikko-logo-source.png"


def s(value: float) -> float:
    return value * SCALE


def gradient() -> Image.Image:
    image = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(image)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(PETROL_TOP, PETROL_BOTTOM))
        draw.line([(0, y), (SIZE, y)], fill=color)
    return image


def arrow_arc(draw, center, radius, start, end, width, color):
    """Arc parcouru dans le sens horaire (repère écran) terminé par une flèche."""
    cx, cy = s(center[0]), s(center[1])
    r, w = s(radius), s(width)
    # L'arc s'arrête un peu avant la pointe pour laisser place à la flèche.
    head = 1.15 * width
    stop = end - math.degrees(head * 0.55 / radius)
    box = [cx - r, cy - r, cx + r, cy + r]
    draw.arc(box, start, stop, fill=color, width=round(w))
    a = math.radians(stop)
    mid_r = r - w / 2
    base = (cx + mid_r * math.cos(a), cy + mid_r * math.sin(a))
    tangent = (-math.sin(a), math.cos(a))
    normal = (math.cos(a), math.sin(a))
    length, half = s(head * 1.05), s(head * 0.95)
    tip = (base[0] + tangent[0] * length, base[1] + tangent[1] * length)
    left = (base[0] + normal[0] * half, base[1] + normal[1] * half)
    right = (base[0] - normal[0] * half, base[1] - normal[1] * half)
    draw.polygon([left, tip, right], fill=color)


def main() -> None:
    image = gradient()
    draw = ImageDraw.Draw(image)
    radius, width = 190, 118
    # Haut du « S » : menthe, du bas (milieu) vers la droite, flèche vers le bas.
    arrow_arc(draw, (512, 512 - radius + width / 2), radius, 90, 335, width, MINT)
    # Bas du « S » : bleu ciel, symétrique, flèche vers le haut.
    arrow_arc(draw, (512, 512 + radius - width / 2), radius, 270, 515, width, SKY)
    image.resize((1024, 1024), Image.LANCZOS).save(OUT)
    print(f"Logo écrit : {OUT}")


if __name__ == "__main__":
    main()
