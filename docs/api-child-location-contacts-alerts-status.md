# 子女端：定位 / 紧急联系人 / 求助信息 / 老人状态 — 后端接口说明

本文档依据融合版库脚本 `sql/table.sql`、`sql/initial.sql`（库名 `elder`）中的表结构与字段注释整理，供子女端（`users.role = child`）调用。**所有涉及某位老人业务数据的接口均须校验 `family_bindings`：** 当前登录用户的 `users.id` 等于 `family_bindings.child_user_id`，路径或参数中的老人标识为 `elder_profile_id`（老人档案 `elder_profiles.id`），且通常仅允许 `family_bindings.status = 'active'` 的绑定访问（`pending` 是否可读由产品决定，须在文档或接口层统一约定）。

**约定（可随项目统一调整）：**

- 基础路径前缀：`/api/v1`（示例）。老人端 V1 文档约定：Flutter `baseUrl` 已带 `/api` 时，代码里实际请求路径多为 **`/v1/...`**（等价于文档中的 `/api/v1/...`），本文件仍以 `/api/v1` 书写；联调时请与客户端保持一致。
- 路径风格：老人端《定位与活动状态接口》《SOS 接口》采用 **`/child/...`**（单数）。本文历史写法为 **`/children/...`**（复数）。**建议全项目统一为一种**（推荐与已写明的 V1 文档一致为 `child`），避免同端两套前缀。
- 统一响应结构（建议与老人端 V1 一致）：成功 `{ "code": 0, "message": "ok", "data": ... }`，失败 `{ "code": 非0, "message": "...", "data": null }`；下文示例为简短起见可能省略 `message`，实现时应补齐。
- 鉴权：`Authorization: Bearer <token>`，解析出 `user_id`（即 `users.id`），且角色为 `child`
- 路径中的 `{elderId}` 在融合版库中对应 **`elder_profiles.id`**（`elder_profile_id`）；与旧脚本中的「老人用户 id」在迁移脚本对齐时数值可能一致，但以档案 id 为准
- 时间格式：与老人端 V1 对齐时建议 **统一 ISO 8601**（如 `2026-04-11T10:30:05Z`）；库表可为 `DATETIME`，由服务端序列化约定。
- 分页：`page`（从 1 开始）、`pageSize`（默认 20，最大 100）

---

## 〇、子女端登录与注册（`users`）

与账号相关的数据落在 **`users`** 表：`username`、`password_hash`、`role`、`name`、`phone`、`avatar_url`、`gender`、`birthday` 等。约束：**`uk_username(username)`** 全局唯一；**`uk_phone_role(phone, role)`** 表示同一手机号在同一角色下只能有一条账号（例如同一手机号可各有一条 `elder` 与一条 `child`，但不能注册两个 `child`）。

以下路径为示例，可与网关/单体应用的实际前缀对齐。

### 0.1 注册（子女）

- **方法 / 路径：** `POST /api/v1/auth/child/register`
- **鉴权：** 无需登录
- **请求体：**

```json
{
  "username": "13900139001",
  "password": "plain-text-password",
  "name": "张明",
  "phone": "13900139001",
  "gender": "male",
  "birthday": "1980-03-10",
  "avatarUrl": null
}
```

- **字段说明：**

| 字段 | 必填 | 说明 |
|------|------|------|
| `username` | 建议必填 | 登录账号，演示数据中与 `phone` 一致即可；须满足 `uk_username` |
| `password` | 是 | 明文由 HTTPS 传输，服务端仅存储 **BCrypt 等哈希** 至 `password_hash` |
| `name` | 是 | 真实姓名，写入 `name` |
| `phone` | 是 | 手机号，写入 `phone`，与 `role=child` 组合唯一 |
| `gender` | 否 | `male` \| `female` \| `unknown`，默认 `unknown` |
| `birthday` | 否 | `yyyy-MM-dd`，可空 |
| `avatarUrl` | 否 | 对应 `avatar_url`，可空 |

- **服务端行为：** 插入 `users`，固定 `role = 'child'`；密码经哈希后写入 `password_hash`。**可选：** 注册成功后自动创建 `notification_settings`（`child_user_id = 新用户 id`，各推送开关默认开启），与 `initial.sql` 演示数据一致。

- **成功响应示例：** `201` 或 `200` + 业务码 0

```json
{
  "code": 0,
  "data": {
    "userId": 4,
    "username": "13900139001",
    "phone": "13900139001",
    "name": "张明",
    "role": "child"
  }
}
```

