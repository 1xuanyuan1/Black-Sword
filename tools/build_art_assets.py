#!/usr/bin/env python3
"""Deterministically prepare the user-supplied hero atlas and arena backdrop."""

from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
import math
import random


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/hero_reference.png"
HERO_OUT = ROOT / "assets/actors/hero/hero_actual.png"
PORTRAIT_OUT = ROOT / "assets/actors/hero/portrait_actual.png"
TORNADO_OUT = ROOT / "assets/vfx/dragon_tornado.png"
MAP_OUT = ROOT / "assets/world/arena_background.png"
RUINS_SOURCE = ROOT / "assets/world/tileset_ruins.png"
COURTYARD_SOURCE = ROOT / "assets/world/tileset_courtyard.png"


STRIPS = [
    ("idle", (0, 34, 512, 160), 6),
    ("run_down", (512, 353, 1024, 498), 6),
    ("run_up", (0, 353, 512, 498), 6),
    ("run_left", (512, 34, 1024, 160), 6),
    ("run_right", (0, 194, 512, 319), 6),
    ("attack_slash", (0, 529, 1024, 633), 6),
    ("attack_thrust", (0, 656, 1024, 751), 6),
    ("hurt", (0, 775, 1024, 878), 6),
    ("death", (0, 897, 1024, 998), 6),
]

# The supplied horizontal-run strips each contain three left-facing frames
# followed by three right-facing frames.  Build one coherent six-frame left
# cycle from the first halves of both strips, then mirror it for running right.
HORIZONTAL_RUN_PANELS = [
    (512, 34, 1024, 160),
    (0, 194, 512, 319),
]


