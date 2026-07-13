# 巡检地图导航后端集成方案

> 状态：接口与迁移设计草案，当前不切换实现  
> 适用范围：`mobile/lib/features/inspection_map`、正式巡检地图页面及未来 `web_api` 机器人导航接口  
> 当前约束：小车离线，本文件不代表已经完成真车部署或验证

## 1. 结论与边界

推荐保留两种能力，但不要用一个全局开关把整页简单切成“全直连”或“全后端”：

| 能力 | Debug 当前方案 | 正式 App 推荐方案 |
| --- | --- | --- |
| 地图、雷达、TF、定位、路径、代价地图等实时数据 | `DirectRosbridge` | `DirectRosbridge` 只读通道 |
| 巡检任务、目标点、地图版本、权限、日志、操作记录 | 可使用 mock 或现有 API | `BackendMediated` |
| 导航、Stop、初始定位等写命令 | 经 rosbridge 发布受限 topic，便于联调 | `BackendMediated` |
| 最终单任务保护 | 机器人侧 `inspection_map_bridge` | 机器人侧 `inspection_map_bridge`，不能省略 |

因此正式形态是混合模式：

```text
高频实时显示：App -> rosbridge -> ROS2 topics
业务与写命令：App -> web_api -> robot command adapter -> ROS2 bridge -> Nav2
```

必须明确以下事实：

1. 增加后端不能修复 `map -> odom` TF 缺失、AMCL 未初始化、`/odom` 不发布、Nav2 lifecycle 未激活、`bt_navigator` 崩溃或 DDS 数据面异常。
2. 后端能做的是鉴权、授权、限流、幂等、审计、单任务调度、状态归一化和失败记录。
3. 当前导航异常不是“没有经过后端”造成的。已知问题是 ROS/Nav2 状态不稳定，以及前端和 bridge 过去缺少充分的重复 goal/Stop 防护。
4. 即使后端已经限制单任务，机器人侧 bridge 仍必须保留 `IDLE / NAVIGATING / CANCELING / COOLDOWN` 状态机，作为靠近 Nav2 的最后一道保护。
5. 本方案不要求修改 `app_control_gateway.py`，也不要求修改 Yahboom 原始导航包。

## 2. 两条链路

### 2.1 DirectRosbridge：当前 debug 链路

```text
inspection_map_debug_app.dart
  -> InspectionMapRosPage
  -> RosbridgeNavigationClient
  -> ws://<robot-ip>:9090
  -> rosbridge_websocket
  -> /goal_pose 或 /initialpose
  -> goal_pose_action_bridge
  -> NavigateToPose
  -> planner/controller
  -> Nav2/controller 输出 /cmd_vel
```

两种模式使用同一份 Stop 合同：

```text
/inspection_map/stop_navigation  (std_msgs/msg/Empty)
```

- `DirectRosbridge`：Flutter 只经 rosbridge 发布一次上述 Stop topic。
- `BackendMediated`：Flutter 调用后端 Stop API，后端 robot adapter 最多发布一次上述 Stop topic。
- Flutter 和后端的 Stop 输出到此 topic 为止，不执行其他 ROS Stop 操作。
- `inspection_map_bridge` 收到 Stop 后，负责对当前 goal handle 发起一次 cancel，并按配置向 `/cmd_vel` 发布有限的 `1..3` 次零速度；重复 Stop 由 bridge 状态机忽略。

当前 `RosbridgeNavigationClient`、调试页面、mock rosbridge 和 command probe 已遵守这份 DirectRosbridge Stop 合同；现有 debug 启动入口、命令和 `ROSBRIDGE_URL` 参数语义保持不变。

当前 debug 启动命令必须保持可用：

```powershell
flutter run -d windows `
  -t lib\features\inspection_map\presentation\inspection_map_debug_app.dart `
  --dart-define=ROSBRIDGE_URL=ws://<robot-ip>:9090
```

`InspectionMapDebugApp` 继续直接打开 `InspectionMapRosPage`。当前阶段不增加必须配置的后端地址，不改变 `ROSBRIDGE_URL` 含义，也不让 debug 链路依赖 `web_api`。

### 2.2 BackendMediated：未来写命令链路

```text
正式 App /inspection/map
  -> NavigationCommandGateway
  -> ApiClient.dio (Bearer token)
  -> web_api
  -> 权限、幂等、活动任务锁、审计、状态记录
  -> per-robot command dispatcher
  -> robot command adapter
  -> /goal_pose 或 /inspection_map/stop_navigation
  -> inspection_map_bridge 单任务状态机
  -> NavigateToPose
  -> Nav2
```

`robot command adapter` 是后端到机器人 ROS 网络的适配层，不应等同于允许正式 App 远程执行 shell。部署可以选择以下一种方式，但对 App 暴露的 HTTP 合同保持不变：