- **失败常见原因：** `409` / 业务码冲突 — `username` 已存在，或该 `phone` 已注册过 `child`（违反 `uk_phone_role`）；`422` — 格式校验失败。

### 0.2 登录（子女）

- **方法 / 路径：** `POST /api/v1/auth/child/login`
- **鉴权：** 无需登录
- **请求体：**

```json
{
  "username": "13900139001",
  "password": "plain-text-password"
}
```

- **说明：** `username` 与注册一致（若产品支持「手机号登录」，可与 `phone` 同值查询 `WHERE username = ? OR phone = ?` 且 `role = 'child'`，二选一实现即可，避免歧义）。

- **服务端行为：** 校验 `password` 与 `password_hash`；签发 **JWT** 或会话 **token**（载荷中建议包含 `sub`/`userId`、`role`，且 `role` 必须为 `child`）。

- **成功响应示例：**

```json
{
  "code": 0,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "user": {
      "id": 4,
      "username": "13900139001",
      "phone": "13900139001",
      "name": "张明",
      "role": "child",
      "gender": "male",
      "birthday": "1980-03-10",
      "avatarUrl": "/avatars/child1.jpg"
    }
  }
}
```

- **失败：** `401` — 账号不存在或密码错误；`403` — 账号存在但 `role` 非 `child`（不应颁发子女端 token）。

**与《注册绑定流程设计》对齐说明：** 该设计文档中的首版主链路是「子女填写老人信息 + 子女账号」**同一事务**内创建 `users(child)`、`elder_profiles`（必要时）、`family_bindings`（`active` / `pending`），并需要**按手机号查询老人主体**等接口。上文的「仅注册子女账号」适用于「分步调用」的后端拆分；若产品按设计文档实现，应**额外**提供：老人主体查询、创建主体、创建绑定等接口（路径可在 `auth` / `child` 模块下定稿）。

### 0.3 退出登录（可选）

- **方法 / 路径：** `POST /api/v1/auth/logout`
- **鉴权：** `Authorization: Bearer <token>`
- **说明：** 若使用无状态 JWT，可实现客户端丢弃 token；若服务端维护黑名单或会话表，在此接口作废当前 token。

---

## 一、涉及的数据表（与脚本一致）

| 模块 | 表名 | 说明 |
|------|------|------|
| 账号 | `users` | `username`、`password_hash`、`role`、`name`、`phone` 等；子女固定 `role=child` |
| 绑定关系 | `family_bindings` | `elder_profile_id`、`child_user_id`、`relation`、`is_primary`、`status` |
| 定位 | `location_logs` | `elder_profile_id`、`location_type`、`room_name`、`latitude`、`longitude`、`source`、`recorded_at` |
| 围栏（与地图/安全相关） | `geofences` | `elder_profile_id`、`name`、`center_latitude`、`center_longitude`、`radius`、`is_enabled` |
| 紧急联系人 | `emergency_contacts` | `elder_profile_id`、`name`、`phone`、`relation`、`priority` |
| 求助记录 | `emergency_alerts` | `elder_profile_id`、`alert_type`、`trigger_mode`、`status`、撤回/发出时间、`handled_by`、`location_id`、`remark` 等 |
| 老人活动状态 | `activity_logs` | `elder_profile_id`、`activity_type`、`start_time`、`end_time`、`duration`、`is_abnormal` |

**枚举（与脚本注释一致）：**

- `location_logs.location_type`：`indoor` | `outdoor`
- `location_logs.source`：`gps` | `wifi` | `beacon` | `sensor` | `gaode`
- `emergency_alerts.alert_type`：`sos` | `inactivity` | `abnormal_location`
- `emergency_alerts.trigger_mode`：`button` | `voice` | `sensor` | `rule_engine`
- `emergency_alerts.status`：`pending_revoke` | `sent` | `cancelled` | `handled` | `false_alarm`
- `activity_logs.activity_type`：`stationary` | `moving` | `go_out` | `come_home`

---

## 二、定位（`location_logs` / `geofences`）

### 2.1 获取某位老人最新一条定位

