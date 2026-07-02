from PIL import Image
import os

base = r"E:\godot\ai-game-0628"

textures = [
    r"assets\pixel_observatory\tripod.png",
    r"assets\pixel_observatory\eyepiece.png",
    r"assets\pixel_observatory\telescope_outline.png",
    r"assets\pixel_observatory\workbench.png",
    r"assets\sprout_lands\tilesets\grass.png",
    r"assets\sprout_lands\tilesets\wooden_house.png",
    r"assets\sprout_lands\objects\basic_furniture.png",
    r"assets\sprout_lands\objects\chest.png",
    r"assets\sprout_lands\objects\grass_biome.png",
    r"assets\sprout_lands\characters\basic_character.png",
]

for rel_path in textures:
    full_path = os.path.join(base, rel_path)
    if not os.path.exists(full_path):
        print(f"MISSING: {rel_path}")
        continue
    im = Image.open(full_path)
    mode = im.mode
    size = im.size

    transp = False
    black = False
    if mode == "RGBA":
        a = im.getchannel("A")
        e = a.getextrema()
        transp = e[0] < 255
        px = im.load()
        w, h = size
        corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
        black = sum(1 for x, y in corners if px[x, y][:3] == (0, 0, 0) and px[x, y][3] > 0) >= 3

    print(f"{rel_path}: {mode} {size} alpha={mode == 'RGBA'} transp={transp} black_bg={black}")