1. 后端位于可访问机器人 ROS/rosbridge 的受控网络，由后端 rosbridge client 发布受限 topic。
2. 机器人侧运行一个受控 agent，由 agent 主动建立到后端的认证连接，再在本地发布受限 ROS topic。
3. 后端与机器人侧 gateway 使用消息队列或受控 HTTP 通道，gateway 再发布 ROS topic。

无论选择哪种方式，正式 App 都不应获得启动 `n1`、启动 `n3`、重启 Docker、执行任意命令或操作机器人文件系统的能力。

## 3. 实时数据与业务数据分流

### 3.1 建议直接经 rosbridge 的实时数据

| ROS 数据 | 用途 | 正式 App 处理原则 |
| --- | --- | --- |
| `/map` | 实时 OccupancyGrid | 用于当前画面；同时校验后端地图版本 |
| `/scan` | 激光雷达 | 只读、节流、仅用于显示和诊断 |
| `/tf`、`/tf_static` | 坐标变换 | 只读；前端只能显示缺失，不能修复 TF |
| `/amcl_pose` | 定位 | 只读；必须带 freshness 判断 |
| `/plan`、`/local_plan` | 路径 | 只读；用于导航可视化 |
| global/local costmap | 障碍与规划代价 | 只读、强制节流，允许低性能设备关闭 |
| `/particlecloud` | AMCL 收敛诊断 | 诊断可选项，不作为唯一 readiness 依据 |
| NavigateToPose feedback/status | 诊断反馈 | 与后端 task/goal id 关联后才能作为业务状态依据 |
| `/cmd_vel` | 运动输出观察 | 只读诊断；不能据“当前无消息”单独判定故障 |

正式 App 的 DirectRosbridge 连接应尽量是 topic allowlist 的只读连接。rosbridge 9090 不应直接暴露到公网；生产环境至少需要受控局域网或 VPN、`wss` 反向代理、连接鉴权和 topic/service ACL。

### 3.2 必须经 web_api 的业务数据

- 巡检任务及其步骤。
- 目标点、命名地点、返航点和路线模板。
- 地图记录、`mapId`、地图 revision/hash 和启用状态。
- 操作人权限、机器人归属关系和租户/机构边界。
- 导航 task、command、goal 的关联记录。
- 导航开始、取消、完成、失败、超时和拒绝日志。
- 事件标记、处理记录、备注和附件。
- 机器人在线状态的聚合结果和最近一次可靠状态时间。

### 3.3 同一数据有两个来源时的规则

地图和导航状态会同时出现在 ROS 实时通道与后端业务通道，必须规定优先级：

1. `/map` 的栅格内容用于实时绘制；后端的地图记录用于身份、版本和权限判断。
2. 只有 ROS map metadata 与后端 `mapId/mapRevision` 对应时，才允许将后端保存的像素点转换成当前 ROS map 坐标。
3. 地图版本不一致时，禁止发导航目标，返回 `MAP_VERSION_MISMATCH`，不能静默使用旧 origin/resolution。
4. Nav2/bridge 是“机器人实际执行状态”的来源；后端是“业务任务状态”的来源。后端应根据带关联 id 的机器人回报更新业务状态，而不是根据 HTTP 请求成功直接标记导航成功。
5. App 从 rosbridge 看到的 action status 如果无法关联当前 goal UUID，只能显示为诊断信息，不能覆盖后端当前任务。
6. 任何状态超过 freshness 阈值都必须标记 `stale=true`；`UNKNOWN` 或 stale 不能降级解释成 `IDLE`。

## 4. 前端模式设计

后续实现时建议把“遥测来源”和“命令来源”分开配置：

```text
telemetryTransport = directRosbridge | backendSnapshot
commandTransport   = directRosbridge | backendMediated
businessTransport  = mockAssets | backendApi
```

推荐组合：

| 场景 | telemetry | command | business |
| --- | --- | --- | --- |
| 当前 Windows/VMware debug | `directRosbridge` | `directRosbridge` | `mockAssets` 或现有 API |
| 正式 App | `directRosbridge` | `backendMediated` | `backendApi` |
| 无法直连机器人网络的远程查看 | `backendSnapshot` | `backendMediated` | `backendApi` |
| Widget/单元测试 | fake | fake | mock |

建议在地图 feature 内逐步形成以下接口，当前文档阶段不新增 Dart 实现：

```dart
abstract interface class NavigationTelemetrySource {
  Stream<NavigationTelemetry> watchTelemetry(String robotId);
}

abstract interface class NavigationCommandGateway {
  Future<NavigationCommandResult> sendGoal(NavigationGoalRequest request);
  Future<NavigationCommandResult> stop(NavigationStopRequest request);
  Future<NavigationCommandResult> setInitialPose(InitialPoseRequest request);
  Future<NavigationTaskStatus> getStatus(String robotId);
}
```

约束：

- `RosbridgeNavigationClient` 可以成为 `NavigationTelemetrySource` 的底层实现。
- debug 可提供 `DirectRosbridgeNavigationCommandGateway`。
- 正式 App 使用 `BackendNavigationCommandGateway`，并复用全局 `ApiClient.dio` 的 token 注入和统一错误处理。
- 页面不应自行拼 HTTP 路径、ROS topic 或状态码；这些属于 data/domain 层。
- 不要在正式页面中暴露 rosbridge URL 输入框、n1/n3 启停、Docker 重启或原始 topic 发布按钮。

