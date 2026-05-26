# 兴趣社群 · 老人端群聊 API（OpenAPI 风格）

> 供 `SCEP-backend` 直接实现与联调。对齐 `docs/兴趣社群.md`、`sql/table_v13.sql` 及 Flutter `mobile/lib/features/interest_community/`。  
> **范围：** 老人端兴趣社群 **群聊主链路**（目录、入群、消息、清空、语音下载）及群聊 UI 依赖的头像上传。  
> **不含：** 子女端预览、好友、私聊（见 `docs/兴趣社群.md` §11.3–11.5）。

| 项目 | 值 |
|------|-----|
| OpenAPI | `3.0.3`（本文档为 Markdown 描述，可手工转为 YAML） |
| Servers | `http://localhost:8080/api` |
| 全局路径前缀 | `/api`（Spring `context-path`） |
| 业务路径前缀 | `/v1/elder/interest-communities` |
| 鉴权 | `Authorization: Bearer <JWT>`，`role=elder` |
| 统一响应 | `ApiResponse<T>`（二进制下载除外） |

---

## 目录

1. [通用约定](#1-通用约定)
2. [数据模型（components/schemas）](#2-数据模型componentsschemas)
3. [接口列表](#3-接口列表)
4. [路径明细](#4-路径明细)
5. [建议表结构补充](#5-建议表结构补充)
6. [错误码与业务规则](#6-错误码与业务规则)

---

## 1. 通用约定

### 1.1 SecuritySchemes

```yaml
BearerAuth:
  type: http
  scheme: bearer
  bearerFormat: JWT
```

所有下文接口均需：`security: [BearerAuth]`，且 JWT 中 `role` 必须为 `elder`。

### 1.2 ApiResponse 信封

```yaml
ApiResponse:
  type: object
  required: [code, message]
  properties:
    code:
      type: integer
      description: "0=成功"
      example: 0
    message:
      type: string
      example: success
    data:
      description: 业务载荷，失败时可为 null
```

| HTTP | code | 说明 |
|------|------|------|
| 200 | `0` | 成功 |
| 200 | `4000` | 参数校验失败 |
| 200 | `401` / `4011` | 未登录 / token 过期 |
| 200 | `403` | 非老人角色 / 未入群即发消息等 |
| 200 | `404` | 社群或消息不存在 |
| 200 | `409` | 业务冲突（如重复入群） |

> 除 **语音文件下载** 外，业务错误也可能返回 HTTP 200，客户端以 `code != 0` 判断。

### 1.3 scopeKey 规则

与前端 `CommunityScope` 一致，写入 `interest_community_memberships.scope_key`、消息的 `sender_scope_key`、清空记录的 `viewer_scope_key`：

| 优先级 | 格式 | 示例 |
|--------|------|------|
| 1 | `phone_{11位手机号}` | `phone_13800138001` |
| 2 | `elder_{elderProfileId}` | `elder_12` |
| 系统 | `system` | 群助手欢迎语 |
| 演示群友 | `demo_peer_wang` 等 | 见 `community_demo_peer_profiles` |

### 1.4 时间字段

- API 响应中同时提供 **`createdAtMillis`**（long，毫秒，与前端一致）及可选 **`createdAt`**（ISO 8601）。
- 数据库存 `DATETIME(3)`，序列化时转换为毫秒时间戳。

---

## 2. 数据模型（components/schemas）

### 2.1 InterestCommunityBrief

社群目录项（列表 / 入群卡片）。

```yaml
InterestCommunityBrief:
  type: object
  required: [id, name, shortDescription, previewIcon, joined]
  properties:
    id:
      type: string
      description: 社群 ID
      example: taiji
      enum: [taiji, calligraphy, fitness, travel]
    name:
      type: string
      example: 太极晨练群
    shortDescription:
      type: string
    previewIcon:
      type: string
      description: emoji 图标
      example: "🥋"
    memberHint:
      type: string
      example: 约 328 人在练
    joined:
      type: boolean
      description: 当前登录老人是否已 active 入群
```

### 2.2 CommunityMessage

群聊消息（GET 列表 / POST 发送响应）。

```yaml
CommunityMessage:
  type: object
  required:
    - id
    - communityId
    - role
    - senderDisplay
    - senderScopeKey
    - kind
    - createdAtMillis
    - mine
  properties:
    id:
      type: string
      example: msg_taiji_20260411103000_001
    communityId:
      type: string
      example: taiji
    role:
      type: string
      enum: [elder, child]
      description: 发送者角色；群聊老人端发送均为 elder
    senderDisplay:
      type: string
      example: 张建国
    senderScopeKey:
      type: string
      example: phone_13800138001
    senderAvatarUrl:
      type: string
      nullable: true
      example: /uploads/avatars/phone_13800138001.jpg
    senderEmoji:
      type: string
      nullable: true
      description: 无头像 URL 时展示
      example: "👵"
    kind:
      type: string
      enum: [voice, text, image]
      description: 前端已支持 image；表结构需扩展 message_kind
    textContent:
      type: string
      default: ""
    audioUrl:
      type: string
      nullable: true
      example: /uploads/community_voice/uuid.m4a
    durationMs:
      type: integer
      minimum: 0
      default: 0
    imageUrl:
      type: string
      nullable: true
      example: /uploads/community_image/uuid.jpg
    createdAtMillis:
      type: integer
      format: int64
      example: 1712716200000
    createdAt:
      type: string
      format: date-time
      nullable: true
    mine:
      type: boolean
      description: 相对当前查看者是否在右侧（老人端=是否本人 scope）
```

### 2.3 MembershipSummary

```yaml
MembershipSummary:
  type: object
  required: [communityId, scopeKey, status, joinedAtMillis]
  properties:
    communityId:
      type: string
    scopeKey:
      type: string
    status:
      type: string
      enum: [active, left]
    joinedAtMillis:
      type: integer
      format: int64
    leftAtMillis:
      type: integer
      format: int64
      nullable: true
```

### 2.4 MembershipsResponse

```yaml
MembershipsResponse:
  type: object
  required: [joinedCommunityIds, scopeKey]
  properties:
    joinedCommunityIds:
      type: array
      items:
        type: string
      example: [taiji, calligraphy]
    scopeKey:
      type: string
      example: phone_13800138001
```

### 2.5 JoinCommunityRequest

```yaml
JoinCommunityRequest:
  type: object
  required: [communityId]
  properties:
    communityId:
      type: string
      example: taiji
```

### 2.6 MessagePage

```yaml
MessagePage:
  type: object
  required: [items, hasMore]
  properties:
    items:
      type: array
      items:
        $ref: '#/components/schemas/CommunityMessage'
    hasMore:
      type: boolean
    nextBefore:
      type: string
      nullable: true
      description: 上一页游标，供客户端下次传 before
```

### 2.7 SendTextMessageRequest

```yaml
SendTextMessageRequest:
  type: object
  required: [kind, textContent]
  properties:
    kind:
      type: string
      enum: [text]
    textContent:
      type: string
      minLength: 1
      maxLength: 2000
```

### 2.8 ClearChatResponse

```yaml
ClearChatResponse:
  type: object
  required: [communityId, viewerScopeKey, clearBeforeMillis]
  properties:
    communityId:
      type: string
    viewerScopeKey:
      type: string
    clearBeforeMillis:
      type: integer
      format: int64
      description: 此时间及之前的消息对当前用户不可见
```

### 2.9 AvatarUploadResponse

```yaml
AvatarUploadResponse:
  type: object
  required: [avatarUrl]
  properties:
    avatarUrl:
      type: string
      example: /uploads/avatars/phone_13800138001.jpg
```

---

## 3. 接口列表

| 方法 | 路径 | operationId | 说明 |
|------|------|-------------|------|
| GET | `/v1/elder/interest-communities` | listInterestCommunities | 社群目录 + 是否已加入 |
| GET | `/v1/elder/interest-communities/memberships` | listMemberships | 已加入群 ID |
| POST | `/v1/elder/interest-communities/memberships` | joinCommunity | 加入社群 |
| DELETE | `/v1/elder/interest-communities/memberships/{communityId}` | leaveCommunity | 退出社群 |
| GET | `/v1/elder/interest-communities/{communityId}/messages` | listCommunityMessages | 群消息分页（含清空过滤） |
| POST | `/v1/elder/interest-communities/{communityId}/messages` | sendCommunityMessage | 发送文字 / 语音 / 图片 |
| DELETE | `/v1/elder/interest-communities/{communityId}/messages` | clearCommunityMessagesForViewer | 清空记录（仅当前用户视角） |
| GET | `/v1/community-voice/{messageId}/file` | downloadCommunityVoice | 下载语音（二进制） |
| GET | `/v1/community-image/{messageId}/file` | downloadCommunityImage | 下载图片（二进制，建议） |
| POST | `/v1/elder/profile/avatar` | uploadElderAvatar | 上传头像（群聊点头像） |

---

## 4. 路径明细

### 4.1 GET `/v1/elder/interest-communities`

**summary：** 获取兴趣社群目录及当前老人是否已加入。

**parameters：** 无

**responses：**

```yaml
'200':
  description: OK
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                type: array
                items:
                  $ref: '#/components/schemas/InterestCommunityBrief'
      example:
        code: 0
        message: success
        data:
          - id: taiji
            name: 太极晨练群
            shortDescription: 一起练站桩、步法与呼吸节律…
            previewIcon: "🥋"
            memberHint: 约 328 人在练
            joined: true
          - id: calligraphy
            name: 书法交流群
            shortDescription: 硬笔、毛笔心得交流
            previewIcon: "🖌️"
            memberHint: 约 156 人在练
            joined: false
```

**服务端逻辑：**

- 查询 `interest_communities` where `is_active=1` order by `sort_order`
- `joined` = 是否存在 `interest_community_memberships` 且 `status=active`（当前 `elder_profile_id`）

---

### 4.2 GET `/v1/elder/interest-communities/memberships`

**summary：** 当前老人已加入（active）的社群 ID 列表。

**responses：**

```yaml
'200':
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                $ref: '#/components/schemas/MembershipsResponse'
      example:
        code: 0
        message: success
        data:
          joinedCommunityIds: [taiji, fitness]
          scopeKey: phone_13800138001
```

---

### 4.3 POST `/v1/elder/interest-communities/memberships`

**summary：** 加入指定兴趣社群。

**requestBody：**

```yaml
required: true
content:
  application/json:
    schema:
      $ref: '#/components/schemas/JoinCommunityRequest'
    example:
      communityId: taiji
```

**responses：**

```yaml
'200':
  description: 入群成功
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                $ref: '#/components/schemas/MembershipSummary'
'200 ':
  description: 业务失败示例（HTTP 仍可为 200）
  content:
    application/json:
      example:
        code: 404
        message: 社群不存在
        data: null
```

**服务端行为（事务内）：**

1. 校验 `communityId` 存在于 `interest_communities` 且 `is_active=1`
2. `INSERT` 或 `UPDATE` `interest_community_memberships` → `status=active`，写入 `scope_key`
3. 若该群 **无任何消息**：插入欢迎语  
   - `sender_scope_key=system`，`sender_display_name=群助手`，`message_kind=text`  
   - `text_content` 示例：`欢迎来到{群名}！可按住说话、点键盘输入文字，或点 + 发送图片。`
4. 若 `community_peer_seed_log` 无该 `community_id`：插入演示消息（王阿姨、李叔叔）并写 log
5. 返回 `MembershipSummary`

---

### 4.4 DELETE `/v1/elder/interest-communities/memberships/{communityId}`

**summary：** 退出社群（软退群，不删群消息）。

**parameters：**

| name | in | type | required | description |
|------|-----|------|----------|-------------|
| communityId | path | string | yes | 如 `taiji` |

**responses：**

```yaml
'200':
  content:
    application/json:
      example:
        code: 0
        message: success
        data: null
```

**服务端行为：**

- `interest_community_memberships.status` → `left`，`left_at=NOW()`
- **不删除** `interest_community_messages` 中历史记录
- 未入群或已 left → `404`

---

### 4.5 GET `/v1/elder/interest-communities/{communityId}/messages`

**summary：** 分页拉取群聊消息（升序），并应用当前用户的「清空记录」过滤。

**parameters：**

| name | in | type | required | default | description |
|------|-----|------|----------|---------|-------------|
| communityId | path | string | yes | | 社群 ID |
| before | query | string | no | | 游标：返回比该 `id` 更早的消息（向上翻页） |
| limit | query | integer | no | 50 | 最大 **200** |

**responses：**

```yaml
'200':
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                $ref: '#/components/schemas/MessagePage'
      example:
        code: 0
        message: success
        data:
          items:
            - id: demo_peer_taiji_1
              communityId: taiji
              role: elder
              senderDisplay: 王阿姨
              senderScopeKey: demo_peer_wang
              senderEmoji: "👵"
              kind: text
              textContent: 大家明天照常去公园练太极，记得带水杯。
              createdAtMillis: 1712620800000
              mine: false
            - id: msg_001
              communityId: taiji
              role: elder
              senderDisplay: 张建国
              senderScopeKey: phone_13800138001
              kind: voice
              audioUrl: /uploads/community_voice/abc.m4a
              durationMs: 4200
              createdAtMillis: 1712716200000
              mine: true
          hasMore: false
          nextBefore: null
```

**过滤规则：**

1. 须已 `active` 入群，否则 `403`
2. 读取 `interest_community_chat_clear`（见 §5）中当前老人 `viewer_scope_key` 的 `clear_before_millis`
3. SQL：`created_at > FROM_UNIXTIME(clear_before_millis/1000)`（无记录则不过滤）
4. 按 `created_at ASC` 排序；`mine = (sender_scope_key == 当前用户 scopeKey)`
5. 单群保留最近 **200** 条（与前端演示一致，可配置）

---

### 4.6 POST `/v1/elder/interest-communities/{communityId}/messages`

**summary：** 发送群消息（文字 JSON / 语音 multipart / 图片 multipart）。

**parameters：**

| name | in | type | required |
|------|-----|------|----------|
| communityId | path | string | yes |

#### 4.6.1 文字消息

```yaml
content:
  application/json:
    schema:
      $ref: '#/components/schemas/SendTextMessageRequest'
    example:
      kind: text
      textContent: 大家好，明天见
```

#### 4.6.2 语音消息

```yaml
content:
  multipart/form-data:
    schema:
      type: object
      required: [kind, file]
      properties:
        kind:
          type: string
          enum: [voice]
        file:
          type: string
          format: binary
          description: m4a / aac
```

| 校验 | 规则 |
|------|------|
| 最短时长 | ≥ **400ms**，否则 `code=4000` |
| 存储 | `/uploads/community_voice/{uuid}.m4a` |
| 字段 | 写 `audio_url`、`duration_ms` |

#### 4.6.3 图片消息（前端已支持，建议一并实现）

```yaml
content:
  multipart/form-data:
    schema:
      type: object
      required: [kind, file]
      properties:
        kind:
          type: string
          enum: [image]
        file:
          type: string
          format: binary
          description: jpg / png / webp，建议 ≤ 5MB
```

| 校验 | 规则 |
|------|------|
| 存储 | `/uploads/community_image/{uuid}.jpg` |
| 字段 | 写 `image_url`（需扩展表字段） |

**responses（三种类型相同）：**

```yaml
'200':
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                $ref: '#/components/schemas/CommunityMessage'
```

**前置条件：**

- 当前老人在该群 `membership.status=active`
- 自动填充 `sender_scope_key`、`sender_display_name`（来自 `users` / `elder_profiles`）
- `sender_role=elder`

---

### 4.7 DELETE `/v1/elder/interest-communities/{communityId}/messages`

**summary：** 清空聊天记录（**仅对当前登录老人隐藏历史**，不删库）。

**parameters：**

| name | in | path | required |
|------|-----|------|----------|
| communityId | path | string | yes |

**requestBody：** 无

**responses：**

```yaml
'200':
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                $ref: '#/components/schemas/ClearChatResponse'
      example:
        code: 0
        message: success
        data:
          communityId: taiji
          viewerScopeKey: phone_13800138001
          clearBeforeMillis: 1712800000000
```

**服务端行为：**

- **禁止** 物理删除 `interest_community_messages` 或媒体文件
- `UPSERT` `interest_community_chat_clear`：  
  `(viewer_scope_key, community_id) → clear_before_millis = 当前毫秒时间戳`
- 之后该用户 GET 消息仅返回 `createdAtMillis > clearBeforeMillis`
- **不影响** 其他群成员、子女端预览（子女使用独立 `viewer_scope_key`，见总文档 §11.5）

---

### 4.8 GET `/v1/community-voice/{messageId}/file`

**summary：** 下载群聊语音文件。

**parameters：**

| name | in | type | required |
|------|-----|------|----------|
| messageId | path | string | yes |

**responses：**

```yaml
'200':
  description: 音频二进制流
  content:
    audio/m4a:
      schema:
        type: string
        format: binary
    audio/aac:
      schema:
        type: string
        format: binary
```

**说明：**

- **不走** `ApiResponse` JSON 信封
- 校验 JWT；校验消息存在且当前用户有权访问该群（已入群或曾为成员，按产品定）
- `Content-Disposition: attachment; filename="{messageId}.m4a"`

---

### 4.9 GET `/v1/community-image/{messageId}/file`（建议）

**summary：** 下载群聊图片，规则同语音。

**responses：**

```yaml
'200':
  content:
    image/jpeg:
      schema:
        type: string
        format: binary
```

---

### 4.10 POST `/v1/elder/profile/avatar`

**summary：** 上传老人头像（群聊内点击自己头像更换）。

**requestBody：**

```yaml
content:
  multipart/form-data:
    schema:
      type: object
      required: [file]
      properties:
        file:
          type: string
          format: binary
          description: jpg/png，建议 ≤ 2MB
```

**responses：**

```yaml
'200':
  content:
    application/json:
      schema:
        allOf:
          - $ref: '#/components/schemas/ApiResponse'
          - type: object
            properties:
              data:
                $ref: '#/components/schemas/AvatarUploadResponse'
```

**行为：** 存储文件并更新 `users.avatar_url`；后续消息 `senderAvatarUrl` 优先取该字段。

---

## 5. 建议表结构补充

完整 DDL 见 **`sql/table_v14.sql`**（新建库直接执行）；已有 V13 库见该文件文末 **「V13 → V14 迁移」** 注释段。

### 5.1 `interest_community_messages`（V14 已含 image）

- `message_kind`：`voice` | `text` | `image`
- 新增 `image_url VARCHAR(512)`

### 5.2 `interest_community_chat_clear`（V14 新增）

对齐前端 `CommunityChatVisibilityRepository` 与 `DELETE .../messages` 软清空：

- 唯一键：`(viewer_scope_key, community_id)`
- `clear_before_millis`：该查看者不可见的上界时间戳
- 可选 `viewer_user_id`：操作者 `users.id`

---

## 6. 错误码与业务规则

| 场景 | code | message 示例 |
|------|------|----------------|
| 未带 token | 401 | 未登录 |
| 非 elder 角色访问老人端路径 | 403 | 无权限 |
| 未入群发消息 / 拉消息 | 403 | 请先加入该社群 |
| communityId 不存在 | 404 | 社群不存在 |
| 语音时长 < 400ms | 4000 | 录音时间太短 |
| 重复 active 入群 | 409 | 已是群成员 |
| 翻页 limit > 200 | 4000 | limit 不能超过 200 |

**消息上限：** 每群保留最近 200 条（插入新消息后异步或同步修剪）。

**头像展示优先级（序列化 `CommunityMessage` 时）：**

1. `users.avatar_url` → `senderAvatarUrl`
2. `community_demo_peer_profiles.emoji` → `senderEmoji`
3. 显示名首字（仅前端兜底，可不返回）

---

## 附录 A：OpenAPI YAML 片段（可复制）

```yaml
openapi: 3.0.3
info:
  title: SECP Interest Community - Elder Group Chat
  version: 1.0.0
  description: 老人端兴趣社群群聊
servers:
  - url: http://localhost:8080/api
security:
  - BearerAuth: []
paths:
  /v1/elder/interest-communities:
    get:
      operationId: listInterestCommunities
      tags: [ElderInterestCommunity]
      summary: 社群目录
      responses:
        '200':
          description: OK
  /v1/elder/interest-communities/memberships:
    get:
      operationId: listMemberships
      tags: [ElderInterestCommunity]
      summary: 已加入群列表
      responses:
        '200':
          description: OK
    post:
      operationId: joinCommunity
      tags: [ElderInterestCommunity]
      summary: 加入社群
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/JoinCommunityRequest'
      responses:
        '200':
          description: OK
  /v1/elder/interest-communities/memberships/{communityId}:
    delete:
      operationId: leaveCommunity
      tags: [ElderInterestCommunity]
      summary: 退出社群
      parameters:
        - name: communityId
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: OK
  /v1/elder/interest-communities/{communityId}/messages:
    get:
      operationId: listCommunityMessages
      tags: [ElderInterestCommunity]
      summary: 群消息列表
      parameters:
        - name: communityId
          in: path
          required: true
          schema:
            type: string
        - name: before
          in: query
          schema:
            type: string
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
            maximum: 200
      responses:
        '200':
          description: OK
    post:
      operationId: sendCommunityMessage
      tags: [ElderInterestCommunity]
      summary: 发送消息
      parameters:
        - name: communityId
          in: path
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SendTextMessageRequest'
          multipart/form-data:
            schema:
              type: object
              properties:
                kind:
                  type: string
                  enum: [voice, image]
                file:
                  type: string
                  format: binary
      responses:
        '200':
          description: OK
    delete:
      operationId: clearCommunityMessagesForViewer
      tags: [ElderInterestCommunity]
      summary: 清空记录（当前用户视角）
      parameters:
        - name: communityId
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: OK
  /v1/community-voice/{messageId}/file:
    get:
      operationId: downloadCommunityVoice
      tags: [ElderInterestCommunity]
      summary: 下载语音
      security:
        - BearerAuth: []
      parameters:
        - name: messageId
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Binary audio
  /v1/elder/profile/avatar:
    post:
      operationId: uploadElderAvatar
      tags: [ElderProfile]
      summary: 上传头像
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              required: [file]
              properties:
                file:
                  type: string
                  format: binary
      responses:
        '200':
          description: OK
components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    ApiResponse:
      type: object
      properties:
        code:
          type: integer
        message:
          type: string
        data: {}
    InterestCommunityBrief:
      type: object
    CommunityMessage:
      type: object
    JoinCommunityRequest:
      type: object
    MessagePage:
      type: object
    ClearChatResponse:
      type: object
```

---

## 附录 B：与 Flutter 前端映射

| 前端（当前本地演示） | 后端接口 |
|---------------------|----------|
| `CommunityCatalog` | GET `/v1/elder/interest-communities` |
| `CommunityMembershipRepository.join` | POST `.../memberships` |
| `CommunityMembershipRepository.leave` | DELETE `.../memberships/{communityId}` |
| `CommunityDemoRepository.loadMessagesForViewer` | GET `.../{communityId}/messages` |
| `CommunityDemoRepository.appendMessage` | POST `.../{communityId}/messages` |
| `CommunityDemoRepository.hideHistoryForViewer` | DELETE `.../{communityId}/messages` |
| `CommunityVoicePlayback` | GET `/v1/community-voice/{messageId}/file` |
| `CommunityChatMediaRepository` + 图片消息 | POST multipart `kind=image` + GET image file |
| `ElderAvatarRepository` | POST `/v1/elder/profile/avatar` |

---

**文档版本：** 2026-05-25 · 对齐前端软清空逻辑与 `kind=image` 扩展。