def _is_background(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    spread = max(rgb) - min(rgb)
    light = (r + g + b) / 3
    return (spread <= 22 and light >= 148) or min(rgb) >= 228


def remove_checkerboard(frame: Image.Image) -> Image.Image:
    """Remove only border-connected neutral checkerboard pixels."""
    rgba = frame.convert("RGBA")
    width, height = rgba.size
    source = rgba.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def add(x: int, y: int) -> None:
        index = y * width + x
        if visited[index]:
            return
        if _is_background(source[x, y][:3]):
            visited[index] = 1
            queue.append((x, y))

    for x in range(width):
        add(x, 0)
        add(x, height - 1)
    for y in range(height):
        add(0, y)
        add(width - 1, y)

    while queue:
        x, y = queue.popleft()
        source[x, y] = (*source[x, y][:3], 0)
        if x > 0:
            add(x - 1, y)
        if x + 1 < width:
            add(x + 1, y)
        if y > 0:
            add(x, y - 1)
        if y + 1 < height:
            add(x, y + 1)

    # Remove isolated checker cells that remain far from colored/dark artwork.
    alpha = rgba.getchannel("A")
    pixels = rgba.load()
    for y in range(height):
        for x in range(width):
            if alpha.getpixel((x, y)) == 0:
                continue
            r, g, b, a = pixels[x, y]
            if _is_background((r, g, b)):
                near_foreground = False
                for oy in range(max(0, y - 2), min(height, y + 3)):
                    for ox in range(max(0, x - 2), min(width, x + 3)):
                        nr, ng, nb, _ = pixels[ox, oy]
                        if not _is_background((nr, ng, nb)):
                            near_foreground = True
                            break
                    if near_foreground:
                        break
                if not near_foreground:
                    pixels[x, y] = (r, g, b, 0)
                elif a > 0:
                    pixels[x, y] = (r, g, b, 90)
    return rgba


def keep_center_subject(frame: Image.Image, expected_x: float) -> Image.Image:
    """Keep only the centered actor, dropping pieces from adjacent run frames."""
    rgba = frame.copy()
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    pixels = alpha.load()
    visited = bytearray(width * height)
    components: list[dict] = []

    for sy in range(height):
        for sx in range(width):
            index = sy * width + sx
            if visited[index] or pixels[sx, sy] < 20:
                continue
            visited[index] = 1
            queue = deque([(sx, sy)])
            points: list[tuple[int, int]] = []
            min_x = max_x = sx
            min_y = max_y = sy
            while queue:
                x, y = queue.popleft()
                points.append((x, y))
                min_x, max_x = min(min_x, x), max(max_x, x)
                min_y, max_y = min(min_y, y), max(max_y, y)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < width and 0 <= ny < height:
                        ni = ny * width + nx
                        if not visited[ni] and pixels[nx, ny] >= 20:
                            visited[ni] = 1
                            queue.append((nx, ny))
            if len(points) >= 6:
                cx = sum(p[0] for p in points) / len(points)
                cy = sum(p[1] for p in points) / len(points)
                components.append({
                    "points": points,
                    "area": len(points),
                    "bbox": (min_x, min_y, max_x, max_y),
                    "center": (cx, cy),
                })

    if not components:
        return rgba
    expected_y = height * 0.56
    main = min(
        components,
        key=lambda comp: (
            abs(comp["center"][0] - expected_x) * 1.4
            + abs(comp["center"][1] - expected_y) * 0.35
            - min(comp["area"], 6000) * 0.012
        ),
    )
    keep_points = set(main["points"])
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    source_pixels = rgba.load()
    output_pixels = output.load()
    for x, y in keep_points:
        output_pixels[x, y] = source_pixels[x, y]
    return output


def build_hero() -> None:
    source = Image.open(SOURCE).convert("RGB")
    cell = 160
    atlas = Image.new("RGBA", (cell * 6, cell * len(STRIPS)), (0, 0, 0, 0))
    portrait = None

    for row, (name, panel, count) in enumerate(STRIPS):
        for column in range(count):
            if name in ("run_left", "run_right"):
                # Both original strips switch direction halfway through. Use
                # only their three genuine left-facing frames and combine the
                # two takes into a consistent six-frame animation.
                x0, y0, x1, y1 = HORIZONTAL_RUN_PANELS[column // 3]
                panel_width = x1 - x0
                source_column = column % 3
                frame_center = x0 + panel_width * (source_column + 0.5) / 6
                left = max(x0, round(frame_center - 65))
                right = min(x1, round(frame_center + 65))
            else:
                x0, y0, x1, y1 = panel
                panel_width = x1 - x0
                frame_center = x0 + panel_width * (column + 0.5) / count
                left = round(x0 + panel_width * column / count) + 2
                right = round(x0 + panel_width * (column + 1) / count) - 2
            top = y0 + 1
            bottom = y1 - 1
            raw = source.crop((left, top, right, bottom))
            cleaned = remove_checkerboard(raw)
            if name in ("run_left", "run_right"):
                cleaned = keep_center_subject(cleaned, frame_center - left)
                if name == "run_right":
                    cleaned = cleaned.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            bbox = cleaned.getbbox()
            if bbox is None:
                continue
            cleaned = cleaned.crop(bbox)
            max_width = 154
            max_height = 154
            scale = min(max_width / cleaned.width, max_height / cleaned.height, 1.14)
            if scale < 0.995 or scale > 1.005:
                cleaned = cleaned.resize(
                    (max(1, round(cleaned.width * scale)), max(1, round(cleaned.height * scale))),
                    Image.Resampling.LANCZOS,
                )
            paste_x = column * cell + (cell - cleaned.width) // 2
            paste_y = row * cell + cell - cleaned.height - 3
            atlas.alpha_composite(cleaned, (paste_x, paste_y))
            if row == 0 and column == 0:
                portrait = cleaned.copy()

    HERO_OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(HERO_OUT, optimize=True)
    if portrait is not None:
        portrait_canvas = Image.new("RGBA", (320, 320), (0, 0, 0, 0))
        scale = min(286 / portrait.width, 286 / portrait.height)
        portrait = portrait.resize(
            (round(portrait.width * scale), round(portrait.height * scale)),
            Image.Resampling.LANCZOS,
        )
        portrait_canvas.alpha_composite(
            portrait,
            ((320 - portrait.width) // 2, 310 - portrait.height),
        )
        portrait_canvas.save(PORTRAIT_OUT, optimize=True)


def _crop_rgba(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    return image.crop(box).convert("RGBA")


def _paste_scaled(canvas: Image.Image, sprite: Image.Image, xy: tuple[int, int], scale: float, flip=False) -> None:
    if flip:
        sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if scale != 1.0:
        sprite = sprite.resize(
            (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))),
            Image.Resampling.NEAREST,
        )
    canvas.alpha_composite(sprite, xy)


def build_rubble_patch(flip: bool = False) -> Image.Image:
    """Draw one coherent low mossy stone pile without atlas-neighbour fragments."""
    patch = Image.new("RGBA", (72, 30), (0, 0, 0, 0))
    draw = ImageDraw.Draw(patch, "RGBA")
    draw.ellipse((5, 20, 67, 28), fill=(8, 16, 18, 115))
    stones = [
        (4, 13, 20, 24, [(6, 18), (9, 13), (17, 12), (21, 17), (18, 24), (8, 24)]),
        (17, 8, 35, 24, [(18, 17), (21, 9), (30, 7), (36, 13), (34, 22), (27, 25), (19, 22)]),
        (32, 12, 50, 25, [(33, 18), (38, 12), (47, 12), (52, 18), (48, 25), (37, 25)]),
        (49, 9, 68, 24, [(50, 16), (55, 9), (64, 10), (69, 16), (66, 23), (57, 25), (50, 21)]),
    ]
    for index, (_x0, _y0, _x1, _y1, polygon) in enumerate(stones):
        fill = [(105, 104, 88, 255), (119, 112, 91, 255), (91, 96, 82, 255), (111, 103, 84, 255)][index]
        draw.polygon(polygon, fill=fill, outline=(39, 48, 45, 255))
        x, y = polygon[1]
        draw.line((x + 2, y + 2, x + 7, y + 1), fill=(153, 142, 110, 150), width=1)
    draw.line((8, 13, 15, 12, 21, 14), fill=(68, 91, 51, 255), width=2)
    draw.line((28, 8, 34, 10, 39, 12), fill=(73, 94, 52, 255), width=2)
    draw.line((52, 10, 59, 9, 65, 12), fill=(67, 88, 49, 255), width=2)
    for x in (2, 24, 46, 69):
        draw.line((x, 25, x + 1, 20), fill=(55, 79, 48, 230), width=1)
        draw.line((x + 2, 25, x + 4, 21), fill=(62, 86, 49, 220), width=1)
    return patch.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if flip else patch


def build_dragon_tornado() -> None:
    """Create a six-frame transparent pixel-art sword-wind tornado atlas."""
    frame_size = 64
    frame_count = 6
    atlas = Image.new("RGBA", (frame_size * frame_count, frame_size), (0, 0, 0, 0))
    for frame_index in range(frame_count):
        frame = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame, "RGBA")
        phase = frame_index * 60

        # A restrained contact shadow keeps the funnel readable on cobbles.
        draw.ellipse((20, 53, 44, 58), fill=(5, 13, 22, 92))

        # Tapered mist body, deliberately asymmetric from frame to frame.
        body = [
            (21 + (frame_index % 2), 17),
            (43, 17 + ((frame_index + 1) % 2)),
            (39, 31),
            (36, 43),
            (34, 54),
            (29, 54),
            (27, 43),
            (24, 31),
        ]
        draw.polygon(body, fill=(49, 118, 137, 82))

        bands = [
            (18, 20, 7),
            (25, 18, 7),
            (33, 15, 6),
            (41, 12, 5),
            (49, 8, 4),
        ]
        for band_index, (y, half_width, half_height) in enumerate(bands):
            wobble = round(2.0 * math.sin(math.radians(phase + band_index * 71)))
            box = (32 + wobble - half_width, y - half_height, 32 + wobble + half_width, y + half_height)
            start = phase + band_index * 43
            draw.arc(box, start + 12, start + 196, fill=(24, 67, 91, 245), width=4)
            draw.arc(box, start + 180, start + 342, fill=(82, 185, 194, 245), width=3)
            draw.arc(box, start + 220, start + 305, fill=(218, 247, 238, 238), width=2)

        # A small wind-dragon head rides the upper coil: snout, horn and eye.
        facing = 1 if frame_index in (0, 1, 5) else -1
        head_x = 32 + (4 if facing > 0 else -4)
        head = [
            (head_x - 7 * facing, 17),
            (head_x - 4 * facing, 11),
            (head_x + 1 * facing, 8),
            (head_x + 7 * facing, 11),
            (head_x + 9 * facing, 15),
            (head_x + 4 * facing, 18),
            (head_x - 1 * facing, 17),
        ]
        draw.polygon(head, fill=(83, 182, 191, 255), outline=(18, 48, 70, 255))
        draw.line((head_x - 2 * facing, 10, head_x - 4 * facing, 5), fill=(190, 238, 226, 255), width=2)
        draw.line((head_x + 1 * facing, 9, head_x + 2 * facing, 5), fill=(190, 238, 226, 255), width=2)
        draw.point((head_x + 3 * facing, 12), fill=(255, 226, 111, 255))
        draw.line((head_x + 6 * facing, 15, head_x + 10 * facing, 14), fill=(222, 248, 240, 255), width=1)

        # Loose wisps sell rotation without enlarging the damage footprint.
        draw.arc((7, 25, 31, 45), phase + 20, phase + 155, fill=(99, 197, 202, 185), width=2)
        draw.arc((35, 20, 58, 42), phase + 188, phase + 320, fill=(186, 235, 228, 185), width=2)
        atlas.alpha_composite(frame, (frame_index * frame_size, 0))

    TORNADO_OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(TORNADO_OUT, optimize=True)


def build_map() -> None:
    random.seed(1907)
    ruins = Image.open(RUINS_SOURCE).convert("RGBA")
    courtyard = Image.open(COURTYARD_SOURCE).convert("RGBA")
    width, height = 768, 432

    # Natural dirt base with small pixel-scale variation instead of repeated giant slabs.
    ground_tile = Image.new("RGBA", (16, 16), (35, 49, 43, 255))
    ground_draw = ImageDraw.Draw(ground_tile, "RGBA")
    for _ in range(14):
        x, y = random.randrange(16), random.randrange(16)
        shade = random.choice([(45, 61, 51, 180), (25, 38, 36, 190), (56, 62, 48, 150)])
        ground_draw.point((x, y), fill=shade)
    ground_draw.line((1, 12, 5, 11), fill=(26, 38, 35, 130), width=1)
    ground_draw.line((10, 4, 14, 5), fill=(49, 61, 50, 120), width=1)
    canvas = Image.new("RGBA", (width, height), (29, 42, 39, 255))
    for y in range(0, height, 16):
        for x in range(0, width, 16):
            tile = ground_tile
            if random.random() < 0.5:
                tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            canvas.alpha_composite(tile, (x, y))

    draw = ImageDraw.Draw(canvas, "RGBA")
    # A bounded temple courtyard with gates and a real 16px cobblestone surface.
    court_rect = (190, 86, 578, 358)
    draw.rectangle((180, 76, 588, 368), fill=(17, 25, 29, 255), outline=(9, 15, 20, 255), width=3)
    cobble_origins = [(240, 224), (256, 224), (272, 224), (288, 224), (304, 224), (320, 224)]
    cobbles = [courtyard.crop((x, y, x + 16, y + 16)) for x, y in cobble_origins]
    for y in range(court_rect[1], court_rect[3], 16):
        for x in range(court_rect[0], court_rect[2], 16):
            tile = random.choice(cobbles)
            if random.random() < 0.3:
                tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            canvas.alpha_composite(tile, (x, y))
    # Main north/south approach paths.
    for y in range(0, 86, 16):
        for x in range(352, 416, 16):
            canvas.alpha_composite(random.choice(cobbles), (x, y))
    for y in range(358, height, 16):
        for x in range(352, 416, 16):
            canvas.alpha_composite(random.choice(cobbles), (x, y))

    draw = ImageDraw.Draw(canvas, "RGBA")
    # Low stone wall with readable gates at the top and bottom.
    wall_color = (62, 70, 72, 255)
    wall_shadow = (22, 31, 35, 255)
    for x in range(180, 588, 16):
        if 344 <= x <= 416:
            continue
        draw.rectangle((x, 76, x + 14, 86), fill=wall_shadow)
        draw.rectangle((x + 1, 73, x + 13, 81), fill=wall_color, outline=(88, 92, 85, 255))
        draw.rectangle((x, 358, x + 14, 368), fill=wall_shadow)
        draw.rectangle((x + 1, 355, x + 13, 363), fill=wall_color, outline=(88, 92, 85, 255))
    for y in range(84, 360, 16):
        draw.rectangle((180, y, 190, y + 14), fill=wall_shadow)
        draw.rectangle((177, y + 1, 185, y + 13), fill=wall_color, outline=(88, 92, 85, 255))
        draw.rectangle((578, y, 588, y + 14), fill=wall_shadow)
        draw.rectangle((583, y + 1, 591, y + 13), fill=wall_color, outline=(88, 92, 85, 255))

    # Asset-pack ruins: temple, side buildings and rubble outside the arena.
    shrine = _crop_rgba(ruins, (190, 82, 320, 173))
    shrine = ImageEnhance.Brightness(shrine).enhance(0.64)
    shrine = ImageEnhance.Color(shrine).enhance(0.72)
    _paste_scaled(canvas, shrine, (312, 6), 1.1)
    broken_house = _crop_rgba(ruins, (0, 0, 84, 48))
    broken_house = ImageEnhance.Brightness(broken_house).enhance(0.58)
    _paste_scaled(canvas, broken_house, (24, 18), 1.45)
    _paste_scaled(canvas, broken_house, (622, 18), 1.45, flip=True)
    # Use one complete tree from the source sheet instead of pasting its
    # pre-composed three-tree cluster.  Staggered rows read as a forest edge
    # while keeping every trunk visible and the courtyard silhouette clear.
    # Exact source bounds marked by the user: crown + roots only.  The next
    # columns/rows belong to a wooden post and loose debris on the atlas.
    tree = _crop_rgba(ruins, (64, 96, 96, 128))
    tree = ImageEnhance.Brightness(tree).enhance(0.48)
    tree_positions = [
        (31, 91, 0.94, False),
        (101, 119, 1.04, True),
        (48, 176, 1.09, True),
        (116, 224, 0.88, False),
        (28, 273, 0.98, False),
        (91, 318, 1.05, True),
        (44, 370, 0.86, True),
        (701, 86, 0.91, True),
        (634, 132, 1.06, False),
        (691, 192, 0.96, False),
        (615, 239, 0.89, True),
        (681, 289, 1.08, True),
        (626, 342, 0.94, False),
        (704, 375, 0.84, False),
    ]
    tree_draw = ImageDraw.Draw(canvas, "RGBA")
    for x, y, scale, flip in sorted(tree_positions, key=lambda item: item[1]):
        crown_width = round(tree.width * scale)
        tree_draw.ellipse(
            (x + 4, y + round(tree.height * scale) - 8, x + crown_width - 4, y + round(tree.height * scale) + 2),
            fill=(4, 11, 13, 105),
        )
        _paste_scaled(canvas, tree, (x, y), scale, flip)
    # Compact mossy rubble replaces the old wide atlas crop that included
    # unrelated beams, a well rim and partial neighbouring sprites.
    rubble_left = build_rubble_patch(False)
    rubble_right = build_rubble_patch(True)
    _paste_scaled(canvas, rubble_left, (68, 382), 0.88)
    _paste_scaled(canvas, rubble_right, (637, 378), 0.88)

    # Small hand-drawn tufts avoid chopped fragments from the tightly packed
    # detail spritesheet while still breaking up the empty exterior ground.
    detail_draw = ImageDraw.Draw(canvas, "RGBA")
    for _ in range(54):
        x = random.randrange(16, width - 16)
        y = random.randrange(16, height - 16)
        if 165 < x < 603 and 62 < y < 380:
            continue
        color = random.choice([(54, 70, 46, 190), (64, 74, 48, 170), (38, 58, 46, 190)])
        detail_draw.line((x, y + 4, x + 1, y), fill=color, width=1)
        detail_draw.line((x + 2, y + 4, x + 4, y + 1), fill=color, width=1)
        if random.random() < 0.36:
            detail_draw.point((x + 6, y + 4), fill=(81, 77, 61, 135))

    # Torii gate, stone lanterns and a small worn crest give the arena landmarks.
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rectangle((0, 0, width - 1, height - 1), outline=(8, 12, 17, 255), width=8)
    # North torii.
    draw.rectangle((353, 55, 360, 88), fill=(96, 43, 38, 255))
    draw.rectangle((408, 55, 415, 88), fill=(96, 43, 38, 255))
    draw.rectangle((342, 51, 426, 58), fill=(135, 55, 43, 255), outline=(61, 29, 27, 255))
    draw.rectangle((349, 61, 419, 66), fill=(118, 48, 39, 255))

    def stone_lantern(x: int, y: int) -> None:
        draw.ellipse((x - 10, y - 10, x + 10, y + 10), fill=(255, 124, 61, 22))
        draw.rectangle((x - 3, y + 5, x + 3, y + 18), fill=(88, 87, 78, 255))
        draw.rectangle((x - 6, y + 17, x + 6, y + 20), fill=(58, 61, 60, 255))
        draw.polygon([(x - 8, y - 3), (x + 8, y - 3), (x + 5, y + 6), (x - 5, y + 6)], fill=(112, 99, 78, 255))
        draw.rectangle((x - 4, y - 1, x + 4, y + 4), fill=(213, 97, 48, 255))
        draw.polygon([(x - 10, y - 4), (x, y - 11), (x + 10, y - 4)], fill=(73, 71, 66, 255))

    for x, y in [(214, 116), (554, 116), (214, 322), (554, 322)]:
        stone_lantern(x, y)

    # Subtle worn crest, smaller than the player combat area.
    draw.ellipse((357, 199, 411, 253), outline=(90, 96, 101, 125), width=2)
    draw.polygon([(382, 207), (386, 207), (388, 240), (384, 247), (380, 240)], fill=(24, 29, 33, 185))
    draw.rectangle((372, 236, 396, 240), fill=(92, 54, 48, 150))
    # Cracks and worn patches inside the yard.
    for x, y in [(266, 156), (490, 183), (302, 304), (514, 286), (252, 252)]:
        draw.line((x, y, x + 5, y + 3, x + 10, y + 1), fill=(25, 28, 30, 150), width=1)

    # Night grade remains readable under the HUD.
    grade = Image.new("RGBA", canvas.size, (8, 23, 42, 48))
    canvas = Image.alpha_composite(canvas, grade)
    vignette = Image.new("L", canvas.size, 0)
    vdraw = ImageDraw.Draw(vignette)
    for inset in range(0, 72, 6):
        alpha = max(0, 86 - inset)
        vdraw.rectangle((inset, inset, width - inset - 1, height - inset - 1), outline=alpha, width=6)
    vignette = vignette.filter(ImageFilter.GaussianBlur(10))
    dark = Image.new("RGBA", canvas.size, (0, 4, 12, 0))
    dark.putalpha(vignette)
    canvas = Image.alpha_composite(canvas, dark)

    canvas = canvas.resize((width * 4, height * 4), Image.Resampling.NEAREST)
    MAP_OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(MAP_OUT, optimize=True)


if __name__ == "__main__":
    build_hero()
    build_dragon_tornado()
    build_map()
    print(HERO_OUT)
    print(PORTRAIT_OUT)
    print(TORNADO_OUT)
    print(MAP_OUT)