## 5. 后端 API 草案

### 5.1 路径约定

建议正式合同使用版本化、多机器人资源路径：

| 方法 | 服务端完整路径 | Flutter 使用 `ApiClient.dio` 时的 path |
| --- | --- | --- |
| `POST` | `/api/v1/robots/{robotId}/navigation/goals` | `/v1/robots/{robotId}/navigation/goals` |
| `POST` | `/api/v1/robots/{robotId}/navigation/stop` | `/v1/robots/{robotId}/navigation/stop` |
| `GET` | `/api/v1/robots/{robotId}/navigation/status` | `/v1/robots/{robotId}/navigation/status` |
| `GET` | `/api/v1/robots/{robotId}/maps/current` | `/v1/robots/{robotId}/maps/current` |
| `GET` | `/api/v1/maps/{mapId}/metadata` | `/v1/maps/{mapId}/metadata` |
| `POST` | `/api/v1/robots/{robotId}/initial-pose` | `/v1/robots/{robotId}/initial-pose` |

用户最初提出的 `/api/robot/navigation/goals` 等单机器人路径可以作为原型参考，但正式合同应携带 `robotId`，避免以后通过请求 body 或全局配置猜测目标机器人。`AppConfig.apiBase` 当前已包含 `/api`，Flutter 调用时不能再拼出 `/api/api/...`。

所有坐标字段使用 ROS map 坐标：

- `x`、`y`：米。
- `yaw`：弧度，范围归一化到 `(-pi, pi]`。
- `frameId`：当前仅允许 `map`。
- 像素坐标只用于 UI，不作为导航 API 的目标坐标。
- 请求必须携带 `mapId` 和 `mapRevision`，后端据此拒绝旧地图目标。

时间统一使用 UTC ISO-8601，例如 `2026-07-14T03:20:45.123Z`。ROS header stamp 由机器人侧 bridge 使用 ROS node 当前时间重写，不信任手机或浏览器时间。

### 5.2 通用响应结构

成功：

```json
{
  "success": true,
  "data": {},
  "requestId": "req_01J...",
  "serverTime": "2026-07-14T03:20:45.123Z"
}
```

失败：

```json
{
  "success": false,
  "error": {
    "code": "ACTIVE_GOAL_EXISTS",
    "message": "Robot already has an active navigation goal",
    "retryable": false,
    "details": {
      "activeTaskId": "nav_01J..."
    }
  },
  "requestId": "req_01J...",
  "serverTime": "2026-07-14T03:20:45.123Z"
}
```

`message` 用于展示或日志，客户端分支必须依赖稳定的 `error.code`，不能解析英文或中文文案。

### 5.3 创建导航目标

`POST /api/v1/robots/{robotId}/navigation/goals`

Headers：

```text
Authorization: Bearer <token>
Idempotency-Key: <UUID generated once per user action>
```

Request：

```json
{
  "clientRequestId": "77e7cb9e-4d7f-4f74-8b71-3d323ce13245",
  "inspectionTaskId": "inspection_123",
  "targetName": "走廊东侧",
  "mapId": "yahboomcar",
  "mapRevision": "sha256:...",
  "pose": {
    "frameId": "map",
    "x": 1.25,
    "y": -0.8,
    "yaw": 1.5707963268
  }
}
```

Accepted response：`202 Accepted`

```json
{
  "success": true,
  "data": {
    "taskId": "nav_01J...",
    "commandId": "cmd_01J...",
    "robotId": "robot_1",
    "state": "QUEUED",
    "target": {
      "frameId": "map",
      "x": 1.25,
      "y": -0.8,
      "yaw": 1.5707963268
    },
    "acceptedAt": "2026-07-14T03:20:45.123Z"
  },
  "requestId": "req_01J...",
  "serverTime": "2026-07-14T03:20:45.123Z"
}
```

`202` 只表示后端已接受异步处理，不表示 bridge 接受、不表示 Nav2 executing，更不表示小车开始移动。

创建前至少校验：

- 用户对该机器人具有导航权限。
- 机器人属于当前机构/租户。
- 目标数字有限，frame 合法，yaw 合法。
- `mapId/mapRevision` 与机器人当前地图一致。
- 目标在地图边界内；是否禁止占用栅格目标由后端地图服务进一步校验。
- 机器人没有活动 goal、cancel 或 cooldown。
- 最近状态没有超过 freshness 阈值。
- robot command adapter 可用；无法确认时返回明确的不可用状态，不可假装已发送。

### 5.4 Stop 当前导航

`POST /api/v1/robots/{robotId}/navigation/stop`

Request：

```json
{
  "clientRequestId": "8ca27037-9370-4c48-98bf-f4e2f369304d",
  "taskId": "nav_01J...",
  "reason": "operator_requested"
}
```

