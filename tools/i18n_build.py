#!/usr/bin/env python3
"""Genera los archivos de idioma del juego a partir de las traducciones en tools/i18n/<código>.json.
Builds the game's language files from the translations in tools/i18n/<code>.json.

Cada JSON es {"CLAVE": "texto", ...} con las mismas claves que STRINGS en scripts/autoload/i18n.gd.
Each JSON is {"KEY": "text", ...} with the same keys as STRINGS in scripts/autoload/i18n.gd.

Uso / Usage:
    python3 tools/i18n_build.py            # todos / all
    python3 tools/i18n_build.py --check    # solo comprobar / check only

Comprueba que cada traducción conserva los marcadores del original (%d, %s, %.1f, [url=...],
saltos de línea...) y avisa de las claves que faltan (en el juego salen en inglés).
Checks that each translation keeps the original's placeholders (%d, %s, %.1f, [url=...], line
breaks...) and warns about missing keys (in the game they show in English).
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "i18n")
OUT = os.path.join(ROOT, "scripts", "autoload", "lang")
LANGS = ["pt", "fr", "ca", "zh"]

# Marcadores que tienen que seguir ahí / Placeholders that must survive
PH = re.compile(r"%[-+0#]*\d*(?:\.\d+)?[dsfixX%]|\[/?[a-z_]+(?:=[^\]]*)?\]|\{[a-z_0-9]+\}|\n")


def placeholders(text):
    return sorted(m for m in PH.findall(text) if m != "%%")


def source():
    """Las cadenas originales (español e inglés), leídas de i18n.gd / The original strings, read from i18n.gd."""
    path = os.path.join(SRC, "source.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def gd_literal(text):
    # json.dumps da un literal válido en GDScript (\" \\ \n \t \uXXXX)
    # json.dumps gives a valid GDScript literal (\" \\ \n \t \uXXXX)
    return json.dumps(text, ensure_ascii=False)


def build(lang, src, write=True):
    path = os.path.join(SRC, lang + ".json")
    if not os.path.exists(path):
        print(f"{lang}: sin traducción / no translation")
        return 0
    with open(path, encoding="utf-8") as f:
        tr = json.load(f)
    problems = 0
    missing = [k for k in src if k not in tr]
    extra = [k for k in tr if k not in src]
    for k, v in tr.items():
        if k not in src:
            continue
        want = placeholders(src[k]["en"])
        got = placeholders(v)
        if want != got:
            problems += 1
            print(f"  {lang} {k}: marcadores / placeholders {want} -> {got}")
    print(f"{lang}: {len(tr)} claves / keys, {len(missing)} faltan / missing, {len(extra)} sobran / extra, {problems} con marcadores distintos / with placeholder mismatches")
    for k in extra[:10]:
        print(f"  {lang} sobra / extra: {k}")
    if write:
        lines = [
            "extends RefCounted",
            f"## Traducción ({lang}), generada con tools/i18n_build.py desde tools/i18n/{lang}.json: no editar a mano.",
            f"## Translation ({lang}), built by tools/i18n_build.py from tools/i18n/{lang}.json: don't edit by hand.",
            "",
            "const STRINGS := {",
        ]
        for k in src:
            if k in tr:
                lines.append(f"\t{gd_literal(k)}: {gd_literal(tr[k])},")
        lines.append("}")
        with open(os.path.join(OUT, f"i18n_{lang}.gd"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    return problems


def main():
    check = "--check" in sys.argv
    langs = [a for a in sys.argv[1:] if not a.startswith("--")] or LANGS
    src = source()
    os.makedirs(OUT, exist_ok=True)
    bad = sum(build(lang, src, write=not check) for lang in langs)
    sys.exit(1 if bad and check else 0)


if __name__ == "__main__":
    main()
