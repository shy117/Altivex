# 照片水印 Logo

- 原始彩色设计：`altivex-logo.svg`，保持不变。
- 水印矢量版本：`altivex-logo-white.svg`，仅将填充与描边改成白色，保留原轮廓和透明背景。
- 应用使用：`generated/altivex-logo-white-512.png`，按实际图形边界裁去空白，避免与文字并排时标志过小。

重新导出（Inkscape）：

```powershell
inkscape altivex-logo-white.svg --export-area-drawing --export-width=512 --export-filename=generated/altivex-logo-white-512.png
```

四套模板均在左上角使用“标志 + 小间距 + Altivex 高度计”的组合。标志宽度约为文字字号的 1.8 倍，垂直居中，并增加轻微暗色阴影；取景与成片共用同一张透明图片和绘制逻辑。