Response：`202 Accepted`

```json
{
  "success": true,
  "data": {
    "taskId": "nav_01J...",
    "commandId": "cmd_stop_01J...",
    "state": "CANCELING",
    "disposition": "CANCEL_REQUESTED"
  },
  "requestId": "req_01J...",
  "serverTime": "2026-07-14T03:21:08.000Z"
}
```

重复 Stop 不得让 bridge 重复触发多组 cancel/零速度：

- 同一 `Idempotency-Key` 重放，返回第一次结果。
- 不同 key 但任务已经 `CANCELING`，返回现有 cancel command，`disposition=ALREADY_CANCELING`。
- 任务已经 terminal，返回 `200 OK`，`disposition=ALREADY_TERMINAL`。
- 没有活动任务时返回 `200 OK`，`disposition=NO_ACTIVE_GOAL`。
- 后端对一次业务 Stop 最多发布一次 `/inspection_map/stop_navigation`；bridge 再保证重复 topic 不会重复进入 cancel 流程。
- 后端和 Flutter 的 Stop 职责在发布 topic 后结束；cancel 当前 goal 和有限零速全部由 `inspection_map_bridge` 执行。

Stop 只针对 bridge 当前持有的 task/goal。正式 App 和普通后端 API 不提供 cancel-all 语义。

### 5.5 获取导航状态

`GET /api/v1/robots/{robotId}/navigation/status`

Response：

```json
{
  "success": true,
  "data": {
    "robotId": "robot_1",
    "taskId": "nav_01J...",
    "commandId": "cmd_01J...",
    "goalId": "ros-goal-uuid-if-known",
    "state": "NAVIGATING",
    "bridgeState": "NAVIGATING",
    "nav2StatusCode": 2,
    "reasonCode": null,
    "target": {
      "frameId": "map",
      "x": 1.25,
      "y": -0.8,
      "yaw": 1.5707963268
    },
    "progress": {
      "distanceRemainingM": 2.31,
      "estimatedTimeRemainingSec": 18.2,
      "numberOfRecoveries": 0
    },
    "robotConnectivity": "ONLINE",
    "rosReadiness": {
      "map": true,
      "odom": true,
      "localization": true,
      "nav2": true
    },
    "lastRobotUpdateAt": "2026-07-14T03:21:10.100Z",
    "lastTransitionAt": "2026-07-14T03:20:46.010Z",
    "stale": false
  },
  "requestId": "req_01J...",
  "serverTime": "2026-07-14T03:21:10.200Z"
}
```

后端可先用短轮询实现；后续如需要实时业务状态，可增加 SSE 或应用 WebSocket。高频激光、TF、costmap 不应塞进该状态 API。

### 5.6 当前地图与 metadata

`GET /api/v1/robots/{robotId}/maps/current`

返回机器人当前声明使用的地图记录：

```json
{
  "success": true,
  "data": {
    "robotId": "robot_1",
    "mapId": "yahboomcar",
    "mapRevision": "sha256:...",
    "metadataUrl": "/api/v1/maps/yahboomcar/metadata",
    "imageUrl": "/api/v1/maps/yahboomcar/image",
    "activatedAt": "2026-07-14T01:00:00.000Z"
  }
}
```

`GET /api/v1/maps/{mapId}/metadata`

```json
{
  "success": true,
  "data": {
    "mapId": "yahboomcar",
    "mapRevision": "sha256:...",
    "frameId": "map",
    "width": 864,
    "height": 896,
    "imageHeight": 896,
    "resolution": 0.05,
    "origin": [-22.8, -22.8, 0.0]
  }
}
```

`mapRevision` 应基于实际部署的 yaml、pgm/png 和关键 metadata 生成稳定 hash，避免只靠文件名判断是否同一张地图。

### 5.7 设置 initial pose

`POST /api/v1/robots/{robotId}/initial-pose`

Request：

```json
{
  "clientRequestId": "e358d688-7f48-498d-a177-643897e02363",
  "mapId": "yahboomcar",
  "mapRevision": "sha256:...",
  "pose": {
    "frameId": "map",
    "x": 0.3,
    "y": -0.4,
    "yaw": 0.0
  },
  "covariancePreset": "operator_initial_pose"
}
```

Initial pose 是定位重置，不是普通导航命令：

- 需要独立的高权限。
- 机器人正在导航时默认拒绝，除非先完成 Stop 并回到稳定状态。
- bridge/relay 使用 ROS node 当前时间重写 header stamp。
- HTTP 成功只代表消息被接受或发布；AMCL 是否收敛必须由后续 `/amcl_pose`、TF 和 readiness 反馈确认。

## 6. 状态语义与关联

### 6.1 三层状态不能混为一个枚举

