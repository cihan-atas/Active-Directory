#!/usr/bin/env python3
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_ad_vault_icon(target_size=1024):
    ss = 2048
    # Canvas
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = ss / 2
    cy = ss / 2

    # 1. Base Squircle Dimensions
    margin = 100
    radius = 420
    rect = [margin, margin, ss - margin, ss - margin]

    # Create solid base layer
    base = Image.new("RGBA", (ss, ss), (10, 14, 24, 255))
    b_draw = ImageDraw.Draw(base)

    # Subtle glowing ambient lighting
    ambient = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    a_draw = ImageDraw.Draw(ambient)
    # Red Team ambient top-left
    a_draw.ellipse([cx - 850, cy - 850, cx + 50, cy + 50], fill=(220, 38, 38, 50))
    # Blue Team ambient bottom-right
    a_draw.ellipse([cx - 50, cy - 50, cx + 850, cy + 850], fill=(37, 99, 235, 60))
    # Cyber Cyan core highlight
    a_draw.ellipse([cx - 300, cy - 300, cx + 300, cy + 300], fill=(14, 165, 233, 40))
    ambient = ambient.filter(ImageFilter.GaussianBlur(110))
    base = Image.alpha_composite(base, ambient)

    # Subtle tech circuit pattern in background
    circuit = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(circuit)
    step = 120
    for x in range(margin + 60, ss - margin, step):
        c_draw.line([(x, margin), (x, ss - margin)], fill=(22, 32, 52, 90), width=4)
    for y in range(margin + 60, ss - margin, step):
        c_draw.line([(margin, y), (ss - margin, y)], fill=(22, 32, 52, 90), width=4)

    base = Image.alpha_composite(base, circuit)

    # Mask base to squircle
    sq_mask = Image.new("L", (ss, ss), 0)
    sq_draw = ImageDraw.Draw(sq_mask)
    sq_draw.rounded_rectangle(rect, radius=radius, fill=255)
    img.paste(base, (0, 0), sq_mask)

    # 2. Glowing Dual Border (Red Team Left, Blue Team Right)
    # We create a horizontal gradient for the border
    grad_border = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    gb_draw = ImageDraw.Draw(grad_border)
    # Draw gradient lines horizontally
    for x in range(ss):
        t = x / ss  # 0.0 (red) to 1.0 (blue)
        r_col = int(239 * (1 - t) + 59 * t)
        g_col = int(68 * (1 - t) + 130 * t)
        b_col = int(68 * (1 - t) + 246 * t)
        gb_draw.line([(x, 0), (x, ss)], fill=(r_col, g_col, b_col, 255), width=1)

    # Border mask
    border_mask = Image.new("L", (ss, ss), 0)
    bm_draw = ImageDraw.Draw(border_mask)
    bm_draw.rounded_rectangle(rect, radius=radius, outline=255, width=28)

    # Paste gradient border onto image
    img.paste(grad_border, (0, 0), border_mask)

    # Inner subtle dark inset line
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        [margin + 28, margin + 28, ss - margin - 28, ss - margin - 28],
        radius=radius - 20,
        outline=(15, 23, 42, 220),
        width=8
    )

    # 3. Security Shield (Majestic Cyber Shield)
    s_top = 400
    s_mid = 1120
    s_bot = 1660
    s_left = 420
    s_right = ss - 420

    shield_pts = [
        (s_left, s_top),
        (cx, s_top - 50),
        (s_right, s_top),
        (s_right, s_mid),
        (cx, s_bot),
        (s_left, s_mid)
    ]

    # Shield shadow
    shield_shadow = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    ss_draw = ImageDraw.Draw(shield_shadow)
    ss_draw.polygon([(p[0], p[1] + 20) for p in shield_pts], fill=(0, 0, 0, 160))
    shield_shadow = shield_shadow.filter(ImageFilter.GaussianBlur(30))
    img.alpha_composite(shield_shadow)

    # Shield base fill
    draw = ImageDraw.Draw(img)
    draw.polygon(shield_pts, fill=(15, 22, 36, 255))

    # Split shading: Left half (Red accent dark), Right half (Blue accent dark)
    left_half = [
        (s_left, s_top),
        (cx, s_top - 50),
        (cx, s_bot),
        (s_left, s_mid)
    ]
    draw.polygon(left_half, fill=(28, 20, 30, 160))

    # Shield Outer Border: Red on left, Blue on right, Cyan on top
    draw.line([(s_left, s_top), (cx, s_top - 50)], fill=(239, 68, 68, 255), width=28)
    draw.line([(cx, s_top - 50), (s_right, s_top)], fill=(59, 130, 246, 255), width=28)
    draw.line([(s_right, s_top), (s_right, s_mid)], fill=(59, 130, 246, 255), width=28)
    draw.line([(s_right, s_mid), (cx, s_bot)], fill=(59, 130, 246, 255), width=28)
    draw.line([(cx, s_bot), (s_left, s_mid)], fill=(239, 68, 68, 255), width=28)
    draw.line([(s_left, s_mid), (s_left, s_top)], fill=(239, 68, 68, 255), width=28)

    # Subtle inner bevel line
    draw.line([(cx, s_top - 35), (cx, s_bot - 35)], fill=(30, 41, 59, 180), width=10)

    # 4. Active Directory Forest Tree Architecture
    r_x, r_y = cx, 660  # Root DC
    t1_x, t1_y = cx - 270, 930  # Red Team / Attack Domain
    t2_x, t2_y = cx + 270, 930  # Blue Team / Defense Domain

    l1_x, l1_y = cx - 290, 1260
    l2_x, l2_y = cx - 105, 1320
    l3_x, l3_y = cx + 105, 1320
    l4_x, l4_y = cx + 290, 1260

    # Draw Circuit Lines (Glowing & Crisp)
    # Root to Tier 1
    draw.line([(r_x, r_y), (t1_x, t1_y)], fill=(239, 68, 68, 255), width=18)
    draw.line([(r_x, r_y), (t2_x, t2_y)], fill=(59, 130, 246, 255), width=18)
    # Tier 1 to Leaves
    draw.line([(t1_x, t1_y), (l1_x, l1_y)], fill=(239, 68, 68, 220), width=14)
    draw.line([(t1_x, t1_y), (l2_x, l2_y)], fill=(245, 158, 11, 220), width=14)
    draw.line([(t2_x, t2_y), (l3_x, l3_y)], fill=(16, 185, 129, 220), width=14)
    draw.line([(t2_x, t2_y), (l4_x, l4_y)], fill=(59, 130, 246, 220), width=14)
    # Trust Relationship Link (Amber Gold)
    draw.line([(l2_x, l2_y), (l3_x, l3_y)], fill=(245, 158, 11, 255), width=16)

    def draw_node(x, y, radius, outer_col, core_col=(255, 255, 255)):
        # Halo
        draw.ellipse([x - radius - 14, y - radius - 14, x + radius + 14, y + radius + 14],
                     fill=(outer_col[0], outer_col[1], outer_col[2], 85))
        # Outer ring
        draw.ellipse([x - radius, y - radius, x + radius, y + radius],
                     fill=outer_col, outline=(255, 255, 255, 220), width=8)
        # Inner Core
        cr = max(6, radius - 16)
        draw.ellipse([x - cr, y - cr, x + cr, y + cr], fill=core_col)

    # Leaf Nodes
    draw_node(l1_x, l1_y, 38, (220, 38, 38))
    draw_node(l2_x, l2_y, 34, (245, 158, 11))
    draw_node(l3_x, l3_y, 34, (16, 185, 129))
    draw_node(l4_x, l4_y, 38, (37, 99, 235))

    # Tier 1 Nodes
    draw_node(t1_x, t1_y, 48, (239, 68, 68))
    draw_node(t2_x, t2_y, 48, (59, 130, 246))

    # Forest Root DC Node
    draw_node(r_x, r_y, 68, (14, 165, 233))

    # 5. Bold "AD" Monogram Text in Center
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    if not os.path.exists(font_path):
        font_path = "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"

    font_ad = ImageFont.truetype(font_path, 270)
    ad_text = "AD"
    bbox = draw.textbbox((0, 0), ad_text, font=font_ad)
    ad_w = bbox[2] - bbox[0]
    ad_h = bbox[3] - bbox[1]
    ad_x = cx - ad_w / 2
    ad_y = 960

    # Draw heavy dark outline
    for ox in [-8, -4, 0, 4, 8]:
        for oy in [-8, -4, 0, 4, 8]:
            draw.text((ad_x + ox, ad_y + oy), ad_text, font=font_ad, fill=(10, 14, 24, 255))
    # Crisp white fill
    draw.text((ad_x, ad_y), ad_text, font=font_ad, fill=(255, 255, 255, 255))

    # 6. Golden Vault Keyhole at Shield Bottom
    key_y = 1510
    draw.ellipse([cx - 28, key_y - 28, cx + 28, key_y + 28], fill=(245, 158, 11, 255))
    draw.polygon([(cx - 18, key_y), (cx + 18, key_y), (cx + 26, key_y + 52), (cx - 26, key_y + 52)],
                 fill=(245, 158, 11, 255))

    # Downsample using high-quality LANCZOS resampling
    final_img = img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return final_img

