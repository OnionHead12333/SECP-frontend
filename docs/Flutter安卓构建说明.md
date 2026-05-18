# Flutter Android 构建说明

## 背景

当前项目在 Windows 上构建 Android 版本时，最容易踩到的坑不是业务代码，而是 Flutter / Gradle / Kotlin 对中文用户目录的兼容问题。

本机用户名为 `张博龙`，默认的 Pub 缓存路径通常是：

```text
C:\Users\张博龙\AppData\Local\Pub\Cache
```

Flutter 生成 Android 插件元数据后，Gradle / Kotlin 在某些阶段会把这段路径错误处理成类似下面的形式：

```text
C:\Users\u5F20\u535A\u9F99\...
```

或者：

```text
C:\Users\寮犲崥榫橽\...
```

这会导致插件源码、依赖 jar 或 Kotlin 增量编译缓存定位失败，最终表现为 `flutter run` 或 `gradlew` 在 Android 编译阶段报错。

## 这类问题的典型报错

如果看到下面这些特征，基本可以直接判断是缓存路径问题：

```text
Execution failed for task ':flutter_tts:compileDebugKotlin'
Execution failed for task ':package_info_plus:compileDebugKotlin'
Execution failed for task ':sensors_plus:compileDebugKotlin'
source file or directory not found
this and base files have different roots
```

尤其要注意日志里是否出现下面这类异常路径：

```text
C:\Users\u5F20\u535A\u9F99\...
C:\Users\寮犲崥榫橽\...
```

## 根因总结

问题核心不是某个 Flutter 插件版本坏了，而是：

1. 当前终端没有显式设置 `PUB_CACHE`
2. Flutter 默认回退到 `C:\Users\张博龙\AppData\Local\Pub\Cache`
3. Android 构建链在处理中文路径时出错
4. 生成文件和构建缓存里留下了错误路径
5. 后续即使配置改对，旧缓存也可能继续污染编译

## 当前仓库里的约定

项目里已经增加了一个辅助脚本：

```text
mobile\flutterw.cmd
```

脚本内容很简单，只做一件事：

```cmd
set "PUB_CACHE=E:\.pub-cache"
flutter %*
```

也就是说，在这个项目里推荐不要直接执行 `flutter`，而是执行 `flutterw.cmd`。

## 推荐日常用法

进入移动端目录后，优先使用：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd pub get
.\flutterw.cmd run
```

如果只是构建 APK，也可以：

```powershell
.\flutterw.cmd build apk
```

## 先确认自己在正确的项目目录

这个项目里容易把两个目录名看混：

```text
E:\SECP-frontend      前端仓库，Flutter 项目在这里
E:\SCEP-backend       后端仓库，Spring Boot 项目在这里
```

注意 `SECP` 和 `SCEP` 字母顺序不同。执行 Flutter 命令前，应该先进入：

```powershell
cd E:\SECP-frontend\mobile
```

这个目录必须能看到下面这些文件或目录：

```text
pubspec.yaml
lib\main.dart
android\
ios\
packages\
flutterw.cmd
```

其中 `pubspec.yaml` 是 Flutter 识别项目根目录的关键文件。没有它，当前目录就不是可执行的 Flutter 工程根。

## 拉取代码后的推荐流程

每次 `git pull` 之后，建议按下面顺序处理：

1. 进入 `mobile` 目录
2. 执行 `.\flutterw.cmd pub get`
3. 直接执行 `.\flutterw.cmd run`

通常到这里就够了。

## 如果报 Expected to find project root

如果执行：

```powershell
flutter pub get
```

或者：

```powershell
.\flutterw.cmd pub get
```

看到下面的错误：

```text
Expected to find project root in current working directory.
```

优先检查两件事：

1. 当前目录是不是 `E:\SECP-frontend\mobile`
2. 当前目录下有没有 `pubspec.yaml`

可以执行：

```powershell
Get-Location
Get-ChildItem
```

如果你在 `mobile` 目录里，但只看到：

```text
flutterw.cmd
packages\
```

而没有 `pubspec.yaml`、`lib\`、`android\`，说明 Flutter 工程主体被误删或没有恢复完整。这时不要执行 `flutter create`，也不要把 `cd <flutter-project-root>` 当成真实命令输入。

先回到前端仓库根目录，用 Git 恢复 `mobile`：

```powershell
cd E:\SECP-frontend
git restore mobile
```

恢复后再进入移动端目录拉依赖：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd pub get
```

