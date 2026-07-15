# 真车联调检查清单

## 一、真车启动顺序

- 启动 `n1`：底盘 / 雷达 / 基础节点。
- 启动 `n3`：Nav2 DWA 导航。
- 不使用 `m1` / `m2` / `m3` / `m4`。

## 二、ROS2 接口确认

- `/inspection_map/goal_pose`：`geometry_msgs/msg/PoseStamped`
- `/initialpose`：`geometry_msgs/msg/PoseWithCovarianceStamped`
- `/amcl_pose`
- `/navigate_to_pose`：`nav2_msgs/action/NavigateToPose`
- `/navigation_status`
- `/obstacle_status`
- `/ai/detection_result`

## 三、地图参数

```text
width = 608
height = 384
resolution = 0.05
origin = [-10, -10, 0]
imageHeight = 384
```

## 四、坐标转换公式

pixel -> map：

```text
mapX = originX + pixelX * resolution
mapY = originY + (imageHeight - pixelY) * resolution
```

map -> pixel：

```text
pixelX = (mapX - originX) / resolution
pixelY = imageHeight - (mapY - originY) / resolution
```

## 五、第一次真车联调原则

- 只测近距离点。
- 不测试远距离。
- 不测试复杂路径。
- 不测试多点巡检。
- 只测试当前位置附近约 1 米左右目标点。

## 六、真车联调流程

1. 小车启动 `n1`。
2. 小车启动 `n3`。
3. 确认 `/map`、`/amcl_pose`、`/inspection_map/goal_pose` 存在。
4. 设置 `initialpose`。
5. 从 debug 页选择一个近距离 target。
6. 生成 `nav_goal` JSON。
7. 交给 A 网关或 ROS2 发布层。
8. A 网关转换为 `/inspection_map/goal_pose`。
9. 小车运动。
10. `navigationStatus` 更新为 `running`。
11. 到达后更新为 `arrived`。

## 七、失败排查

- Nav2 是否启动。
- AMCL 是否设置初始位姿。
- `/inspection_map/goal_pose` 是否收到消息。
- 坐标点是否在可通行区域。
- 是否急停。
- 是否 `obstacleStatus=obstacle`。
- A 网关是否收到 navigation start 请求。
- 后端接口是否返回 `running`。
- Flutter 是否刷新状态。

## 八、演示保底方案

- 真车能走：展示真车导航。
- 真车不能走：展示 Backend API mock + debug 页。
- 后端挂了：切回 `Mock assets`。
- Flutter 工具链卡住：检查 Flutter lockfile 权限，必要时使用提升权限终端；同时使用已录屏材料保底。
