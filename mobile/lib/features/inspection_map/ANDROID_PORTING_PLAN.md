# 巡检地图 ROS 前端迁移到 Android App 方案

## 目标

把当前 Flutter debug 里已经验证过的 ROS/rosbridge 巡检地图页面，迁移为正式 Android App 中的一个页面。

正式链路保持为：

```text
Android App
  -> ws://<小车 IP>:9090
  -> rosbridge_websocket
  -> ROS2/Nav2 topics
```

不要使用 Windows Node + SSH `robot_control_bridge` 作为正式导航通信方案，也不要依赖 `/root/Control_demo/app_control_gateway.py`。

## 当前可复用的前端代码

当前代码位于 Flutter 仓库 `SECP-frontend/mobile` 的 `map` 分支工作区中。

核心迁移文件：

```text
lib/features/inspection_map/data/rosbridge_navigation_client.dart
lib/features/inspection_map/models/ros_navigation_models.dart
lib/features/inspection_map/presentation/inspection_map_ros_page.dart
```

这些文件的职责：

```text
rosbridge_navigation_client.dart
  负责 WebSocket 连接 rosbridge，订阅 ROS topic，发布 initialpose/goal_pose，
  调用 NavigateToPose cancel service，并发送有限次数零速度停止。

ros_navigation_models.dart
  负责解析 ROS 消息模型，例如 OccupancyGrid、LaserScan、Pose、Path、
  TF、GoalStatus 等。

inspection_map_ros_page.dart
  负责页面展示和交互，显示 ROS 地图、机器人位置、雷达点云、全局路径、
  局部路径、global/local costmap、导航状态，并提供 Start、Target、
  Navigate、Stop navigation 操作。
```

辅助调试文件：

```text
lib/features/inspection_map/presentation/inspection_map_debug_app.dart
tool/rosbridge_probe.dart
tool/mock_rosbridge_server.dart
tool/rosbridge_command_probe.dart
tool/rosbridge_navigation_safety_probe.dart
```

这些可以保留在 `map` 分支中用于调试和验收，但不要作为正式 App 入口。

## 不建议迁移为正式方案的代码

```text
lib/features/inspection_map/data/robot_control_bridge_client.dart
lib/features/inspection_map/presentation/inspection_map_debug_page.dart
```

原因：

```text
robot_control_bridge_client.dart
  属于旧的 HTTP/Windows bridge 思路，不符合正式 ROS/rosbridge 方案。

inspection_map_debug_page.dart
  偏 mock/API/debug 展示，不是当前真车 ROS 图层页面。
```

正式 Android App 应直接复用 `InspectionMapRosPage`，而不是迁移整个 debug app。

## ROS topic 对接范围

Android App 侧需要订阅：

```text
/map
/scan
/amcl_pose
/plan
/local_plan
/global_costmap/costmap
/local_costmap/costmap
/particlecloud
/cost_cloud
/tf
/tf_static
/navigate_to_pose/_action/status
/navigate_to_pose/_action/feedback
```

Android App 侧需要发布：

```text
/initialpose
/goal_pose
```

停止导航应执行：

```text
1. Flutter 向 /inspection_map/stop_navigation 单次发布 std_msgs/msg/Empty
2. Flutter 不直接调用 NavigateToPose CancelGoal
3. Flutter 不 advertise 或发布 /cmd_vel；取消 action 和有限零速由 bridge 统一负责
```

## 地图资源放入 App 的方式

实时地图展示应优先使用 ROS `/map` 的 `nav_msgs/msg/OccupancyGrid`。

如果需要 App 离线或未连接时也显示底图，可以把小车当前地图快照转换成 PNG 后放入：

```text
assets/robot_maps/yahboomcar.png
assets/robot_maps/map_info.json
```

`pubspec.yaml` 需要包含：

```yaml
flutter:
  assets:
    - assets/robot_maps/
```

`map_info.json` 必须和小车 `yahboomcar.yaml` 保持一致。当前新地图保存信息示例：

```json
{
  "mapName": "yahboomcar",
  "imageAsset": "assets/robot_maps/yahboomcar.png",
  "imageFile": "yahboomcar.png",
  "width": 864,
  "height": 896,
  "imageHeight": 896,
  "resolution": 0.05,
  "origin": [-22.8, -22.8, 0.0],
  "frameId": "map"
}
```

说明：

```text
PGM/YAML 可以保留在工程资料或工具目录中，但 Android 展示建议直接使用 PNG。
ROS 在线模式下，/map 会携带 width、height、resolution、origin，
页面应以 /map 数据为准。
```

## 正式 App 接入方式

推荐新增一个正式页面入口，页面本体直接使用：

```dart
const InspectionMapRosPage()
```

可选接入方式：

```text
方案 A：在 MaterialApp routes 中新增 /inspection-map
  优点：接入快，便于验收。
  适合：阶段性演示、内部测试。

方案 B：在已有“巡检/机器人/设备控制”模块中增加入口按钮
  优点：更符合正式产品结构。
  适合：最终 App 集成。
```