**用途：** 地图中心点、卡片展示「当前位置」。

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/location/latest`
- **权限：** 绑定校验通过
- **响应体示例：**

```json
{
  "code": 0,
  "data": {
    "id": 3,
    "elderId": 1,
    "locationType": "outdoor",
    "roomName": null,
    "latitude": 39.905,
    "longitude": 116.408,
    "source": "gps",
    "recordedAt": "2024-04-05 10:30:00"
  }
}
```

- **说明：** 无记录时 `data` 可为 `null`。

### 2.2 分页查询定位历史

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/locations`
- **查询参数：**
  - `page`、`pageSize`
  - 可选：`from`、`to`（按 `recorded_at` 过滤）
  - 可选：`locationType`、`source`
- **响应体：** `{ "list": [ ... ], "total": 100, "page": 1, "pageSize": 20 }`  
  列表项字段同 `location_logs` 一行（驼峰与库列对应即可）。

### 2.3 查询老人的地理围栏列表

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/geofences`
- **响应体：** `geofences` 表字段：`id`、`elderId`、`name`、`centerLatitude`、`centerLongitude`、`radius`（米）、`isEnabled`、`createdAt`、`updatedAt`。

**与《定位与活动状态接口 V1》对齐说明：** 老人端 V1 另约定子女端应提供（本文若未单列，实现时不应遗漏）：
- `GET /api/v1/child/elders/{elderId}/guard-rule`、`PUT` 同路径 — 对应 `elder_guard_rules`；
- `GET /api/v1/child/elders/{elderId}/home-geofence`、`PUT` 同路径 — 当前阶段以 **`name = 家`** 的单条围栏为主（与「列表 2.3」可同时存在：列表用于多围栏场景，home-geofence 用于产品主链路）；
- `GET /api/v1/child/elders/{elderId}/location-summary` — 聚合最新位置、`isHome`、`presenceSource`、`updatedAt` 等，而非仅原始 `location_logs` 一条；
- `GET /api/v1/child/elders/{elderId}/activity-alerts` — 未活动类提醒，数据仍来自 `emergency_alerts`（`alert_type = inactivity`、`trigger_mode = rule_engine`）。

---

## 三、紧急联系人（`emergency_contacts`）

子女仅可操作**已绑定老人**下的联系人。

**数据与语义（与 `sql/table_v7.sql` 一致）：** 表 `emergency_contacts` 含 `priority INT`，注释为 **数字越小越优先**（最先联络）。**不使用 `isPrimary` 字段**；联络顺序完全由 `priority` 表达。客户端展示列表时建议按 `priority` **升序**排列（自上而下：先联络 → 后联络）。

### 3.1 列表

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/emergency-contacts`
- **查询参数（可选）：** `sort=priority`（按 `priority` 升序，数字越小越优先）
- **响应字段：** `id`、`elderId`、`name`、`phone`、`relation`、`priority`、`createdAt`、`updatedAt`

**成功响应示例：**

```json
{
  "code": 0,
  "message": "ok",
  "data": [
    {
      "id": 12,
      "elderId": 1,
      "name": "张明",
      "phone": "13900139001",
      "relation": "儿子",
      "priority": 1,
      "createdAt": "2026-04-11T10:30:05Z",
      "updatedAt": "2026-04-11T10:30:05Z"
    }
  ]
}
```

### 3.2 新建（PUT，幂等）

- **方法 / 路径：** `PUT /api/v1/children/elders/{elderId}/emergency-contacts/{contactId}`

- **路径参数：** `elderId`（老人档案 id）；`contactId`（**由客户端生成**，建议 UUID，与资源一一对应，重复请求幂等）

- **请求体：**

```json
{
  "name": "张明",
  "phone": "13900139001",
  "relation": "儿子",
  "priority": 1
}
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | 是 | 姓名 |
| `phone` | 是 | 手机号 |
| `relation` | 是 | 与老人关系 |
| `priority` | 是 | 优先级，**正整数**；**数字越小越优先**（最先联络） |

- **语义：** 该 `contactId` 不存在时 **INSERT（新建）**；已存在时以请求体 **覆盖** 为最新内容（幂等重放）。不使用 `isPrimary`；若服务端曾有 `isPrimary` 顺延逻辑，应改为仅依据 **`priority`** 与业务规则处理。

- **校验：** `name`、`phone`、`relation` 非空；`priority` 为 ≥ 1 的整数。

### 3.3 修改（PATCH，部分更新）

- **方法 / 路径：** `PATCH /api/v1/children/elders/{elderId}/emergency-contacts/{contactId}`

- **路径参数：** `elderId`、`contactId`

- **请求体（示例）：**

```json
{
  "priority": 1
}
```

可只包含需要更新的字段（至少一项）。字段含义同 3.2 表（`name`、`phone`、`relation`、`priority` 均可按需出现）。

- **成功响应示例：** `200`

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "id": 12,
    "elderId": 1,
    "name": "张明",
    "phone": "13900139001",
    "relation": "儿子",
    "priority": 1,
    "createdAt": "2026-04-11T10:30:05Z",
    "updatedAt": "2026-04-20T09:12:00Z"
  }
}
```

