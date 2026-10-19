#!/usr/bin/env python3
"""使用 Inkscape 将品牌 SVG 按完整画布导出为多尺寸白底或透明 PNG。"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
from pathlib import Path


DEFAULT_SIZES = (32, 48, 64, 72, 96, 128, 144, 192, 256, 384, 512, 1024)


def find_inkscape(explicit_path: str | None) -> str:
    candidates = [explicit_path] if explicit_path else []
    discovered = shutil.which("inkscape")
    if discovered:
        candidates.append(discovered)
    candidates.extend([
        r"D:\Program Files\Inkscape\bin\inkscape.com",
        r"C:\Program Files\Inkscape\bin\inkscape.com",
        r"C:\Program Files\Inkscape\bin\inkscape.exe",
    ])
    for candidate in candidates:
        if Path(candidate).is_file():
            return str(Path(candidate).resolve())
    raise SystemExit("未找到 Inkscape，请通过 --inkscape 指定程序路径。")


def parse_sizes(value: str) -> tuple[int, ...]:
    try:
        sizes = tuple(dict.fromkeys(int(part.strip()) for part in value.split(",")))
    except ValueError as error:
        raise argparse.ArgumentTypeError("尺寸必须是逗号分隔的整数。") from error
    if not sizes or any(size < 1 or size > 4096 for size in sizes):
        raise argparse.ArgumentTypeError("尺寸必须在 1 到 4096 之间。")
    return sizes


def render_png(
    inkscape: str, source: Path, target: Path, size: int, background: str
) -> None:
    subprocess.run([
        inkscape,
        str(source),
        "--export-type=png",
        "--export-area-page",
        "--export-background=#FFFFFF",
        f"--export-background-opacity={0 if background == 'transparent' else 1}",
        f"--export-filename={target}",
        f"--export-width={size}",
        f"--export-height={size}",
    ], check=True, timeout=60)
    with target.open("rb") as image:
        header = image.read(24)
    if (len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n"
            or header[12:16] != b"IHDR"
            or struct.unpack(">II", header[16:24]) != (size, size)):
        raise RuntimeError(f"生成图片格式或尺寸不正确：{target}")


def main() -> int:
    directory = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--svg", type=Path, default=directory / "altivex-logo.svg")
    parser.add_argument("--out-dir", type=Path, default=directory / "generated")
    parser.add_argument("--sizes", type=parse_sizes, default=DEFAULT_SIZES)
    parser.add_argument("--inkscape", help="指定 Inkscape 命令行程序路径。")
    parser.add_argument("--background", choices=("white", "transparent"),
                        default="white", help="背景模式，默认不透明白底。")
    args = parser.parse_args()
    source, output = args.svg.resolve(), args.out_dir.resolve()
    if not source.is_file():
        parser.error(f"SVG 源文件不存在：{source}")
    inkscape = find_inkscape(args.inkscape)
    output.mkdir(parents=True, exist_ok=True)
    for size in args.sizes:
        target = output / f"{source.stem}-{args.background}-{size}.png"
        render_png(inkscape, source, target, size, args.background)
        print(f"已生成 {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