如果 `pub get` 能正常输出 `Changed xxx dependencies!`，说明 Flutter 项目根已经恢复正常。

## 如果拉取后又开始报 Kotlin / Gradle 路径错误

优先按下面步骤处理：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd pub get
```

如果还是报下面这种错误：

```text
compileDebugKotlin
source file or directory not found
different roots
```

说明旧缓存还在，继续做一次清理：

```powershell
Remove-Item -LiteralPath E:\SECP-frontend\mobile\build -Recurse -Force
Remove-Item -LiteralPath E:\SECP-frontend\mobile\android\.gradle -Recurse -Force
.\flutterw.cmd pub get
.\flutterw.cmd run
```

## 如何快速确认当前是否走的是 E 盘缓存

可以检查下面两个生成文件：

```text
mobile\.dart_tool\package_config.json
mobile\.flutter-plugins-dependencies
```

如果内容里出现：

```text
E:\.pub-cache
```

说明当前 Flutter 元数据是正常的。

如果仍然出现：

```text
C:\Users\张博龙\AppData\Local\Pub\Cache
```

说明当前终端没有正确使用 `PUB_CACHE`，或者之前的生成文件还没刷新。

## 可选的一次性系统配置

如果希望以后所有新开的终端默认都走 E 盘缓存，可以执行一次：

```powershell
setx PUB_CACHE E:\.pub-cache
```

执行后需要关闭并重新打开终端窗口。

即便设置了全局环境变量，这个项目里仍然建议优先用：

```powershell
.\flutterw.cmd run
```

这样最稳，不容易受外部环境影响。

## 不要手工修改的生成目录

下面这些文件或目录是构建生成物，不要手改：

```text
mobile\.dart_tool\
mobile\.flutter-plugins-dependencies
mobile\build\
mobile\android\.gradle\
```

它们出问题时，正确做法是删除后重新生成，不是直接改里面的路径。

## 后端和前端联调启动顺序

联调时先启动后端，再启动 Flutter。

后端在：

```text
E:\SCEP-backend\backend
```

启动命令：

```powershell
cd E:\SCEP-backend\backend
.\mvnw.cmd spring-boot:run
```

后端默认端口和上下文路径是：

```text
http://localhost:8080/api
```

可以用健康检查确认后端是否启动成功：

```powershell
Invoke-RestMethod http://localhost:8080/api/v1/health
```

然后再启动 Flutter。不同运行设备的 `API_BASE` 不一样：

Android 模拟器访问电脑本机后端：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd run --dart-define=API_BASE=http://10.0.2.2:8080/api
```

Android 真机访问电脑后端：

```powershell
ipconfig
```

找到电脑当前 WLAN 的 IPv4 地址，例如 `192.168.1.23`，然后：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd run --dart-define=API_BASE=http://192.168.1.23:8080/api
```

Windows 桌面端访问电脑本机后端：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd run -d windows --dart-define=API_BASE=http://localhost:8080/api
```

如果后端没启动、手机和电脑不在同一个网络、Windows 防火墙拦截 8080 端口，前端都会表现为无法连接服务器。

## 当前这些改动可以保留

为了避免中文用户目录和 Android 构建路径问题，当前仓库里这几类改动是有意义的：

```text
mobile\flutterw.cmd
docs\Flutter安卓构建说明.md
.gitignore 里的 .pub-cache / .gradle-user-home 忽略规则
```

`mobile\flutterw.cmd` 是项目约定入口。以后在这个 Flutter 工程里优先用它，不要直接用裸 `flutter` 命令。

## 一句话结论

这个项目在当前 Windows 环境下，Android 构建要尽量避开中文用户目录路径。

最稳妥的做法就是：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd pub get
.\flutterw.cmd run
```

如果再次遇到 Kotlin 插件编译失败，先清 `mobile\build` 和 `mobile\android\.gradle`，再重新执行上面的命令。
