# Altivex

Flutter / Dart 双平台高度计。主界面沿用参考图的渐变、圆形高度表及图标布局，默认使用设备数据；设置中可切换模拟模式进行界面对照。

## 软件示例

以下为 Android 模拟器运行截图，位置及传感器数值为测试数据，不代表真机测量精度；相机画面为模拟器虚拟场景。

| 高度计主界面 | 水印相机 |
| --- | --- |
| <img src="docs/images/altivex-main.png" alt="Altivex 高度计主界面" width="300"> | <img src="docs/images/altivex-camera.png" alt="Altivex 四角水印相机" width="300"> |

## 阶段归档

- `v0.1.0-demo`：模拟界面演示基线。
- `v0.2.0-stage2`：GPS、气压计、指南针、水印拍照、手动保存、分享及横竖屏适配；Android 已完成模拟器验证和部分真机验证，iOS 及室外精度仍待验收。
- 当前普通调试安装包：`build/altivex-live-debug.apk`；标准构建输出：`build/app/outputs/flutter-apk/app-debug.apk`。APK 和测试日志不纳入 Git。

## 当前功能

- GPS：Android 使用系统 LocationManager 以避免依赖 Google 定位增强服务；iOS 使用系统定位。前台定位、经纬度、平台定位高度、速度、水平/垂直精度；拒绝授权、永久拒绝、系统定位关闭及无定位提示。
- 气压计：显示 mmHg（主界面）及 hPa（设置）；气压高度公式 `44330 × (1 - (P/P0)^0.1903)`。未校准时使用 1013.25 hPa 标准参考值并明确标注；收到新鲜且水平、垂直精度均在 30 米内的 GPS 数据后自动校准，可在设置中重新校准。校准只在本次运行中保留。
- 指南针：融合方向驱动 N/S 标记，跨 0° 按最短角度平滑；缺失或数据过期时隐藏方向标记。
- 相机：独立实时预览、前后摄像头切换、设备支持范围内的圆形倍率按钮与双指变焦、右上角水滴水印开关、左上角返回箭头。底部依次为本次拍照页上一张照片、拍摄、镜头切换。拍摄后先预览，用户点击“保存相册”才写入相册；保存成功后禁用重复保存，支持系统分享。仅拍照片，不申请录音权限。
- 永久水印：按下快门时冻结一份不可变的海拔、气压、位置及时间快照，再解码照片、使用 Flutter Canvas 和文字阴影绘制，输出真正含水印像素的 PNG。预览中的水印不是最终保存方式。
- 取景与成片复用四角水印：左上“实时高度表”、右上气压、左下海拔、右下两行经纬度；白字加阴影，不绘制山形图或 Logo，不铺设时间及精度文字。预览页左上角返回、右上角分享，底部仅保存相册。倍率圆点直径 32，档位为 0.6×、1×、2×、3.2×，当前镜头不支持的档位隐藏。主界面横屏采用仪表盘在左、信息在右，操作行贴顶；横屏拍照时按钮与倍率保留在原设备底边对应的侧边，图标及数字转正。
- 缺失传感器时不使用模拟数据填充真实值；GPS 超过 30 秒、气压/方向超过 10 秒未更新时停止当作当前测量使用。
- 前后台切换释放并恢复传感器、定位和相机资源；相册保存失败时保留已生成照片，当前拍照页可重试保存或分享。

GPS 高度的基准由系统定位服务提供，目前没有做统一的大地水准面修正。气压高度会受天气及参考高度误差影响；GPS 校准阈值不代表保证达到该测量精度。无磁力计、无气压计、定位较粗或权限不足时会降级显示。应用不请求后台定位。

## 代码边界

- `lib/altimeter_reading.dart`：不可变测量快照、单位和坐标格式、气压/方向数学函数。
- `lib/measurement_hardware.dart`：跨平台插件适配及设备能力接口。
- `lib/altimeter_controller.dart`：订阅、权限状态、数据时效、平滑和校准。
- `lib/demo_altimeter.dart`：模拟模式入口，保留原 UI 演示基线。
- `lib/altimeter_page.dart`：主界面和设置。
- `lib/camera_access.dart`：Android 相机权限预检。
- `lib/photo_preview_page.dart`：相机生命周期、快门流程、相册保存和照片查看。
- `lib/photo_watermark.dart`：将拍摄快照绘制进照片像素。
- `lib/sharing.dart`：系统分享，含 iPad 弹出位置。

跨平台依赖：geolocator、sensors_plus、flutter_compass、camera、gal、path_provider、share_plus、permission_handler。permission_handler 只用于 Android 相机权限预检，规避 CameraX 在永久拒绝时持续重试；iOS 相机仍由 camera 插件请求权限。平台依赖版本由 `pubspec.lock` 固定。

## 开发与验证

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <Android设备ID>
flutter build apk --debug
```

SDK 未识别时：

```powershell
flutter config --android-sdk "D:\Android\Sdk"
flutter doctor --android-licenses
```

调试 APK：`build/app/outputs/flutter-apk/app-debug.apk`。Android 模拟器为 `Altivex_API_36`。真机开启 USB 调试并授权电脑连接后，用 `flutter devices` 获取设备 ID。

需要本地 HTTP/Mixed 代理时，可仅在当前 PowerShell 会话中设置：

```powershell
$env:HTTP_PROXY = 'http://127.0.0.1:7892'
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:JAVA_TOOL_OPTIONS = '-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7892 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7892'
```

Android Studio 的代理独立配置。本机曾用 `build/local-mirrors.gradle` 临时镜像脚本加速 Maven 下载，该脚本不属于源码必需文件；正常可访问官方仓库时直接使用标准 Flutter 构建命令。

## 硬件缺失验证

模拟器可能提供合成气压、方向、GPS 及虚拟相机，不能据此认定真机传感器正常。除模拟器本身关闭定位、拒绝权限的测试外，提供仅在 debug 生效的故障注入：

```powershell
flutter run --dart-define=ALTIVEX_DISABLE_HARDWARE=true -d <模拟器ID>
```

此模式主界面明确显示“硬件缺失测试”，GPS/气压/指南针/相机均返回不可用；真实值应显示 `--`、方向标记隐藏、拍照按钮禁用，仍可打开设置、重试和切换模拟模式。普通构建不启用此开关，release 构建也不会启用它。

测试包含数据过期、缺失硬件、权限拒绝/永久拒绝、定位服务关闭、校准精度门槛、指南针跨零、模式切换清理、不可变快照与永久水印像素检查。实际验证结果另见 `docs/第二阶段验证记录.md`。

## 真机验收

1. 允许/拒绝定位；关闭/重开系统定位；后台再恢复，确认状态及恢复正确。
2. 室外查看 GPS 海拔、位置、速度、精度；等待气压计数据和校准，转动手机观察 N/S，与设备传感器实际能力核对。
3. 相机允许/拒绝、切换摄像头、后台恢复；拍摄时移动，确认照片水印仍使用触发快门时的数据。
4. 在系统相册打开 PNG，确认水印永久存在、方向正确、中文字清晰；拒绝相册权限后在拍摄页重试保存或分享。
5. 断网后测试设备 GPS/传感器/拍摄；首次定位可能更慢，不应将缺失数据冒充为真实值。

iOS 的权限说明已配置，部署目标为 iOS 15；Windows 无法执行 iOS 构建，需在 macOS/Xcode 编译并验证定位、运动权限、照片方向、相册及 iPad 分享。应用 ID 暂为 `com.example.altivex`，正式发布前需确定签名和最终 ID。
