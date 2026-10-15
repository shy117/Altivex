# Altivex

Android / iOS 高度计界面 Demo，使用 Flutter 编写。

当前功能：圆形仪表盘、每秒更新的模拟高度、m/ft 切换、模拟气压、GPS 未接入状态。无定位权限及真实传感器接入，数据仅用于离线界面演示。

## 目录

- `lib/main.dart`：应用入口及主题。
- `lib/altimeter_page.dart`：高度计界面与仪表绘制。
- `lib/demo_altimeter.dart`：模拟数据及定时器生命周期。

## 开发与验证

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <Android设备ID>
flutter build apk --debug
```

调试 APK：`build/app/outputs/flutter-apk/app-debug.apk`。

优先在 Android Studio 的 Device Manager 启动模拟器，再运行 `flutter devices` 获取设备 ID。真机需要开启 USB 调试，并在手机上批准电脑连接。

若 SDK 未识别：

```powershell
flutter config --android-sdk "D:\Android\Sdk"
flutter doctor --android-licenses
```

需要通过本地 HTTP/Mixed 代理构建时，在当前 PowerShell 会话设置：

```powershell
$env:HTTP_PROXY = 'http://127.0.0.1:7892'
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:JAVA_TOOL_OPTIONS = '-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7892 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7892'
```

关闭窗口后代理环境变量失效。Android Studio 的代理需在 IDE 中独立配置。

iOS 工程已生成，需要后续在 macOS/Xcode 中构建和验证。应用 ID 暂为 `com.example.altivex`，正式发布前确定最终 ID 和签名方案。

## 参考 UI 与后续功能边界

第一阶段按参考图实现青蓝到青绿、橙黄、红橙的全屏渐变；顶部设置、标题、分享和相机入口；浅绿半透明圆环、橙红渐变圆盘、N/S 标记、大字号高度、速度及底部两行经纬度。所有数值均为模拟，单位切换位于设置中。

拍照页目前仅为布局示意，没有摄像头画面、照片输出、相册保存或系统分享。示意页接收不可变数据快照用于验证页面隔离，不代表真实拍摄流程。

第二阶段要求：接入 GPS、气压计和磁力计/姿态传感器；指南针角度驱动 N/S 标记；相机页实时预览，快门触发时冻结海拔、气压、经纬度及时间，再将这份快照绘制到原始照片像素中。异步编码和保存期间不得重新读取定位。水印为白色加阴影，输出照片需验证水印已永久嵌入，并处理权限拒绝、无定位、缺少传感器、相机生命周期及照片方向。