| 层 | 建议状态 | 含义 |
| --- | --- | --- |
| 后端业务 task | `QUEUED`、`DISPATCHING`、`ACCEPTED`、`NAVIGATING`、`CANCELING`、`SUCCEEDED`、`CANCELED`、`ABORTED`、`REJECTED`、`UNKNOWN` | App 对用户展示和审计的主状态 |
| robot bridge | `IDLE`、`NAVIGATING`、`CANCELING`、`COOLDOWN` | 单任务与重复命令防护状态 |
| Nav2 action | status code `0..6` | ROS action 的底层状态 |

Nav2 常用 code 映射：

| Nav2 code | ROS 含义 | 后端映射原则 |
| --- | --- | --- |
| `0` | unknown | `UNKNOWN`，不能当 `IDLE` |
| `1` | accepted | `ACCEPTED` |
| `2` | executing | `NAVIGATING` |
| `3` | canceling | `CANCELING` |
| `4` | succeeded | `SUCCEEDED` |
| `5` | canceled | `CANCELED` |
| `6` | aborted | `ABORTED`，记录原始错误上下文 |

### 6.2 状态推进规则

```text
QUEUED
  -> DISPATCHING
  -> ACCEPTED
  -> NAVIGATING
  -> SUCCEEDED | ABORTED | CANCELING
CANCELING
  -> CANCELED | ABORTED | UNKNOWN
```

- `REJECTED` 表示命令在 bridge/Nav2 接受前被权限、参数、活动任务或 readiness 校验拒绝。
- `ABORTED` 表示已进入机器人执行链路后由 Nav2/bridge 失败结束。
- `UNKNOWN` 表示无法可靠判断，不等于成功、不等于失败，也不允许立即创建下一任务；需 reconcile 或人工确认。
- 后端请求超时不能直接写 `ABORTED`，因为命令可能已到机器人但回执丢失。先写 `UNKNOWN`/`DISPATCH_UNKNOWN` 并执行按 command id 的对账。
- bridge 进入 `COOLDOWN` 时，业务 task 已可 terminal，但新 goal 仍需等待 bridge 回到 `IDLE`。

### 6.3 必须保存的关联 id

每次导航至少保存：

- `taskId`：业务导航任务。
- `commandId`：一次下发命令。
- `clientRequestId`：App 一次用户操作。
- `Idempotency-Key`：HTTP 重试去重键。
- `robotId`。
- `inspectionTaskId`：可选的上层巡检任务。
- `goalId`：bridge/Nav2 goal UUID，收到后补写。
- `mapId/mapRevision`。

不能再通过 `status_list.last` 猜测当前任务。机器人回报和前端实时 action status 都应按 goal UUID 关联；无法关联的历史 status 只进入诊断日志。

## 7. 幂等、并发与单任务保护

### 7.1 HTTP 幂等

1. 创建 goal、Stop、initial pose 都要求 `Idempotency-Key`。
2. 后端保存 `(actorId, robotId, operation, idempotencyKey)` 唯一记录和请求 body hash。
3. 相同 key、相同 body 的重试返回第一次结果，不重新下发。
4. 相同 key、不同 body 返回 `409 IDEMPOTENCY_KEY_REUSED`。
5. 幂等记录保留时间应覆盖移动端网络重试窗口，建议至少 24 小时。

### 7.2 每机器人并发控制

- 后端对每个 robot 使用数据库行锁、分布式锁或单线程 actor/queue，原子地检查并创建活动任务。
- 数据库应有“每机器人最多一个非 terminal 导航 task”的约束，不能只依赖页面按钮 disabled。
- 收到第二个 goal 时默认 `409 ACTIVE_GOAL_EXISTS`，不排队、不覆盖、不隐式 cancel 当前任务。
- cancel 进行中返回现有 cancel 状态。
- bridge cooldown 期间返回 `409 ROBOT_COOLDOWN`，并可附 `retryAfterMs`。

### 7.3 多层防重复

```text
UI busy/debounce
  + HTTP Idempotency-Key
  + backend per-robot active-task lock
  + dispatcher command deduplication
  + inspection_map_bridge state machine
```

任何一层都不能作为删除其他层的理由。移动端可能重复点击，网络库可能重试，后端实例可能重启，消息通道可能重复投递，因此 bridge 必须继续忽略 active/cancel/cooldown 期间的新 goal 和重复 Stop。

## 8. 鉴权、权限与安全

### 8.1 App 到 web_api

- 复用 `ApiClient.dio` 和现有 `AuthSession` Bearer token 注入。
- 建议权限拆分为：

| Permission | 能力 |
| --- | --- |
| `robot.navigation.read` | 查看任务和状态 |
| `robot.telemetry.read` | 获取 rosbridge 只读连接授权或代理快照 |
| `robot.navigation.command` | 创建普通导航 goal |
| `robot.navigation.stop` | 停止当前 goal |
| `robot.localization.initialize` | 设置 initial pose |
| `robot.navigation.operate` | 受控运维动作，不授予普通正式 App |

- 每次操作还要校验用户、机构、机器人三者的资源关系，不能只检查 token 是否有效。
- initial pose 和运维能力应比普通导航权限更严格。

### 8.2 web_api 到机器人

