#!/usr/bin/env python3
"""
Active Directory Rehberi - İçerik Çıkarıcı ve İndeksleyici
Bu betik:
- '1-Sistem_Yoneticisi', '2-Blue_Team' ve '3-Red_Team' dizinlerini tarar.
- Orijinal dosyalara ASLA dokunmaz.
- Tüm modül ve konu hiyerarşisini, başlıkları, özetleri, etiketleri ve markdown içeriklerini
  çıkartarak tek bir optimize edilmiş 'app/assets/data/content.json' dosyasına yazar.
- Yeni markdown içeriği eklendiğinde bu betiğin çalıştırılması (veya 'build.sh' çalıştırılması) yeterlidir.
"""

import os
import re
import json
import hashlib
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

PILLARS = [
    {
        "id": "red_team",
        "dir": "3-Red_Team",
        "name": "Red Team (Ofansif)",
        "subtitle": "Saldırı Teknikleri, Operasyonel Cephanelik & Modüller",
        "icon": "shield-cross",
        "color": "#ef4444"  # Red
    },
    {
        "id": "blue_team",
        "dir": "2-Blue_Team",
        "name": "Blue Team (Defansif)",
        "subtitle": "Tespit Mühendisliği, Savunma, Sertleştirme & Loglar",
        "icon": "shield-check",
        "color": "#3b82f6"  # Blue
    },
    {
        "id": "sistem_yoneticisi",
        "dir": "1-Sistem_Yoneticisi",
        "name": "Sistem Yöneticisi (Altyapı)",
        "subtitle": "Active Directory Mimarisi, Yönetim & Temeller",
        "icon": "server",
        "color": "#10b981"  # Emerald / Green
    }
]

def clean_title(raw_title: str) -> str:
    """Temiz ve okunabilir başlık üretir."""
    # Başındaki Markdown # işaretlerini kaldır
    title = re.sub(r"^#+\s*", "", raw_title).strip()
    return title

def extract_metadata(markdown_text: str, filename: str):
    """Markdown metninden başlık, açıklama ve arama etiketlerini çıkarır."""
    lines = markdown_text.splitlines()
    title = ""
    description = ""
    category = ""
    
    for line in lines:
        stripped = line.strip()
        if not title and stripped.startswith("# "):
            title = clean_title(stripped)
        elif not description and stripped.startswith("> **Tanım:**"):
            match = re.search(r">\s*\*\*Tanım:\*\*\s*(.*)", stripped)
            if match:
                description = match.group(1).strip()
        elif not category and stripped.startswith("> **Kategori:**"):
            match = re.search(r">\s*\*\*Kategori:\*\*\s*\[?([^\]]+)\]?", stripped)
            if match:
                category = match.group(1).strip()
                
    if not title:
        # Dosya adından başlık türet
        base_name = Path(filename).stem
        title = base_name.replace("_", " ").title()

    if not description:
        # İlk anlamlı paragrafı bul
        for line in lines:
            stripped = line.strip()
            if stripped and not stripped.startswith("#") and not stripped.startswith(">") and not stripped.startswith("-") and not stripped.startswith("```"):
                description = stripped[:200]
                break

    # Basit arama anahtarları oluştur
    search_text = f"{title} {description} {category} {filename}".lower()
    
    return title, description, category, search_text

def format_module_title(dir_name: str) -> str:
    """Modul_01_Mimari_ve_Temeller -> Modül 01: Mimari ve Temeller"""
    match = re.match(r"Modul_(\d+)_(.*)", dir_name)
    if match:
        num, rest = match.groups()
        readable_rest = rest.replace("_", " ")
        return f"Modül {num}: {readable_rest}"
    return dir_name.replace("_", " ")

def format_category_title(dir_name: str) -> str:
    """01_Ag_ve_Port_Tarama -> 01. Ağ ve Port Tarama"""
    match = re.match(r"(\d+)_(.*)", dir_name)
    if match:
        num, rest = match.groups()
        readable_rest = rest.replace("_", " ")
        return f"{num}. {readable_rest}"
    return dir_name.replace("_", " ")

