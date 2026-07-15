# inspection_map 模块交付总结

## 一、模块定位

- 本模块是地图 / 导航 / 巡检数据层 + debug 验证模块。
- 本模块不是正式员工端页面。
- E 负责正式 Flutter App 页面、员工端巡检地图页面、点位详情弹窗、事件处理按钮、子女端告警页面。
- 本模块给 E 提供可复用的数据结构、model、repository、坐标转换、mock 数据和 debug 验证入口。

## 二、已完成能力

- 地图显示。
- marker 显示。
- 点击地图获取 pixel 坐标。
- pixel 坐标转换为 ROS map 坐标。
- `initial_pose` JSON 生成。
- `nav_goal` JSON 生成。
- `fall` / `crack` / `robot` / `target` / `obstacle` marker 显示。
- fall 身份字段显示：`elderName`、`identitySource`、`identityConfidence`、`notifiedChild`。
- fall / crack 的 `Mark handled` 状态处理。
- `Mock assets` 数据源。
- `Backend API` 数据源。
- Backend API 关闭时显示错误提示，不崩溃，并可切回 `Mock assets`。

## 三、运行方式

启动后端 mock：

```powershell
cd D:/Desktop/little_semaster/05/SECP-backend/backend
mvn -DskipTests spring-boot:run
```

启动 Flutter debug app：

```powershell
cd D:/Desktop/little_semaster/05/SECP-frontend/mobile
$env:PUB_CACHE="D:\Desktop\little_semaster\.pub-cache"
flutter run -d chrome -t lib/features/inspection_map/presentation/inspection_map_debug_app.dart --web-port 54321
```

## 四、Flutter 工具链权限要求

- 本机 Flutter SDK 会写入：

```text
D:\apps\flutter\bin\cache\lockfile
```

- 如果沙箱或普通终端没有权限写这个 lockfile，会导致：

```text
flutter --version 卡住
flutter analyze 卡住
flutter run 卡住
```

- 解决方式：

1. 给当前沙箱 / 终端写入 `D:\apps\flutter\bin\cache` 的权限。
2. 或使用提升权限的终端运行 Flutter。
3. 或先确认 `lockfile` 可写后再运行。

- 运行前设置本地 `PUB_CACHE`：

```powershell
$env:PUB_CACHE="D:\Desktop\little_semaster\.pub-cache"
```

这是 Flutter SDK 工具链权限问题，不是 `inspection_map` 模块代码问题。若 Flutter 命令长时间无输出，优先检查 lockfile 权限，不要误判为页面或 repository 代码错误。

## 五、已验证结果

- `Mock assets` 模式通过。
- `Backend API` 模式通过。
- `Mark handled` 通过。
- `Start navigation` 通过。
- `Cancel` 通过。
- `Return home` 通过。
- `Refresh` 通过。
- 后端关闭时错误处理通过：页面显示错误，不崩溃，可切回 `Mock assets`。
- `flutter analyze lib/features/inspection_map` 通过。

## 六、给 E 的接入方式

E 正式页面不要直接读取 JSON 文件，建议依赖：

```dart
InspectionMapRepository
```

本地 mock：

```dart
final InspectionMapRepository repo = InspectionMapMockRepository();
```

后端 mock：

```dart
final InspectionMapRepository repo = InspectionMapApiRepository(
  baseUrl: 'http://localhost:8080/api',
);
```

后续真接口继续实现同一个 `InspectionMapRepository`，不改页面调用逻辑。

## 七、给后端 / A 的字段说明

marker 字段：

```text
id
type
x
y
level
title
message
imageUrl
time
status
locationName
elderId
elderName
identitySource
identityConfidence
notifiedChild
```

fall 身份字段：

```text
elderId
elderName
identitySource
identityConfidence
notifiedChild
```

`navigationStatus` 枚举：

```text
idle
running
arrived
failed
paused
```

`obstacleStatus` 枚举：

```text
safe
obstacle
unknown
```

`nav_goal` JSON：

```json
{
  "type": "nav_goal",
  "frame_id": "map",
  "x": 0.0,
  "y": 0.0,
  "yaw": 0.0
}
```

`initial_pose` JSON：

```json
{
  "type": "initial_pose",
  "frame_id": "map",
  "x": 0.0,
  "y": 0.0,
  "yaw": 0.0
}
```

## 八、真车接入时替换关系

当前链路：

```text
Flutter debug page
-> InspectionMapApiRepository
-> SpringBoot mock controller
-> 内存 mock 数据
```

真车后链路：

```text
Flutter 正式页面
-> InspectionMapApiRepository
-> SpringBoot 正式接口
-> A 网关
-> ROS2 topic / Nav2 / 小车
```