- 使用服务身份认证、TLS 和每机器人凭据；不能信任客户端传入的 rosbridge URL。
- 只允许发布固定 topic 和固定 message type，不提供任意 topic、service、action 或 shell 透传。
- rosbridge 9090 不直接开放公网。若正式 App 必须直连实时数据，使用短期连接凭证、VPN/受控网络、`wss` 和只读 ACL。
- 不在日志中记录 Bearer token、机器人密钥或完整连接凭据。

### 8.3 审计

每次写命令记录：

- actor、角色、机构、robotId。
- requestId、clientRequestId、idempotency key 的 hash。
- taskId、commandId、goalId。
- 原始目标坐标、地图版本和操作原因。
- 权限决策、限流结果、下发时间、bridge 接受时间、Nav2 terminal 时间。
- 最终状态、稳定错误码和必要的 ROS 摘要。

审计日志是业务追踪，不代替 ROS bag、Nav2 日志或 core dump。

## 9. 错误合同

建议错误码：

| HTTP | code | retryable | 说明 |
| --- | --- | --- | --- |
| `400` | `INVALID_POSE` | false | 坐标、yaw、frame 非法 |
| `400` | `TARGET_OUT_OF_MAP` | false | 目标超出当前地图 |
| `401` | `UNAUTHENTICATED` | false | token 无效或过期 |
| `403` | `ROBOT_FORBIDDEN` | false | 无权访问机器人 |
| `403` | `INITIAL_POSE_FORBIDDEN` | false | 无定位重置权限 |
| `404` | `ROBOT_NOT_FOUND` | false | robotId 不存在 |
| `409` | `ACTIVE_GOAL_EXISTS` | false | 已有活动导航 |
| `409` | `CANCEL_IN_PROGRESS` | true | 正在取消 |
| `409` | `ROBOT_COOLDOWN` | true | bridge 冷却中 |
| `409` | `MAP_VERSION_MISMATCH` | false | App 目标基于旧地图 |
| `409` | `IDEMPOTENCY_KEY_REUSED` | false | 同 key 不同请求 |
| `422` | `TARGET_OCCUPIED` | false | 目标落在禁止栅格 |
| `423` | `LOCALIZATION_NOT_READY` | true | AMCL/TF 未满足条件 |
| `503` | `ROBOT_OFFLINE` | true | 机器人连接过期 |
| `503` | `NAV2_NOT_READY` | true | Nav2/action server 未就绪 |
| `503` | `ROBOT_ADAPTER_UNAVAILABLE` | true | 后端到机器人通道不可用 |
| `504` | `DISPATCH_TIMEOUT` | true | 下发结果未知，需要对账 |

ROS 侧问题应保留更具体的 `reasonCode`，例如：

- `TF_MAP_MISSING`
- `TF_ODOM_MISSING`
- `AMCL_INITIAL_POSE_REQUIRED`
- `ODOM_STALE`
- `ACTION_SERVER_UNAVAILABLE`
- `NAV2_ABORTED`
- `NAV2_PROCESS_EXITED`
- `STATUS_STALE`

这些错误码用于说明现象，不表示后端能够修复对应 ROS 问题。

## 10. 后端调度实现建议

推荐一次 goal 下发过程：

1. API 完成鉴权、资源授权、参数和地图版本校验。
2. 在事务内创建 task/command、占用机器人活动任务槽，并写入 outbox。
3. 返回 `202 QUEUED`。
4. dispatcher 按 robotId 串行消费 outbox。
5. adapter 向机器人发布 goal，并携带 command/task correlation metadata；若 `/goal_pose` 消息无法携带业务字段，则 adapter 本地保存 commandId 与 ROS goal UUID 的映射。
6. bridge 接受第一个 goal，进入 `NAVIGATING`；活动期的其他 goal 由 bridge 忽略并记录。
7. bridge/Nav2 状态回报驱动后端状态更新。
8. terminal 后 bridge 进入 `COOLDOWN`，清理 goal handle，随后回 `IDLE`。
9. 后端定时 reconcile 长时间停留在 `DISPATCHING`、`CANCELING` 或 `UNKNOWN` 的任务。

使用 transactional outbox 的目的是避免“数据库写成功但进程在发布前崩溃”造成永久丢命令。消息仍可能重复，因此 adapter 和 bridge 仍要幂等。

正式业务 API 不应包含以下能力：

- 任意 SSH、Docker 或 shell 命令。
- 任意 ROS topic/service/action 调用。
- 启动或重启 n1/n3/Nav2。
- 修改 Yahboom 原始参数或工作空间。
- 从 App 上传并覆盖机器人工作空间。

这些能力如确实需要，只能放在独立、受控的运维面，并与普通 App 权限和接口隔离。

## 11. 文件复用与归属

### 11.1 inspection_map feature 内