def scan_repository():
    hierarchy = []
    all_articles = []
    stats = {
        "total_pillars": len(PILLARS),
        "total_modules": 0,
        "total_subcategories": 0,
        "total_articles": 0,
        "total_lines": 0,
        "total_words": 0
    }

    for pillar_cfg in PILLARS:
        pillar_path = BASE_DIR / pillar_cfg["dir"]
        if not pillar_path.exists():
            continue

        pillar_obj = {
            "id": pillar_cfg["id"],
            "name": pillar_cfg["name"],
            "subtitle": pillar_cfg["subtitle"],
            "dir": pillar_cfg["dir"],
            "color": pillar_cfg["color"],
            "featured_articles": [],
            "modules": []
        }

        # Modülleri sırala
        module_dirs = sorted([d for d in pillar_path.iterdir() if d.is_dir() and d.name.startswith("Modul_")])
        
        for mod_dir in module_dirs:
            stats["total_modules"] += 1
            mod_title = format_module_title(mod_dir.name)
            
            module_obj = {
                "id": f"{pillar_cfg['id']}_{mod_dir.name}",
                "folder": mod_dir.name,
                "title": mod_title,
                "path": str(mod_dir.relative_to(BASE_DIR)),
                "has_subcategories": False,
                "subcategories": [],
                "articles": []
            }

            # Modül README'si varsa
            mod_readme = mod_dir / "README.md"
            if mod_readme.exists():
                content = mod_readme.read_text(encoding="utf-8", errors="ignore")
                title, desc, cat, search_text = extract_metadata(content, "README.md")
                art_id = hashlib.md5(f"{mod_dir.name}/README.md".encode()).hexdigest()[:10]
                art_item = {
                    "id": art_id,
                    "title": f"📋 {mod_title} - Genel Bakış",
                    "description": desc or f"{mod_title} kapsam ve konu özeti",
                    "path": str(mod_readme.relative_to(BASE_DIR)),
                    "filename": "README.md",
                    "pillar_id": pillar_cfg["id"],
                    "module_id": module_obj["id"],
                    "category": "Genel Bakış",
                    "content": content,
                    "search_text": search_text,
                    "is_readme": True
                }
                module_obj["articles"].append({
                    "id": art_id,
                    "title": art_item["title"],
                    "description": art_item["description"],
                    "path": art_item["path"],
                    "is_readme": True
                })
                all_articles.append(art_item)
                stats["total_articles"] += 1
                stats["total_lines"] += len(content.splitlines())
                stats["total_words"] += len(content.split())

            # Alt dizinler var mı? (Örn. Modül 11 Araç kategorileri)
            sub_dirs = sorted([d for d in mod_dir.iterdir() if d.is_dir() and not d.name.startswith(".")])
            
            if sub_dirs:
                module_obj["has_subcategories"] = True
                for sub_dir in sub_dirs:
                    stats["total_subcategories"] += 1
                    sub_title = format_category_title(sub_dir.name)
                    subcat_obj = {
                        "id": f"{module_obj['id']}_{sub_dir.name}",
                        "folder": sub_dir.name,
                        "title": sub_title,
                        "path": str(sub_dir.relative_to(BASE_DIR)),
                        "articles": []
                    }

                    # Subcat içindeki markdown dosyaları
                    md_files = sorted([f for f in sub_dir.glob("*.md")])
                    
                    # README'yi başa al
                    md_files.sort(key=lambda x: (0 if x.name.lower() == "readme.md" else 1, x.name))

                    for md_file in md_files:
                        content = md_file.read_text(encoding="utf-8", errors="ignore")
                        title, desc, cat, search_text = extract_metadata(content, md_file.name)
                        art_id = hashlib.md5(f"{sub_dir.name}/{md_file.name}".encode()).hexdigest()[:10]
                        is_readme = md_file.name.lower() == "readme.md"

                        art_item = {
                            "id": art_id,
                            "title": title,
                            "description": desc,
                            "path": str(md_file.relative_to(BASE_DIR)),
                            "filename": md_file.name,
                            "pillar_id": pillar_cfg["id"],
                            "module_id": module_obj["id"],
                            "subcategory_id": subcat_obj["id"],
                            "category": cat or sub_title,
                            "content": content,
                            "search_text": search_text,
                            "is_readme": is_readme
                        }
                        subcat_obj["articles"].append({
                            "id": art_id,
                            "title": title,
                            "description": desc,
                            "path": art_item["path"],
                            "is_readme": is_readme
                        })
                        all_articles.append(art_item)
                        stats["total_articles"] += 1
                        stats["total_lines"] += len(content.splitlines())
                        stats["total_words"] += len(content.split())

                    module_obj["subcategories"].append(subcat_obj)
            else:
                # Doğrudan modül içindeki .md dosyaları
                md_files = sorted([f for f in mod_dir.glob("*.md") if f.name.lower() != "readme.md"])
                for md_file in md_files:
                    content = md_file.read_text(encoding="utf-8", errors="ignore")
                    title, desc, cat, search_text = extract_metadata(content, md_file.name)
                    art_id = hashlib.md5(f"{mod_dir.name}/{md_file.name}".encode()).hexdigest()[:10]

                    art_item = {
                        "id": art_id,
                        "title": title,
                        "description": desc,
                        "path": str(md_file.relative_to(BASE_DIR)),
                        "filename": md_file.name,
                        "pillar_id": pillar_cfg["id"],
                        "module_id": module_obj["id"],
                        "category": mod_title,
                        "content": content,
                        "search_text": search_text,
                        "is_readme": False
                    }
                    module_obj["articles"].append({
                        "id": art_id,
                        "title": title,
                        "description": desc,
                        "path": art_item["path"],
                        "is_readme": False
                    })
                    all_articles.append(art_item)
                    stats["total_articles"] += 1
                    stats["total_lines"] += len(content.splitlines())
                    stats["total_words"] += len(content.split())

            pillar_obj["modules"].append(module_obj)
        
        # Pillar kökündeki doğrudan .md dosyaları (Örn: 3-Red_Team/PLAYBOOK.md)
        root_md_files = sorted([f for f in pillar_path.glob("*.md") if f.name.lower() != "readme.md"])
        for r_file in root_md_files:
            content = r_file.read_text(encoding="utf-8", errors="ignore")
            title, desc, cat, search_text = extract_metadata(content, r_file.name)
            art_id = hashlib.md5(f"{pillar_cfg['dir']}/{r_file.name}".encode()).hexdigest()[:10]
            art_item = {
                "id": art_id,
                "title": title or r_file.stem.replace('_', ' '),
                "description": desc or f"{pillar_cfg['name']} özel rehberi ve oyun kitabı",
                "path": str(r_file.relative_to(BASE_DIR)),
                "filename": r_file.name,
                "pillar_id": pillar_cfg["id"],
                "module_id": f"{pillar_cfg['id']}_root",
                "category": cat or "Oyun Kitabı & Genel",
                "content": content,
                "search_text": search_text,
                "is_readme": False
            }
            pillar_obj["featured_articles"].append({
                "id": art_id,
                "title": art_item["title"],
                "description": art_item["description"],
                "path": art_item["path"],
                "is_readme": False
            })
            all_articles.append(art_item)
            stats["total_articles"] += 1
            stats["total_lines"] += len(content.splitlines())
            stats["total_words"] += len(content.split())
        
        hierarchy.append(pillar_obj)

    return hierarchy, all_articles, stats