不要把 `inspection_map_debug_app.dart` 作为正式 App 的入口；它只是单独运行 debug 页面用的壳。

## rosbridge 地址配置

Web/Windows 调试时可以使用：

```text
ws://192.168.137.142:9090
```

Android 真机上不能使用：

```text
ws://127.0.0.1:9090
```

因为 Android 设备上的 `127.0.0.1` 指的是手机自己，不是小车。

建议正式 App 支持以下配置方式之一：

```text
1. 编译参数：--dart-define=ROSBRIDGE_URL=ws://<小车 IP>:9090
2. App 设置页：用户手动填写小车 IP
3. 后端配置：从后端下发当前小车 IP
```

当前 debug 入口已经支持：

```text
ROSBRIDGE_URL
ROSBRIDGE_AUTO_CONNECT
```

## Android 网络配置

Android App 需要确认：

```text
1. AndroidManifest.xml 有 INTERNET 权限
2. 允许 ws:// 明文 WebSocket
3. 手机和小车在同一网络
4. 小车 rosbridge 监听 0.0.0.0:9090
```

如果 Android 连接 `ws://` 失败，需要检查 Android 9+ 明文网络限制。可以使用：

```xml
<application
    android:usesCleartextTraffic="true">
</application>
```

或者配置 `network_security_config.xml`，只允许小车所在网段/IP 明文访问。

## 小车侧运行要求

小车容器中需要运行：

```text
n1
n3
inspection_map_bridge inspection_map.launch.py
```

rosbridge 启动参数建议：

```bash
ros2 launch inspection_map_bridge inspection_map.launch.py \
  domain_id:=30 \
  rosbridge_address:=0.0.0.0 \
  rosbridge_port:=9090 \
  test_data:=false \
  goal_action_bridge:=true \
  start_map_server:=false \
  use_sim_time:=false
```

说明：

```text
goal_action_bridge:=true
  负责把 Flutter 发布的 /goal_pose 转成 Nav2 NavigateToPose action goal。

start_map_server:=false
  真车上由 Yahboom/Nav2 bringup 自己启动 map_server，避免重复启动。
```

## Android 调试运行命令

示例：

```bash
flutter run -d <android-device-id> \
  -t lib/main.dart \
  --dart-define=ROSBRIDGE_URL=ws://192.168.137.142:9090 \
  --dart-define=ROSBRIDGE_AUTO_CONNECT=true
```

如果还没接入正式 App 入口，可以继续使用 debug 入口验证：

```bash
flutter run -d <android-device-id> \
  -t lib/features/inspection_map/presentation/inspection_map_debug_app.dart \
  --dart-define=ROSBRIDGE_URL=ws://192.168.137.142:9090 \
  --dart-define=ROSBRIDGE_AUTO_CONNECT=true
```

## 验收项

Android 真机上应验证：

```text
1. 页面能连接 ws://<小车 IP>:9090
2. /map 能显示真实 ROS OccupancyGrid
3. /scan 雷达点能跟随小车环境变化
4. /amcl_pose 能显示机器人位置和朝向
5. /plan 和 /local_plan 能显示路径
6. global/local costmap 能显示
7. NavigateToPose status/feedback 能更新
8. Start 发布 /initialpose 格式正确
9. Navigate 发布 /goal_pose 格式正确
10. Stop navigation 只向 /inspection_map/stop_navigation 发布一次 Empty
11. Flutter 不直接调用 CancelGoal，也不 advertise 或发布 /cmd_vel
12. 不依赖 app_control_gateway.py
```

## 风险和注意点

```text
地图过小/地图原点错误
  App 静态底图必须使用和小车当前 yaml 一致的 width、height、resolution、origin。
  在线 ROS 模式优先相信 /map 的 metadata。

目标方向 yaw
  目标点 quaternion 如果是 z=0,w=1，即 yaw=0。
  如果车头方向和目标 yaw 差很大，Nav2 会原地旋转调整方向。

重复 goal
  同一时间只运行一个 goal_pose_action_bridge。
  App 也只保留一个连接页面，避免重复发送 /goal_pose。

Android IP
  Android 真机不能使用 127.0.0.1 连接小车。

明文 WebSocket
  ws:// 需要 Android 允许 cleartext traffic。
```

## 建议提交到 map 分支的内容

正式迁移前，建议把以下内容提交到 `map` 分支：

```text
lib/features/inspection_map/data/rosbridge_navigation_client.dart
lib/features/inspection_map/models/ros_navigation_models.dart
lib/features/inspection_map/presentation/inspection_map_ros_page.dart
lib/features/inspection_map/presentation/inspection_map_debug_app.dart
tool/rosbridge_probe.dart
tool/mock_rosbridge_server.dart
tool/rosbridge_command_probe.dart
tool/rosbridge_navigation_safety_probe.dart
lib/features/inspection_map/ANDROID_PORTING_PLAN.md
```

如果要支持离线底图，再提交：

```text
assets/robot_maps/yahboomcar.png
assets/robot_maps/map_info.json
```

不建议作为正式方案提交或接入：

```text
lib/features/inspection_map/data/robot_control_bridge_client.dart
```