| 文件 | 当前职责 | 未来归属 |
| --- | --- | --- |
| `data/rosbridge_navigation_client.dart` | WebSocket、topic 订阅和 debug 写命令 | 实时 transport 可复用；DirectRosbridge Stop adapter 的唯一输出是 `/inspection_map/stop_navigation`；正式模式中的写命令方法不直接供页面调用 |
| `models/ros_navigation_models.dart` | ROS map、pose、TF、path、feedback/status 解析 | 可复用；正式接入前必须按 goal UUID 关联 status，不能继续只取 `status_list.last` |
| `models/map_info.dart` | 地图 metadata | 可复用；增加 `mapId/mapRevision` 时保持坐标语义一致 |
| `utils/coordinate_converter.dart` | 像素与 map 坐标转换 | 可复用；输入 metadata 必须来自同一 map revision |
| `utils/occupancy_grid_placement.dart` | OccupancyGrid 图像放置 | 可复用 |
| `data/inspection_map_repository.dart` | debug 数据源抽象 | 概念可复用；正式实现需与现有 `InspectionService` 统一，避免两套业务 repository 长期并存 |
| `data/inspection_map_api_repository.dart` | 独立 Dio 的 API 原型 | 可参考字段归一化；正式 App 应改用 `ApiClient.dio`，不能绕过 token 注入 |
| `data/inspection_map_mock_repository.dart` | asset/mock 数据 | 保留给 debug 和测试 |
| `presentation/inspection_map_ros_page.dart` | 完整 rosbridge 调试页面 | 作为 debug/integration surface；地图渲染与实时 controller 可逐步抽取复用，但正式页面不应直接复用其 URL/原始控制 UI |
| `presentation/inspection_map_debug_app.dart` | 独立 debug main | 仅 debug，当前启动方式保持不变 |
| `presentation/inspection_map_debug_page.dart` | mock/API/本地 robot control gateway 综合调试 | 仅 debug/运维实验，不进入正式 App |
| `data/robot_control_bridge_client.dart` | 调用 `127.0.0.1:18080` 的启停、重启和发 pose 调试接口 | 仅 debug；不得作为正式 BackendMediated client |
| `inspection_map_api_contract.md` | 早期地图业务 API 合同 | 保留历史背景；实现新导航 API 时统一版本和状态命名，避免两个合同相互冲突 |

### 11.2 正式 App 接入点

| 文件 | 接入计划 |
| --- | --- |
| `mobile/lib/features/inspection/presentation/inspection_map_page.dart` | 当前 `/inspection/map` 正式页面。未来注入业务 repository、telemetry source 和 backend command gateway |
| `mobile/lib/features/inspection/data/inspection_service.dart` | 当前已经使用 `ApiClient.dio` 调业务接口，是正式后端适配的主要迁移点；导航 task 路径需与本方案最终合同统一 |
| `mobile/lib/app/smart_elderly_care_app.dart` | 保持 `/inspection/map` 为正式入口；`/inspection-map` 直连页仅作为集成/debug 入口，生产构建可隐藏 |
| `mobile/lib/core/network/api_client.dart` | 复用统一 API base、Bearer token 和错误处理，不在地图 feature 再创建无鉴权的全局 Dio |
| `mobile/lib/core/config/app_config.dart` | 后续增加命令/遥测模式配置；避免把机器人 IP 硬编码进正式页面 |

### 11.3 建议后续新增的 feature 内文件

以下只是未来落地建议，本次不创建：

```text
inspection_map/
  domain/
    navigation_command_gateway.dart
    navigation_telemetry_source.dart
    navigation_task_state.dart
  data/
    backend_navigation_command_gateway.dart
    direct_rosbridge_command_gateway.dart
    rosbridge_navigation_telemetry_source.dart
  presentation/
    inspection_map_controller.dart
    widgets/inspection_map_surface.dart
```

先抽接口和测试，再迁移页面；不要一次重写整个地图模块或其他 App 功能。

## 12. 正式 App 页面行为

正式页面接入 BackendMediated 后应满足：

- 用户点击地图只选择目标，不自动下发。
- 确认导航后立即进入 submitting/busy，防止连续点击。
- `202` 返回后显示“任务已提交”，不能显示“导航成功”或“小车已开始移动”。
- 只有状态进入 `NAVIGATING` 才显示正在导航。
- 活动 task 存在时 Navigate 禁用；后端 `409` 仍作为最终保护处理。
- Stop 点击后立即进入 canceling/busy，重复点击不产生新请求。
- `UNKNOWN`、stale、robot offline、map mismatch 时禁止新 goal，并展示稳定错误说明。
- 直接 rosbridge 实时数据断开不应自动取消后端任务；应提示实时画面不可用，并继续从后端查询业务状态。
- 后端 API 断开也不应把 rosbridge action status 无关联地当作正式任务结果。
- App 退出、切后台或页面 dispose 不自动 Stop；导航任务归属于后端 task，而不是某个 Widget 生命周期。

## 13. 迁移阶段

### 阶段 0：当前状态

- 保持 debug 启动命令和 DirectRosbridge 行为不变。
- 新 bridge 单任务状态机先在 VMware/本地 ROS2 Foxy 离线验证。
- 当前仅提交方案文档，不声称真车已验证。

