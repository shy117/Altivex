#!/usr/bin/env python3
"""从已导出的品牌图片与 SVG 生成 Android 图标，不修改品牌源图。"""

from pathlib import Path
import shutil
import xml.etree.ElementTree as ET


def main() -> None:
    branding = Path(__file__).resolve().parent
    res = branding.parents[1] / "android/app/src/main/res"
    for density, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)]:
        shutil.copyfile(branding / f"generated/altivex-logo-white-{size}.png",
                        res / f"mipmap-{density}/ic_launcher.png")
    android = "http://schemas.android.com/apk/res/android"
    ET.register_namespace("android", android)
    def attributes(**values: str) -> dict[str, str]:
        return {f"{{{android}}}{key}": value for key, value in values.items()}
    vector = ET.Element("vector", attributes(width="108dp", height="108dp",
        viewportWidth="768", viewportHeight="768"))
    # Insets preserve the complete mountain under circular and rounded masks.
    group = ET.SubElement(vector, "group", attributes(translateX="128", translateY="128"))
    source = ET.parse(branding / "altivex-logo.svg").getroot()
    for source_group in source.findall("{http://www.w3.org/2000/svg}g"):
        for path in source_group.findall("{http://www.w3.org/2000/svg}path"):
            values = {"pathData": path.attrib["d"], "fillColor": source_group.get("fill", "#00000000")}
            if "stroke" in source_group.attrib:
                values.update(strokeColor=source_group.attrib["stroke"],
                    strokeWidth=source_group.attrib["stroke-width"], strokeLineJoin="round")
            ET.SubElement(group, "path", attributes(**values))
    ET.indent(vector)
    ET.ElementTree(vector).write(res / "drawable/ic_launcher_foreground.xml",
        encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