### 3.4 删除

- **方法 / 路径：** `DELETE /api/v1/children/elders/{elderId}/emergency-contacts/{contactId}`
- **路径参数：** `elderId`、`contactId`
- **请求体：** 无（`DELETE` 不需要 body）。
- **成功响应示例：** `200`

```json
{
  "code": 0,
  "message": "ok",
  "data": null
}
```

**与《紧急联系人接口 V1（老人端）》对齐说明：** 老人端 V1 **暂不开放**编辑、删除、调序；库表无 `note` 列时前端不应依赖 `note`。子女端是否开放 3.3 / 3.4 由产品决定；若与老人端严格一致，子女端也可只保留 **列表 + 新增**。

---

## 四、求助信息（`emergency_alerts`）

### 4.1 分页列表（子女查看绑定老人的求助记录）

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/emergency-alerts`
- **查询参数：**
  - `page`、`pageSize`
  - 可选：`status`、`alertType`、`from`、`to`（按 `trigger_time`）

**与《SOS 接口 V1 / SOS 流程约定 V1》对齐说明：**
- V1 另提供**按子女维度**的列表：`GET /api/v1/child/emergency-alerts`（无需路径中的 `elderId`，列表项中带 `elderId`、`elderName` 等），适合安全首页汇总；本文「按老人维度」列表仍可用于老人详情页，两者可并存。
- **默认展示范围：** 流程约定明确子女端主列表**不展示** `pending_revoke`、`cancelled`（撤回窗口与已撤回不应「闪一下」打扰子女）；`inactivity` / `abnormal_location` 是否纳入同一列表由产品定。
- **详情路径：** V1 为 `GET /api/v1/child/emergency-alerts/{alertId}`（通过权限校验关联老人），不必强制带 `elderId`。
- **列表项字段（与表一致）：**

| 字段 | 说明 |
|------|------|
| `id` | 主键 |
| `elderId` | 业务上为老人档案 id（`elder_profile_id`） |
| `alertType` | sos / inactivity / abnormal_location |
| `triggerMode` | button / voice / sensor / rule_engine |
| `status` | pending_revoke / sent / cancelled / handled / false_alarm |
| `triggerTime` | 触发时间 |
| `revokeDeadline` | 撤回截止时间，可空 |
| `sentTime` | 正式发出时间，可空 |
| `cancelTime` | 取消时间，可空 |
| `cancelMode` | button / voice / system，可空 |
| `handledTime` | 处理完成时间，可空 |
| `handledBy` | 处理人用户 id（如子女账号），可空 |
| `locationId` | 关联 `location_logs.id`，可空 |
| `remark` | 备注 |
| `createdAt` | 创建时间 |

### 4.2 单条详情

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/emergency-alerts/{alertId}`
- **扩展（可选）：** 若存在 `locationId`，可一并返回对应 `location_logs` 片段（经纬度、时间），便于地图展示。

### 4.3 标记已处理（子女端）

- **方法 / 路径：** `PATCH /api/v1/children/elders/{elderId}/emergency-alerts/{alertId}/handle`  
  **与 V1 对齐的等价写法：** `POST /api/v1/child/emergency-alerts/{alertId}/handle`（无 `elderId` 路径段时须用 `alertId` + 绑定关系校验权限）。
- **请求体（与 SOS V1 一致建议）：**

```json
{
  "action": "handled",
  "remark": "已电话联系，老人安全"
}
```

或误报：`"action": "false_alarm"`，`remark` 可选。

- **服务端行为建议（对齐 SOS V1）：** 仅当 `status = sent` 时允许处理；`handled` → 更新 `handled_time`、`handled_by`；`false_alarm` → `status = false_alarm`。若仅用 `remark` 而无 `action`，与 Flutter 预留及 V1 文档不一致，**不推荐**。

---

## 五、老人状态（`activity_logs`）

脚本中**活动状态**由 `activity_logs` 表达（静止 / 移动 / 外出 / 回家及是否异常）。