回滚：无运行时代码变化。

### 阶段 1：冻结合同与后端数据模型

- 团队确认 endpoint、状态枚举、错误码、map revision 和 idempotency 规则。
- 后端建立 robot、navigation_task、navigation_command、idempotency_record、audit_event/outbox 数据模型。
- 使用 mock robot adapter 做 API contract tests。

回滚：接口不接正式入口，现有 App 不受影响。

### 阶段 2：地图 feature 内抽象 transport

- 抽出 telemetry source 与 command gateway。
- 用现有 `RosbridgeNavigationClient` 包装 DirectRosbridge adapter。
- DirectRosbridge Stop contract test 必须断言只发布一次 `/inspection_map/stop_navigation`，且客户端不执行其他 ROS Stop 操作。
- 增加 fake adapter 测试重复 goal、重复 Stop、stale 和 map mismatch UI。
- `inspection_map_debug_app.dart` 仍显式选择 direct adapters。

回滚：debug 默认仍走原 adapter，不依赖后端。

### 阶段 3：增加 BackendNavigationCommandGateway

- 复用 `ApiClient.dio`。
- 先用 feature flag 仅对测试账号/机器人启用。
- 实时 telemetry 继续直连 rosbridge，命令改走后端。
- 对比 taskId、commandId、goalId 与机器人日志，验证状态关联。

回滚：关闭 command feature flag，回到 DirectRosbridge debug；正式生产是否允许回退直连写命令应由安全策略决定，不能自动降级。

### 阶段 4：接入正式 `/inspection/map`

- 将可复用地图 surface/controller 接入当前正式页面。
- 正式页面只展示受权限控制的命令。
- 隐藏 URL、n1/n3、restart、原始 publish 等 debug 控件。
- 保持 `/inspection-map` 或独立 debug main 用于工程联调，但不从生产菜单暴露。

回滚：正式路由切回当前 `InspectionMapPage`，不删除 debug 工具。

### 阶段 5：生产加固

- rosbridge 只读 ACL、`wss`/VPN、短期授权。
- 后端 per-robot 锁、outbox、reconcile、限流和告警。
- 真车断网、后端重启、重复投递、bridge 重启、Nav2 abort/crash 场景测试。
- 稳定后再废弃重复的早期导航 API，不能长期维护两套状态语义。

## 14. 离线与真车验证边界

当前没有小车在线时可以完成：

- API OpenAPI/JSON schema 与 contract tests。
- 后端幂等、活动任务唯一约束和权限测试。
- mock adapter 的 queued/accepted/navigating/canceling/terminal 状态推进测试。
- Flutter gateway 单元测试和页面重复点击测试。
- rosbridge/bridge 的 mock action server 离线测试。
- map revision、坐标边界和错误映射测试。

必须等小车在线后验证：

- 后端 adapter 到真实机器人网络的连接、认证和重连。
- bridge goal UUID 与后端 task/command 的真实关联。
- 单次 goal、活动期重复 goal、单次 Stop、连续 Stop 的真车行为；确认 Flutter/后端只发布 Stop topic，bridge 只进入一次 cancel 流程。
- bridge/Nav2 输出的 `/cmd_vel`、`/odom`、TF、AMCL、Nav2 lifecycle 和 action server 的完整链路。
- backend `202`、bridge accept、Nav2 executing、terminal 状态的时间顺序。
- 网络中断后 task 是否进入正确的 stale/unknown/reconcile 流程。
- `bt_navigator` exit code `-11` 的 core/backtrace；后端日志不能替代该证据。

真车验收时应把“命令提交成功”“bridge 接受”“Nav2 executing”“小车产生有效运动”作为四个独立检查点，不得合并成一个“成功”。

## 15. 待团队确认的决策

建议默认值如下：

| 决策 | 建议默认值 |
| --- | --- |
| 正式 App telemetry | rosbridge 只读直连 |
| 正式 App command | 后端统一下发 |
| 后端到机器人 transport | 受控 robot agent 或内网 adapter，不开放任意 ROS 代理 |
| 导航并发 | 每机器人最多一个活动 task，不排队 |
| Stop | 两种模式都只发布 `/inspection_map/stop_navigation`；bridge 单次 cancel 当前 goal 并有限发布零速，重复请求幂等 |
| 状态更新 | 初期 HTTP polling，后续可加 SSE；高频 telemetry 不走 API |
| 地图一致性 | `mapId + mapRevision/hash` 强校验 |
| initial pose | 独立高权限，导航活动时拒绝 |
| 命令自动降级 | 正式模式不自动从后端降级为 App 直连写命令 |
| debug | 继续支持现有 `inspection_map_debug_app.dart + ROSBRIDGE_URL` |

在这些决策冻结前，不建议让后端、Flutter 和机器人 bridge 分别自行发明状态名和重试规则。优先固定 correlation id、幂等、状态语义和地图版本合同，再开始正式 App 切换。
