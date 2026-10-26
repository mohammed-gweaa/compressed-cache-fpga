import os
import shutil
import fitz
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
POSTER_DIR = os.path.dirname(BASE_DIR)
src_pdf = os.path.join(BASE_DIR, "Academic_Poster_LaTeX_2m.pdf")
dst_pdf = os.path.join(POSTER_DIR, "EngPoster.pdf")
exports_dir = os.path.join(POSTER_DIR, "exports")
pres_asset = os.path.join(os.path.dirname(POSTER_DIR), "Presentation", "assets", "academic_poster_4k.png")

# 1. Copy master PDF
shutil.copy2(src_pdf, dst_pdf)
print(f"Copied master PDF to {dst_pdf}")

# 2. Render from PDF
doc = fitz.open(src_pdf)
page = doc[0]
rect = page.rect
print("Poster Rect:", rect)

# Define export targets
targets = [
    (os.path.join(exports_dir, "04_Poster_Master_Archive_8K_8000px.jpg"), 8000, 95),
    (os.path.join(exports_dir, "01_Poster_Teams_UltraHD_6000px.jpg"), 6000, 92),
    (os.path.join(exports_dir, "02_Poster_Facebook_4K_HighRes_4096px.jpg"), 4096, 90),
    (os.path.join(exports_dir, "03_Poster_Facebook_Feed_Standard_2048px.jpg"), 2048, 88),
]

# Render high-res base pixmap (8000px width)
zoom_8k = 8000.0 / rect.width
matrix_8k = fitz.Matrix(zoom_8k, zoom_8k)
print(f"Rendering 8K pixmap with zoom {zoom_8k:.4f}...")
pix_8k = page.get_pixmap(matrix=matrix_8k, alpha=False)
base_img = Image.frombytes("RGB", [pix_8k.width, pix_8k.height], pix_8k.samples)
print(f"Base image size: {base_img.size}")

os.makedirs(exports_dir, exist_ok=True)

for path, target_w, quality in targets:
    if target_w == base_img.width:
        img_to_save = base_img
    else:
        target_h = int(round(base_img.height * (target_w / base_img.width)))
        print(f"Resampling to {target_w}x{target_h}...")
        img_to_save = base_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    img_to_save.save(path, "JPEG", quality=quality, optimize=True)
    print(f"Saved: {path} ({os.path.getsize(path):,} bytes)")

# Presentation 4K PNG asset
if os.path.exists(os.path.dirname(pres_asset)):
    target_w = 3840
    target_h = int(round(base_img.height * (target_w / base_img.width)))
    print(f"Resampling presentation asset to {target_w}x{target_h} PNG...")
    pres_img = base_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
    pres_img.save(pres_asset, "PNG", optimize=True)
    print(f"Saved presentation asset: {pres_asset} ({os.path.getsize(pres_asset):,} bytes)")

print("All deliverables exported and synchronized successfully!")
