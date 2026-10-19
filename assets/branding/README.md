# 品牌图片资源

- `altivex-logo.svg`：透明背景品牌源图，保留山形、聚焦框、配色和原有留白。
- `generate_logo_images.py`：使用 Inkscape 导出白底或透明 PNG，不修改源图。
- `generated/altivex-logo-white-尺寸.png`：完整方形画布、不透明白色背景，不预裁圆角。
- `generated/altivex-logo-transparent-尺寸.png`：完整方形画布，背景与山体留白透明。

默认尺寸：32、48、64、72、96、128、144、192、256、384、512、1024 像素。

在项目根目录运行（需要 Python 3.10+ 和 Inkscape）：

```powershell
python assets/branding/generate_logo_images.py
```

导出同样尺寸的透明图片（与白底图片分别命名，不相互覆盖）：

```powershell
python assets/branding/generate_logo_images.py --background transparent
```

也可以通过 `--sizes 48,192,1024` 指定尺寸，通过 `--inkscape` 指定 Inkscape 路径。
重新运行会更新对应的生成图片，原始 SVG 保持不变。

Android 启动图标使用这些品牌资源；`generate_android_icons.py` 生成传统图标和自适应图标前景。

主界面资源：`altivex-logo-dark.svg` 从原始 SVG 仅调整山峰颜色，保留橙色聚焦框与全部路径；`generated/home-logo-light.png` 和 `generated/home-logo-dark.png` 使用绘图边界导出，仅用于主界面。水印相机继续使用独立的白色水印资源。