def export_all_icons(base_dir):
    base_dir = Path(base_dir)
    app_dir = base_dir / "app"

    print("🎨 Active Directory Vault Master Logo Üretiliyor...")
    master_1024 = create_ad_vault_icon(1024)
    master_512 = master_1024.resize((512, 512), Image.Resampling.LANCZOS)
    master_192 = master_1024.resize((192, 192), Image.Resampling.LANCZOS)

    # 1. In-App Assets
    img_dir = app_dir / "assets" / "images"
    img_dir.mkdir(parents=True, exist_ok=True)
    master_512.save(img_dir / "logo.png")
    print(f"  ✓ {img_dir / 'logo.png'}")

    # 2. Web Icons
    web_icons = app_dir / "web" / "icons"
    web_icons.mkdir(parents=True, exist_ok=True)
    master_192.save(web_icons / "Icon-192.png")
    master_192.save(web_icons / "Icon-maskable-192.png")
    master_512.save(web_icons / "Icon-512.png")
    master_512.save(web_icons / "Icon-maskable-512.png")
    master_1024.resize((64, 64), Image.Resampling.LANCZOS).save(app_dir / "web" / "favicon.png")
    print(f"  ✓ Web simgeleri güncellendi: {web_icons}")

    # 3. Android Launcher Mipmap Icons
    res_dir = app_dir / "android" / "app" / "src" / "main" / "res"
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, dim in sizes.items():
        target_folder = res_dir / folder
        target_folder.mkdir(parents=True, exist_ok=True)
        scaled = master_1024.resize((dim, dim), Image.Resampling.LANCZOS)
        target_path = target_folder / "ic_launcher.png"
        scaled.save(target_path)
        print(f"  ✓ Android {folder} ({dim}x{dim}): {target_path}")

    # Master preview copy in scripts
    master_512.save(base_dir / "scripts" / "master_icon_preview.png")
    print(f"✅ Tüm simgeler ve logolar başarıyla üretildi ve dağıtıldı!")

if __name__ == "__main__":
    current_dir = Path(__file__).resolve().parent.parent
    export_all_icons(current_dir)
