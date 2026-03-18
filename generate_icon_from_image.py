"""
Generate Dispatch app launcher icon from user-provided image (white bg + gold car).
Produces BOTH legacy ic_launcher.png AND adaptive icon layers.
"""
from PIL import Image
import os

# Input image path (user will need to save the image here first)
INPUT_IMAGE = 'icon_source_dispatch.png'

# ── Dimensions ──
SIZE = 1024
ADAPT_FG = 432

# ── Colors ──
WHITE = (255, 255, 255)

# Load and resize the source image
try:
    source_img = Image.open(INPUT_IMAGE).convert('RGBA')
    print(f'Loaded source image: {INPUT_IMAGE}')
except FileNotFoundError:
    print(f'ERROR: {INPUT_IMAGE} not found. Please save the image as {INPUT_IMAGE} in the same directory.')
    exit(1)

# ═══════════════════════════════════════
#  1. LEGACY ICON (ic_launcher.png)
# ═══════════════════════════════════════
img_legacy = source_img.resize((SIZE, SIZE), Image.LANCZOS)

# ═══════════════════════════════════════
#  2. ADAPTIVE FOREGROUND (transparent bg)
# ═══════════════════════════════════════
fg_master = source_img.resize((ADAPT_FG, ADAPT_FG), Image.LANCZOS)

# ═══════════════════════════════════════
#  3. ADAPTIVE BACKGROUND (solid white)
# ═══════════════════════════════════════
bg_master = Image.new('RGB', (ADAPT_FG, ADAPT_FG), WHITE)

# ═══════════════════════════════════════
#  OUTPUT PATHS
# ═══════════════════════════════════════
out_dir = os.path.dirname(os.path.abspath(__file__))
res_base = os.path.join(out_dir, 'android', 'app', 'src', 'main', 'res')

# Save master asset
master_path = os.path.join(out_dir, 'assets', 'dispatch_icon_1024.png')
os.makedirs(os.path.dirname(master_path), exist_ok=True)
# Convert RGBA to RGB for PNG
if img_legacy.mode == 'RGBA':
    rgb_img = Image.new('RGB', img_legacy.size, WHITE)
    rgb_img.paste(img_legacy, mask=img_legacy.split()[3])
    rgb_img.save(master_path, 'PNG')
else:
    img_legacy.save(master_path, 'PNG')
print(f'Saved master: {master_path}')

# Mipmap sizes (legacy square icon)
LEGACY_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, sz in LEGACY_SIZES.items():
    fp = os.path.join(res_base, folder)
    os.makedirs(fp, exist_ok=True)
    resized = img_legacy.resize((sz, sz), Image.LANCZOS)
    if resized.mode == 'RGBA':
        rgb_img = Image.new('RGB', resized.size, WHITE)
        rgb_img.paste(resized, mask=resized.split()[3])
        rgb_img.save(os.path.join(fp, 'ic_launcher.png'), 'PNG')
    else:
        resized.save(os.path.join(fp, 'ic_launcher.png'), 'PNG')
    print(f'  legacy  {folder}/ic_launcher.png  {sz}x{sz}')

# Adaptive foreground sizes
ADAPT_SIZES = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
}
for folder, sz in ADAPT_SIZES.items():
    fp = os.path.join(res_base, folder)
    os.makedirs(fp, exist_ok=True)
    fg_master.resize((sz, sz), Image.LANCZOS).save(os.path.join(fp, 'ic_launcher_foreground.png'), 'PNG')
    print(f'  fg      {folder}/ic_launcher_foreground.png  {sz}x{sz}')

# Adaptive background sizes
for folder, sz in ADAPT_SIZES.items():
    fp = os.path.join(res_base, folder)
    os.makedirs(fp, exist_ok=True)
    bg_master.resize((sz, sz), Image.LANCZOS).save(os.path.join(fp, 'ic_launcher_background.png'), 'PNG')
    print(f'  bg      {folder}/ic_launcher_background.png  {sz}x{sz}')

# ── Adaptive icon XML ──
import textwrap
anydpi_dir = os.path.join(res_base, 'mipmap-anydpi-v26')
os.makedirs(anydpi_dir, exist_ok=True)
xml_content = textwrap.dedent("""\
    <?xml version="1.0" encoding="utf-8"?>
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
        <background android:drawable="@mipmap/ic_launcher_background"/>
        <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    </adaptive-icon>
""")
with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w') as f:
    f.write(xml_content)
print(f'  xml     mipmap-anydpi-v26/ic_launcher.xml')

# ── Update colors.xml ──
import re
values_dir = os.path.join(res_base, 'values')
os.makedirs(values_dir, exist_ok=True)
colors_path = os.path.join(values_dir, 'colors.xml')
white_hex = '#FFFFFF'
bg_entry = f'<color name="ic_launcher_background">{white_hex}</color>'
if os.path.exists(colors_path):
    with open(colors_path, 'r') as f:
        content = f.read()
    if 'ic_launcher_background' in content:
        content = re.sub(
            r'<color name="ic_launcher_background">[^<]*</color>',
            bg_entry, content)
    else:
        content = content.replace('</resources>', f'    {bg_entry}\n</resources>')
    with open(colors_path, 'w') as f:
        f.write(content)
else:
    with open(colors_path, 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'    {bg_entry}\n</resources>\n')
standalone = os.path.join(values_dir, 'ic_launcher_background.xml')
if os.path.exists(standalone):
    os.remove(standalone)
print(f'  color   values/colors.xml (ic_launcher_background -> {white_hex})')

# ── Web icons (Dispatch is Android-only, but generate anyway) ──
web_dir = os.path.join(out_dir, 'web', 'icons')
os.makedirs(web_dir, exist_ok=True)
for name, wsz in [('Icon-192.png', 192), ('Icon-512.png', 512)]:
    resized = img_legacy.resize((wsz, wsz), Image.LANCZOS)
    if resized.mode == 'RGBA':
        rgb_img = Image.new('RGB', resized.size, WHITE)
        rgb_img.paste(resized, mask=resized.split()[3])
        rgb_img.save(os.path.join(web_dir, name), 'PNG')
    else:
        resized.save(os.path.join(web_dir, name), 'PNG')
    print(f'  web     {name}  {wsz}x{wsz}')

print('\nDone — Dispatch icon generated from user image.')
