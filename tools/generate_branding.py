"""Generate SaveTrack branding from the SVG master with no extra dependencies.

Run from the repository root: py tools/generate_branding.py
The final step uses Flutter's own vector renderer for antialiased PNG exports.
Only absolute M/L/C/Q/Z SVG paths and solid fills/strokes are supported, so the
generated Flutter painter, SVG variants and Android vectors share geometry.
"""
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets/branding"
RES = ROOT / "android/app/src/main/res"
MASTER = BRAND / "savetrack-symbol.svg"
SVG = "{http://www.w3.org/2000/svg}"
EMERALD = "#073F34"
MINT = "#4BD4A8"
GOLD = "#F5C96A"
BACKGROUND = ("#073F34", "#13876D")
# A conservative circular safe zone, within Android's central 66/108 region.
ADAPTIVE_SCALE = .84


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def commands(data):
    values = re.findall(r"[A-Za-z]|-?\d+(?:\.\d+)?", data)
    arity = {"M": 2, "L": 2, "C": 6, "Q": 4, "Z": 0}
    i = 0
    while i < len(values):
        op = values[i]
        if op not in arity:
            raise ValueError(f"Unsupported path command: {op}")
        n = arity[op]
        yield op, values[i + 1:i + 1 + n]
        i += n + 1


def color(value):
    return f"Color(0xFF{value.lstrip('#')})"


def variant(tree, name, *, light=False, mono=False, background=False, adaptive=False):
    # Parse again to keep each variant independent of mutations.
    root = ET.fromstring(ET.tostring(tree))
    coin_rim = tree.find(f".//{SVG}path[@id='coin-rim']").get("d")
    for element in list(root.iter(f"{SVG}path")):
        if mono and element.get("id") in ("slot", "eye", "coin-rim"):
            parent = next(p for p in root.iter() if element in list(p))
            parent.remove(element)
            continue
        if mono and element.get("id") == "coin-face":
            element.set("d", element.get("d") + " " + coin_rim)
            element.set("fill-rule", "evenodd")
        for attr in ("fill", "stroke"):
            value = element.get(attr)
            if value and value != "none":
                if mono:
                    element.set(attr, EMERALD)
                elif light and value == MINT:
                    element.set(attr, EMERALD)
                elif light and value == EMERALD:
                    element.set(attr, "#DCF8EB")
    if adaptive:
        group = ET.Element(f"{SVG}g", {"transform": f"translate(512 512) scale({ADAPTIVE_SCALE}) translate(-512 -512)"})
        for child in list(root):
            if child.tag == f"{SVG}g":
                root.remove(child)
                group.append(child)
        root.append(group)
    if background:
        defs = ET.Element(f"{SVG}defs")
        grad = ET.SubElement(defs, f"{SVG}linearGradient", {
            "id": "aurora", "x1": "0", "y1": "0", "x2": "1024", "y2": "1024",
            "gradientUnits": "userSpaceOnUse",
        })
        for offset, tint in zip(("0", "1"), BACKGROUND):
            ET.SubElement(grad, f"{SVG}stop", {"offset": offset, "stop-color": tint})
        root.insert(0, defs)
        root.insert(1, ET.Element(f"{SVG}path", {
            "fill": "url(#aurora)", "d": "M 0 0 L 1024 0 L 1024 1024 L 0 1024 Z",
        }))
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    write(BRAND / name, ET.tostring(root, encoding="unicode") + "\n")


def dart_painter(tree):
    code = ["// GENERATED from assets/branding/savetrack-symbol.svg. Do not edit.",
            "// Regenerate with: py tools/generate_branding.py",
            "import 'package:flutter/material.dart';", "",
            "/// Identical geometry for in-app branding and raster exports.",
            "class SaveTrackLogoPainter extends CustomPainter {",
            "  const SaveTrackLogoPainter({this.light = false, this.monochrome = false,",
            "    this.coinProgress = 0, this.artworkScale = 1});",
            "  final bool light, monochrome;",
            "  final double coinProgress, artworkScale;", "",
            "  @override", "  void paint(Canvas canvas, Size size) {",
            "    canvas.save();",
            "    canvas.scale(size.width / 1024, size.height / 1024);",
            "    canvas.translate(512, 512);",
            "    canvas.scale(artworkScale);",
            "    canvas.translate(-512, -512);"]
    methods = {"M": "moveTo", "L": "lineTo", "C": "cubicTo", "Q": "quadraticBezierTo", "Z": "close"}
    for group in tree.findall(f"{SVG}g"):
        coin = group.get("id") == "coin"
        if coin:
            code += ["    canvas.save();", "    // The slot clips the coin as it enters; no route or startup delay.",
                     "    canvas.clipRect(const Rect.fromLTRB(0, 0, 1024, 378));",
                     "    canvas.translate(0, coinProgress * 300);"]
        for index, path in enumerate(group.findall(f"{SVG}path")):
            name = f"{group.get('id')}Path{index}"
            detail = path.get("id") in ("slot", "eye", "coin-rim")
            if detail:
                code.append("    if (!monochrome) {")
            code.append(f"    final {name} = Path()")
            ops = list(commands(path.get("d")))
            for pos, (op, args) in enumerate(ops):
                code.append(f"      ..{methods[op]}({', '.join(args)})" + (";" if pos == len(ops)-1 else ""))
            if path.get("id") == "coin-face":
                code += ["    if (monochrome) {", f"      {name}..fillType = PathFillType.evenOdd"]
                rim = list(commands(group.find(f"{SVG}path[@id='coin-rim']").get("d")))
                for pos, (op, args) in enumerate(rim):
                    code.append(f"        ..{methods[op]}({', '.join(args)})" + (";" if pos == len(rim)-1 else ""))
                code.append("    }")
            stroke = path.get("fill") == "none"
            tint = path.get("stroke" if stroke else "fill")
            if tint == MINT:
                expr = f"light ? {color(EMERALD)} : {color(MINT)}"
            elif tint == EMERALD:
                expr = f"light ? {color('#DCF8EB')} : {color(EMERALD)}"
            else:
                expr = color(tint)
            code += [f"    canvas.drawPath({name}, Paint()",
                     f"      ..color = monochrome ? {color(EMERALD)} : ({expr})"]
            if stroke:
                code += ["      ..style = PaintingStyle.stroke", f"      ..strokeWidth = {path.get('stroke-width')}"]
            code[-1] += ");"
            if detail:
                code.append("    }")
        if coin:
            code.append("    canvas.restore();")
    code += ["    canvas.restore();", "  }", "", "  @override",
             "  bool shouldRepaint(SaveTrackLogoPainter oldDelegate) =>",
             "    light != oldDelegate.light || monochrome != oldDelegate.monochrome ||",
             "    coinProgress != oldDelegate.coinProgress || artworkScale != oldDelegate.artworkScale;", "}"]
    write(ROOT / "lib/branding/savetrack_logo_painter.dart", "\n".join(code) + "\n")