def export_content(output_dir: Path):
    output_dir.mkdir(parents=True, exist_ok=True)
    hierarchy, all_articles, stats = scan_repository()

    # 1. Hiyerarşi yapısı (Navigasyon için hafif veri)
    hierarchy_file = output_dir / "hierarchy.json"
    hierarchy_file.write_text(json.dumps(hierarchy, ensure_ascii=False, indent=2), encoding="utf-8")

    # 2. Hızlı Arama İndeksi (Başlıklar, yollar, açıklamalar)
    search_index = [
        {
            "id": a["id"],
            "title": a["title"],
            "description": a["description"],
            "category": a.get("category", ""),
            "path": a["path"],
            "pillar_id": a["pillar_id"],
            "module_id": a["module_id"],
            "is_readme": a.get("is_readme", False),
            "search_text": a["search_text"]
        }
        for a in all_articles
    ]
    search_file = output_dir / "search_index.json"
    search_file.write_text(json.dumps(search_index, ensure_ascii=False, indent=2), encoding="utf-8")

    # 3. Tüm Makaleler Sözlüğü (ID -> Makale detayları ve tam markdown içeriği)
    articles_dict = {a["id"]: a for a in all_articles}
    articles_file = output_dir / "articles.json"
    articles_file.write_text(json.dumps(articles_dict, ensure_ascii=False), encoding="utf-8")

    # 4. İstatistikler
    stats_file = output_dir / "stats.json"
    stats_file.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"✅ İndeksleme Tamamlandı!")
    print(f"📊 Toplam Sütun (Pillars): {stats['total_pillars']}")
    print(f"📁 Toplam Modül: {stats['total_modules']}")
    print(f"📂 Toplam Alt Kategori: {stats['total_subcategories']}")
    print(f"📄 Toplam Doküman/Makale: {stats['total_articles']}")
    print(f"📝 Toplam Satır: {stats['total_lines']:,}")
    print(f"📖 Toplam Kelime: {stats['total_words']:,}")
    print(f"💾 Çıktı Dizini: {output_dir}")

if __name__ == "__main__":
    import sys
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else (BASE_DIR / "app" / "assets" / "data")
    export_content(target)
