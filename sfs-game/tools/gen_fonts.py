#!/usr/bin/env python3
"""gen_fonts.py — 按工程实际用字裁剪/实例化字体
用法: python3 tools/gen_fonts.py
"""
import os
import string
from fontTools.ttLib import TTFont
from fontTools import subset
from fontTools.varLib import instancer

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJ, "assets", "fonts")
SRC_LATIN = "/root/dl/fonts2"
SRC_CN = "/root/dl/fonts/NotoSansSC.ttf"

SKIP_DIRS = ("/.godot", "/android/", "/build/", "/launcher_icons/", "/assets/")


def collect_chars():
    chars = set(string.ascii_letters + string.digits + string.punctuation + " ")
    for root, _dirs, files in os.walk(PROJ):
        if any(s in root + "/" for s in SKIP_DIRS):
            continue
        for fn in files:
            if not fn.endswith((".gd", ".tscn", ".godot", ".cfg")):
                continue
            try:
                text = open(os.path.join(root, fn), encoding="utf-8").read()
            except Exception:
                continue
            for ch in text:
                o = ord(ch)
                if (0x2000 <= o <= 0x206F or 0x2190 <= o <= 0x21FF
                        or 0x25A0 <= o <= 0x25FF or 0x3000 <= o <= 0x30FF
                        or 0x4E00 <= o <= 0x9FFF or 0xFE30 <= o <= 0xFE4F
                        or 0xFF00 <= o <= 0xFFEF
                        or o in (0x2022, 0x2026, 0x00B7, 0x2014, 0x00D7, 0x00B0,
                                 0x221E, 0x221A, 0x2248, 0x2264, 0x2265, 0x00B1,
                                 0x2039, 0x203A, 0x00A0)):
                    chars.add(ch)
    # 保险：界面必用符号
    chars.update("×÷°∞≈≤≥±√‰→←↑↓↔↺↻⟲⟳—–…·•※§¶†‡€$¥£%‰①②③④⑤⑥⑦⑧⑨⑩")
    chars.update("0123456789.,:;!?()[]{}+-=*/<>|&@#^~_\"'\\ ")
    return "".join(sorted(chars))


def build(src, out_name, wght, glyph_text, keep_hinting=False):
    out = os.path.join(OUT, out_name)
    font = TTFont(src, fontNumber=0)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(
            font, {"wght": wght}, inplace=False, updateFontNames=False)
    tmp = out + ".tmp"
    font.save(tmp)
    args = [tmp, "--text=" + glyph_text, "--output-file=" + out,
            "--layout-features=*", "--desubroutinize", "--drop-tables+=DSIG"]
    if not keep_hinting:
        args.append("--no-hinting")
    subset.main(args)
    os.remove(tmp)
    print("  %-28s wght=%-4s %8d bytes" % (out_name, wght, os.path.getsize(out)))


def main():
    os.makedirs(OUT, exist_ok=True)
    cn = collect_chars()
    print("unique chars:", len(cn))
    # 中文：思源黑体三个字重（保留 hinting，小字号更锐利）
    for w, name in ((400, "NotoSansSC-Regular.ttf"),
                    (500, "NotoSansSC-Medium.ttf"),
                    (700, "NotoSansSC-Bold.ttf")):
        build(SRC_CN, name, w, cn, keep_hinting=True)
    # 拉丁：Oxanium（标题/Logo）+ JetBrains Mono（HUD 数字）
    latin = "".join(sorted(
        set(string.ascii_letters + string.digits + string.punctuation)
        | set("×°∞←→↑↓↺↻—…·•%+-=<>/.,:;()[]{}\"'|&@#^~_!? ")))
    build(os.path.join(SRC_LATIN, "Oxanium[wght].ttf"), "Oxanium-Bold.ttf", 700, latin)
    build(os.path.join(SRC_LATIN, "Oxanium[wght].ttf"), "Oxanium-SemiBold.ttf", 600, latin)
    build(os.path.join(SRC_LATIN, "JetBrainsMono[wght].ttf"),
          "JetBrainsMono-Medium.ttf", 500, latin)


if __name__ == "__main__":
    main()