def vector(tree, *, monochrome=False, scale=ADAPTIVE_SCALE, dp=108):
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             '<!-- Generated from savetrack-symbol.svg; py tools/generate_branding.py -->',
             '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
             f'    android:width="{dp}dp" android:height="{dp}dp"',
             '    android:viewportWidth="1024" android:viewportHeight="1024">',
             f'    <group android:pivotX="512" android:pivotY="512" android:scaleX="{scale}" android:scaleY="{scale}">']
    for path in tree.iter(f"{SVG}path"):
        if monochrome and path.get("id") in ("slot", "eye", "coin-rim"):
            continue
        data = path.get("d")
        if monochrome and path.get("id") == "coin-face":
            data += " " + tree.find(f".//{SVG}path[@id='coin-rim']").get("d")
            lines.append(f'        <path android:fillType="evenOdd" android:pathData="{data}"')
        else:
            lines.append(f'        <path android:pathData="{data}"')
        if path.get("fill") == "none":
            lines += [f'            android:fillColor="#00000000" android:strokeColor="{path.get("stroke")}"',
                      f'            android:strokeWidth="{path.get("stroke-width")}" />']
        else:
            tint = "#FFFFFF" if monochrome else path.get("fill")
            lines.append(f'            android:fillColor="{tint}" />')
    lines += ["    </group>", "</vector>"]
    return "\n".join(lines) + "\n"


def native_assets(tree):
    write(RES / "drawable/ic_launcher_foreground.xml", vector(tree))
    write(RES / "drawable/ic_launcher_monochrome.xml", vector(tree, monochrome=True))
    write(RES / "drawable/savetrack_splash.xml", vector(tree, scale=.92, dp=288))
    write(RES / "drawable/ic_launcher_background.xml", '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="1024" android:viewportHeight="1024">
    <path android:pathData="M 0 0 L 1024 0 L 1024 1024 L 0 1024 Z">
        <aapt:attr name="android:fillColor">
            <gradient android:type="linear" android:startX="0" android:startY="0"
                android:endX="1024" android:endY="1024"
                android:startColor="#073F34" android:endColor="#13876D" />
        </aapt:attr>
    </path>
</vector>
''')
    for version in (26, 33):
        mono = '\n    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />' if version == 33 else ""
        write(RES / f"mipmap-anydpi-v{version}/ic_launcher.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />{mono}
</adaptive-icon>
''')
    write(RES / "values/branding_colors.xml", '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="savetrack_emerald">#073F34</color>
</resources>
''')
    launch = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/savetrack_emerald" />
    <item android:width="160dp" android:height="160dp" android:gravity="center"
        android:drawable="@drawable/ic_launcher_foreground" />
</layer-list>
'''
    for folder in ("drawable", "drawable-v21"):
        write(RES / folder / "launch_background.xml", launch)
    # Android 12+ uses a static vector on an opaque background, without holding
    # the launch screen or changing the Flutter activity lifecycle.
    for folder, parent in (("values-v31", "Theme.Light.NoTitleBar"), ("values-night-v31", "Theme.Black.NoTitleBar")):
        write(RES / folder / "styles.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/{parent}">
        <item name="android:windowBackground">@color/savetrack_emerald</item>
        <item name="android:windowSplashScreenBackground">@color/savetrack_emerald</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/savetrack_splash</item>
    </style>
</resources>
''')


def main():
    tree = ET.parse(MASTER).getroot()
    if len(tree.findall(f"{SVG}g[@id='coin']")) != 1:
        raise ValueError("The master must contain exactly one coin group")
    variant(tree, "savetrack-light.svg", light=True)
    variant(tree, "savetrack-monochrome.svg", mono=True)
    variant(tree, "savetrack-icon.svg", background=True)
    variant(tree, "savetrack-adaptive-foreground.svg", adaptive=True)
    dart_painter(tree)
    native_assets(tree)
    flutter = shutil.which("flutter")
    if not flutter:
        raise SystemExit("Flutter must be on PATH to generate the PNG assets")
    subprocess.run([flutter, "test", "tools/render_branding.dart", "--reporter", "expanded"],
                   cwd=ROOT, check=True)
    subprocess.run([shutil.which("dart"), "format", "lib/branding/savetrack_logo_painter.dart"],
                   cwd=ROOT, check=True)
    print("Generated SVG variants, Flutter painter, Android vectors, and platform PNGs.")


if __name__ == "__main__":
    main()