### 5.1 当前或最近一条活动状态

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/activity/latest`
- **语义建议：** 返回**未结束**的一条（`end_time` 为空）或按 `start_time` 最新的一条，与产品定义一致即可。
- **响应体字段：** `id`、`elderId`、`activityType`、`startTime`、`endTime`、`duration`（秒）、`isAbnormal`、`createdAt`

### 5.2 活动历史分页

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/activities`
- **查询参数：** `page`、`pageSize`；可选 `from`、`to`、`activityType`、`isAbnormal`

### 5.3 日汇总（可选增强）

若 App 需要「今日是否异常、外出次数」等，可增加：

- **方法 / 路径：** `GET /api/v1/children/elders/{elderId}/activity/summary?date=2024-04-05`
- **响应示例：** `{ "date": "2024-04-05", "goOutCount": 1, "abnormalCount": 1, "lastActivityType": "go_out" }`  
  由服务端聚合 `activity_logs` 计算，字段以产品为准。

---

## 六、错误与权限

| HTTP / 业务 | 说明 |
|-------------|------|
| `401` | 未登录或 token 无效 |
| `403` | 已登录但不是 `child`，或该 `elderId`（档案 id）与当前用户无有效的 `family_bindings`（`child_user_id` + `elder_profile_id` + `status`） |
| `404` | 老人档案、联系人、求助单等资源不存在 |
| `409` | 注册时 `username` 或 `(phone, child)` 已存在 |
| `422` | 参数校验失败（手机号格式、枚举非法等） |

---

## 七、与脚本的字段对应关系（速查）

- **账号：** `users(username, password_hash, role, name, phone, gender, birthday, avatar_url, ...)`
- **定位：** `location_logs(elder_profile_id, location_type, room_name, latitude, longitude, source, recorded_at)`
- **围栏：** `geofences(elder_profile_id, name, center_latitude, center_longitude, radius, is_enabled, ...)`
- **紧急联系人：** `emergency_contacts(elder_profile_id, name, phone, relation, priority, ...)`
- **求助：** `emergency_alerts(elder_profile_id, alert_type, trigger_mode, status, trigger_time, revoke_deadline, sent_time, cancel_time, cancel_mode, handled_time, handled_by, location_id, remark, ...)`
- **老人状态：** `activity_logs(elder_profile_id, activity_type, start_time, end_time, duration, is_abnormal, ...)`

---

## 八、审查结论：与老人端 V1 文档的主要差异（速查）

| 维度 | 老人端 V1 文档 | 本文档原状 / 建议 |
|------|----------------|-------------------|
| 路径前缀 | `/api/v1/child/...` | 多为 `/api/v1/children/...` → **建议统一为 `child`** |
| 响应体 | 含 `message` | 示例常省略 → **建议始终带 `message`** |
| 时间 | ISO 8601 | 曾写可与 `yyyy-MM-dd HH:mm:ss` 混用 → **建议统一 ISO** |
| 注册 | 流程含多老人 + 绑定 + 事务 | 仅单接口注册子女 → **需补流程设计中的其它接口或改文案范围** |
| 定位 | `location-summary`、监护规则、`home-geofence`、`activity-alerts` | 原仅有 latest / 列表 / 围栏列表 → **已在 §2.3 注明须补齐** |
| 求助列表 | 全局 `GET /child/emergency-alerts` + 按条 `GET /child/emergency-alerts/{id}` | 原仅按老人路径 → **§4.1 已说明可并存** |
| 求助处理 | `POST .../handle` + `action`：`handled` \| `false_alarm`，且仅 `sent` 可处理 | 原为 `PATCH` + 仅 `remark` → **§4.3 已改为与 V1 一致** |
| 子女可见状态 | 默认不展示 `pending_revoke`、`cancelled` | 原文未强调 → **§4.1 已注明** |
| 紧急联系人 | 老人端仅查、增；无 `note` 列；无 `isPrimary`，用 `priority` | 子女端本文含改、删；**仅用 `priority`，不用 `isPrimary`** → **§三** |

---

*文档版本：依据 `sql/table.sql` / `sql/initial.sql`（融合版）整理；**紧急联系人字段以 `sql/table_v7.sql` 为准**。旧库请见 `sql/migrate_legacy_to_v4.sql`。已与《注册绑定流程设计》《紧急联系人接口 V1》《定位与活动状态（流程/接口）V1》《SOS（接口/流程）V1》做过交叉审查，差异见 §八。仅紧急联系人接口的精简版见 `docs/api-child-emergency-contacts.md`。*
