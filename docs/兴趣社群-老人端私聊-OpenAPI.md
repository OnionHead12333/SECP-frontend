# 兴趣社群 · 老人端私聊 API（OpenAPI 风格）

> 供 `SCEP-backend` 直接实现与联调。全模块汇总见 **[兴趣社群-接口文档.md](./兴趣社群-接口文档.md)**。  
> **范围：** 老人端 **一对一私聊**（拉取历史、发送文字/语音/图片、媒体按需下载）。  
> **不含：** 群聊、好友、子女端（见汇总文档对应章节）。

| 项目 | 值 |
|------|-----|
| OpenAPI | `3.0.3`（本文档为 Markdown 描述，可手工转为 YAML） |
| Servers | `http://localhost:8080/api` |
| 全局路径前缀 | `/api`（Spring `context-path`） |
| 业务路径前缀 | `/v1/elder/direct-messages` |
| 鉴权 | `Authorization: Bearer <JWT>`，`role=elder` |
| 统一响应 | `ApiResponse<T>`（二进制下载除外） |

**前端现状：** 私聊页 `CommunityDirectChatPage` 已对接 `InterestCommunityDirectApi` / `CommunityDirectChatService`；消息模型复用 `InterestCommunityVoiceMessage`；媒体播放/图片走 `CommunityMediaCache` + `/v1/community-voice|image/{messageId}/file`。

---

## 目录

1. [通用约定](#1-通用约定)
2. [数据模型（components/schemas）](#2-数据模型componentsschemas)
3. [接口列表](#3-接口列表)
4. [路径明细](#4-路径明细)
5. [数据库与线程规则](#5-数据库与线程规则)
6. [错误码与业务规则](#6-错误码与业务规则)
7. [前端字段映射](#7-前端字段映射)

---

## 1. 通用约定

### 1.1 SecuritySchemes

与群聊文档一致：

```yaml
BearerAuth:
  type: http
  scheme: bearer
  bearerFormat: JWT
```

所有下文接口均需：`security: [BearerAuth]`，且 JWT 中 `role` 必须为 `elder`。

### 1.2 ApiResponse 信封

与 [`兴趣社群-老人端群聊-OpenAPI.md`](./兴趣社群-老人端群聊-OpenAPI.md) §1.2 相同：`code=0` 为成功；多数业务错误亦可能 HTTP 200。

### 1.3 scopeKey 与线程键

| 概念 | 规则 |
|------|------|
| 当前老人 scope | 与群聊相同：`phone_{11位}` 优先，否则 `elder_{profileId}` |
| 对方 scope | 路径参数 `peerScopeKey`（如 `demo_peer_wang`、`phone_13800001101`） |
| 线程唯一键 | `participant_a_scope_key` = 字典序较小者，`participant_b_scope_key` = 较大者 |
| 前端本地键（仅演示） | `interest_comm_direct_v1_{min}__{max}`，与上表逻辑一致 |

**禁止** 与自己私聊：`peerScopeKey == 当前用户 scopeKey` → `code=4000`。

### 1.4 时间字段

- 响应提供 **`createdAtMillis`**（long，毫秒）。
- 库表 `direct_messages.created_at` 为 `DATETIME(3)`。

### 1.5 分页（与群聊对齐）

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `before` | string | 无 | 游标：返回比该 `id` **更早** 的消息（向上翻页） |
| `limit` | integer | 50 | 单页条数，最大 **200** |

响应 `MessagePage`：`items` 按 **`created_at ASC`**；`hasMore` + `nextBefore` 供客户端继续拉更早记录。  
首屏（无 `before`）应返回**最近一页**升序消息，以便前端正序列表打开后滚到底部。

---

## 2. 数据模型（components/schemas）

### 2.1 DirectMessage

私聊单条消息。字段与群聊 `CommunityMessage` 对齐，便于前端 **同一模型** `InterestCommunityVoiceMessage`。

```yaml
DirectMessage:
  type: object
  required:
    - id
    - communityId
    - peerScopeKey
    - role
    - senderDisplay
    - senderScopeKey
    - kind
    - createdAtMillis
    - mine
  properties:
    id:
      type: string
      example: direct_1_elder1_voice
    communityId:
      type: string
      description: 固定为 direct，便于前端区分群聊/私聊
      example: direct
    peerScopeKey:
      type: string
      description: 会话对方 scope（相对当前登录老人）
      example: demo_peer_wang
    role:
      type: string
      enum: [elder, child]
      description: 老人端发送均为 elder；演示种子可能含对方消息
    senderDisplay:
      type: string
      example: 张建国
    senderScopeKey:
      type: string
      example: phone_13800138001
    senderAvatarUrl:
      type: string
      nullable: true
    senderEmoji:
      type: string
      nullable: true
      description: 演示账号无头像 URL 时使用
    kind:
      type: string
      enum: [voice, text, image]
    textContent:
      type: string
      default: ""
    audioUrl:
      type: string
      nullable: true
      example: /uploads/community_voice/direct_elder1_20260410.m4a
    durationMs:
      type: integer
      minimum: 0
      description: 语音必填且 >0；列表与发送响应均需返回，避免前端显示 1″
    imageUrl:
      type: string
      nullable: true
      example: /uploads/community_image/uuid.jpg
    createdAtMillis:
      type: integer
      format: int64
    createdAt:
      type: string
      format: date-time
      nullable: true
    mine:
      type: boolean
      description: sender_scope_key == 当前老人 scopeKey
```

### 2.2 DirectMessagePage

```yaml
DirectMessagePage:
  type: object
  required: [items, hasMore]
  properties:
    items:
      type: array
      items:
        $ref: '#/components/schemas/DirectMessage'
    hasMore:
      type: boolean
    nextBefore:
      type: string
      nullable: true
      description: 上一页游标，客户端下次传 before
```

### 2.3 SendDirectTextMessageRequest

```yaml
SendDirectTextMessageRequest:
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

### 2.4 DirectThreadSummary（可选，后续扩展）

当前 Flutter **未调用** 线程列表接口；若后端需要「最近私聊」入口可另行实现。

```yaml
DirectThreadSummary:
  type: object
  required: [peerScopeKey, updatedAtMillis]
  properties:
    peerScopeKey:
      type: string
    peerDisplayName:
      type: string
    peerEmoji:
      type: string
      nullable: true
    latestMessage:
      $ref: '#/components/schemas/DirectMessage'
      nullable: true
    updatedAtMillis:
      type: integer
      format: int64
```

---

## 3. 接口列表

| 方法 | 路径 | operationId | 说明 |
|------|------|-------------|------|
| GET | `/v1/elder/direct-messages/threads/{peerScopeKey}/messages` | listDirectMessages | 分页拉取与某人的私聊历史 |
| POST | `/v1/elder/direct-messages/threads/{peerScopeKey}/messages` | sendDirectMessage | 发送文字 / 语音 / 图片 |
| DELETE | `/v1/elder/direct-messages/threads/{peerScopeKey}/messages` | clearDirectMessagesForViewer | 清空私聊（仅当前用户视角，不删除消息） |
| GET | `/v1/community-voice/{messageId}/file` | downloadCommunityVoice | **复用** 群聊语音下载（校验私聊消息归属） |
| GET | `/v1/community-image/{messageId}/file` | downloadCommunityImage | **复用** 群聊图片下载 |

**关联（非本文档主体）：**

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/v1/elder/friends` | 好友列表 → 进入私聊页 |
| POST | `/v1/elder/friends` | 群聊点头像加好友 |
| POST | `/v1/elder/profile/avatar` | 换头像（见群聊 OpenAPI §4.10） |

---

## 4. 路径明细

### 4.1 GET `/v1/elder/direct-messages/threads/{peerScopeKey}/messages`

**summary：** 分页拉取与指定 `peerScopeKey` 的一对一消息（升序）。

**parameters：**

| name | in | type | required | default | description |
|------|-----|------|----------|---------|-------------|
| peerScopeKey | path | string | yes | | 对方 scopeKey |
| before | query | string | no | | 游标：比该 `id` 更早的消息 |
| limit | query | integer | no | 50 | 最大 200 |

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
                $ref: '#/components/schemas/DirectMessagePage'
      example:
        code: 0
        message: success
        data:
          items:
            - id: direct_1_wang_voice
              communityId: direct
              peerScopeKey: demo_peer_wang
              role: elder
              senderDisplay: 王阿姨
              senderScopeKey: demo_peer_wang
              senderEmoji: "👵"
              kind: voice
              audioUrl: /uploads/community_voice/direct_wang_20260408.m4a
              durationMs: 3800
              createdAtMillis: 1712564760000
              mine: false
            - id: direct_1_elder1_voice
              communityId: direct
              peerScopeKey: demo_peer_wang
              role: elder
              senderDisplay: 张建国
              senderScopeKey: phone_13800138001
              kind: voice
              audioUrl: /uploads/community_voice/direct_elder1_20260410.m4a
              durationMs: 5100
              createdAtMillis: 1712716320000
              mine: true
          hasMore: false
          nextBefore: null
```

**服务端行为：**

1. 解析当前老人 `ownerScope`；校验 `peerScopeKey != ownerScope`
2. 按 §5 查找或**不创建**线程（无消息时返回 `items: []`）
3. 查询 `direct_messages` WHERE `thread_id = ?`，`created_at ASC`
4. 每条序列化时：
   - `communityId` 固定 `"direct"`
   - `peerScopeKey` = 路径参数（会话对方）
   - `mine = (sender_scope_key == ownerScope)`
   - 填充 `senderAvatarUrl` / `senderEmoji`（规则同群聊 OpenAPI §6）
5. 单线程保留最近 **200** 条（可配置）
6. **不过滤** `system` 类消息（私聊无群助手）；若未来有系统通知，单独约定 `senderScopeKey`

**分页 SQL 示意：**

- 无 `before`：取最近 `limit` 条后按时间 ASC 返回（或子查询 `ORDER BY created_at DESC LIMIT n` 再反序）
- 有 `before`：取 `created_at < (SELECT created_at FROM direct_messages WHERE id = ?)` 的更早记录

---

### 4.2 POST `/v1/elder/direct-messages/threads/{peerScopeKey}/messages`

**summary：** 向指定好友/群友发送私聊消息；首次发送时 **自动创建** `direct_message_threads`。

**parameters：**

| name | in | type | required |
|------|-----|------|----------|
| peerScopeKey | path | string | yes |

#### 4.2.1 文字消息

```yaml
content:
  application/json:
    schema:
      $ref: '#/components/schemas/SendDirectTextMessageRequest'
    example:
      kind: text
      textContent: 王阿姨，明天公园见
```

#### 4.2.2 语音消息

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
        durationMs:
          type: integer
          description: 可选，客户端探测时长；未传时服务端解析文件
```

| 校验 | 规则 |
|------|------|
| 最短时长 | ≥ **400ms**，否则 `code=4000` |
| 存储 | `/uploads/community_voice/{uuid}.m4a`（与群聊共用目录即可） |
| 字段 | `message_kind=voice`，`audio_url`、`duration_ms`（**必须 >0**） |

#### 4.2.3 图片消息

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
| 字段 | `message_kind=image`，`image_url` |

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
                $ref: '#/components/schemas/DirectMessage'
      example:
        code: 0
        message: success
        data:
          id: direct_20260525143000_abc
          communityId: direct
          peerScopeKey: demo_peer_wang
          role: elder
          senderDisplay: 张建国
          senderScopeKey: phone_13800138001
          kind: text
          textContent: 王阿姨，明天公园见
          createdAtMillis: 1716634200000
          mine: true
```

**服务端行为：**

1. `peerScopeKey != 当前 scope`，否则 `4000`
2. `UPSERT` 线程：`participant_a/b_scope_key` 字典序 + 可选 `participant_*_elder_profile_id`
3. 生成 `id` 建议：`direct_{threadId}_{uuid}` 或 `dm_{snowflake}`，**全局唯一**（供媒体下载）
4. 写入 `direct_messages`：`sender_role=elder`，`sender_display_name` 来自档案/用户
5. 更新 `direct_message_threads.updated_at`
6. 超 200 条时修剪最旧记录（**不删**已上传媒体文件，或异步 GC，与群聊策略一致）
7. **不要求** 对方在好友表中（群聊点头像可直接进私聊）；若产品要求仅好友可聊，返回 `403` 并在此文档注明

---

### 4.3 DELETE `/v1/elder/direct-messages/threads/{peerScopeKey}/messages`

**summary：** 清空当前私聊会话（**仅隐藏**该查看者的更早消息，不删除 `direct_messages` 行与媒体文件）。

**parameters：**

| name | in | type | required | description |
|------|-----|------|----------|-------------|
| peerScopeKey | path | string | yes | 对方 scopeKey |

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
                type: object
                required: [peerScopeKey, viewerScopeKey, clearBeforeMillis]
                properties:
                  peerScopeKey:
                    type: string
                    example: demo_peer_wang
                  viewerScopeKey:
                    type: string
                    example: phone_13800138001
                  clearBeforeMillis:
                    type: integer
                    format: int64
```

**服务端行为（与群聊清空一致的软隐藏语义）：**

1. 解析当前老人 `viewerScopeKey`（即当前登录 elder scope）
2. 查找/定位该 `peerScopeKey` 对应的 `direct_message_threads` 线程（由 `{peerScopeKey}` 与当前 scope 共同构造字典序参与者键）
3. `UPSERT direct_message_clear`：
   - 唯一键：`(thread_id, scope_key)`
   - 更新：`clear_before_millis = 当前毫秒时间戳`
4. 对该查看者后的 GET 列表过滤：
   - 仅返回 `direct_messages.created_at > clear_before_millis` 的记录
5. **不影响** 另一参与者（对方有各自的 `scope_key` 视角清空）

----

### 4.4 GET `/v1/community-voice/{messageId}/file`（复用）

**summary：** 按消息 ID 下载语音；**同时支持**群聊 `interest_community_messages` 与私聊 `direct_messages`。

**鉴权与归属校验：**

1. JWT `role=elder`
2. 根据 `messageId` 查表（先私聊后群聊，或统一 `message_id` 命名空间）
3. 私聊：当前老人 scope 须为该线程参与者之一
4. 返回二进制流，`Content-Type: audio/m4a` 或 `audio/aac`；**不走** JSON 信封

前端接入后：`CommunityMediaDownloader` / `CommunityVoicePlayback` 对 `audioUrl` 为空或需鉴权时走此接口（与群聊相同）。

---

### 4.5 GET `/v1/community-image/{messageId}/file`（复用）

规则同 §4.3，校验私聊 `message_kind=image` 归属后返回 `image/jpeg` 等。

---

## 5. 数据库与线程规则

DDL 见 **`sql/table_v14.sql`** §16.6–16.7。

### 5.1 `direct_message_threads`

| 列 | 说明 |
|----|------|
| `participant_a_scope_key` | `min(scopeA, scopeB)` |
| `participant_b_scope_key` | `max(scopeA, scopeB)` |
| `participant_*_elder_profile_id` | 可空；演示账号 `demo_peer_*` 无档案 |
| `updated_at` | 最近一条消息时间，可供可选线程列表排序 |

唯一键：`uk_direct_thread_participants (participant_a_scope_key, participant_b_scope_key)`。

### 5.2 `direct_messages`

| 列 | API 字段 |
|----|----------|
| `id` | `id` |
| `thread_id` | （内部） |
| `sender_scope_key` | `senderScopeKey` |
| `sender_display_name` | `senderDisplay` |
| `sender_role` | `role` |
| `message_kind` | `kind` |
| `text_content` | `textContent` |
| `audio_url` | `audioUrl` |
| `image_url` | `imageUrl` |
| `duration_ms` | `durationMs` |
| `created_at` | `createdAtMillis` |

演示种子见 **`sql/initial_v14.sql`**（张建国 ↔ 王阿姨 两条语音）。

### 5.3 私聊「清空」说明

当前 **`兴趣社群.md` §11.4 未定义** 私聊清空接口；前端私聊页亦无清空按钮。  
若后续需要与群聊一致的「仅对自己隐藏」，可新增表 `direct_message_chat_clear(viewer_scope_key, peer_scope_key, clear_before_millis)` 及 `DELETE .../threads/{peerScopeKey}/messages`；**V14 未包含该表**。

---

## 6. 错误码与业务规则

| 场景 | code | message 示例 |
|------|------|----------------|
| 未带 token | 401 | 未登录 |
| 非 elder 角色 | 403 | 无权限 |
| `peerScopeKey` 为自己 | 4000 | 不能与自己私聊 |
| 对方 scope 不存在 / 非法 | 404 | 用户不存在 |
| 语音时长 < 400ms | 4000 | 录音时间太短 |
| `durationMs` 为 0 的语音消息入库 | — | **禁止**；列表须返回真实时长 |
| 翻页 `limit` > 200 | 4000 | limit 不能超过 200 |
| 仅允许好友私聊（若启用） | 403 | 请先添加对方为好友 |

**消息上限：** 每线程最近 200 条。

**入口场景（产品）：**

| 用户操作 | 前端行为 | 后端接口 |
|----------|----------|----------|
| 好友列表进入私聊 | `CommunityDirectChatPage(peerScopeKey: …)` | 打开后 `GET .../messages` |
| 群聊点击他人头像 → 私聊 | 同上 | 可先 `POST /v1/elder/friends`（可选），再 `GET/POST` 私聊 |
| 发送文字/语音/图片 | 本地 append（待接 API） | `POST .../messages` |

**头像展示优先级**（序列化 `DirectMessage` 时，与群聊一致）：

1. `users.avatar_url` → `senderAvatarUrl`
2. `community_demo_peer_profiles.emoji` → `senderEmoji`
3. 显示名首字（前端兜底）

---

## 7. 前端字段映射

| 后端 `DirectMessage` | `InterestCommunityVoiceMessage` | 备注 |
|----------------------|----------------------------------|------|
| `communityId: "direct"` | `communityId` | 固定值 |
| `peerScopeKey` | （路由参数 `widget.peerScopeKey`） | 响应可带，解析 JSON 时不必写入模型 |
| `kind` | `kind` | `voice` / `text` / `image` |
| `audioUrl` | `audioUrl` | 播放走下载接口 + 本地缓存 |
| `imageUrl` | `imageUrl` | `CommunityChatImage` |
| `durationMs` | `durationMs` | 避免 `clamp(1)` 假 1 秒 |
| `mine` | `mine` 或 `senderScopeKey == ownerScope` | 优先服务端 |
| `senderAvatarUrl` | `senderAvatarUrl` | 与 `ElderAvatarRepository` 本地路径合并策略待定 |

**已实现文件：**

- `mobile/lib/features/interest_community/data/interest_community_direct_api.dart`
- `mobile/lib/features/interest_community/data/community_direct_chat_service.dart`
- `mobile/lib/features/interest_community/presentation/community_direct_chat_page.dart`

---

## 附录 A：OpenAPI YAML 片段（可复制）

```yaml
openapi: 3.0.3
info:
  title: SECP Interest Community - Elder Direct Messages
  version: 1.0.0
  description: 老人端兴趣社群一对一私聊
servers:
  - url: http://localhost:8080/api
security:
  - BearerAuth: []
paths:
  /v1/elder/direct-messages/threads/{peerScopeKey}/messages:
    get:
      operationId: listDirectMessages
      tags: [ElderDirectMessages]
      parameters:
        - name: peerScopeKey
          in: path
          required: true
          schema: { type: string }
        - name: before
          in: query
          schema: { type: string }
        - name: limit
          in: query
          schema: { type: integer, default: 50, maximum: 200 }
      responses:
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
                        $ref: '#/components/schemas/DirectMessagePage'
    post:
      operationId: sendDirectMessage
      tags: [ElderDirectMessages]
      parameters:
        - name: peerScopeKey
          in: path
          required: true
          schema: { type: string }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SendDirectTextMessageRequest'
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
                durationMs:
                  type: integer
      responses:
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
                        $ref: '#/components/schemas/DirectMessage'
components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    DirectMessage:
      type: object
      required: [id, communityId, peerScopeKey, role, senderDisplay, senderScopeKey, kind, createdAtMillis, mine]
      properties:
        id: { type: string }
        communityId: { type: string, example: direct }
        peerScopeKey: { type: string }
        role: { type: string, enum: [elder, child] }
        senderDisplay: { type: string }
        senderScopeKey: { type: string }
        senderAvatarUrl: { type: string, nullable: true }
        senderEmoji: { type: string, nullable: true }
        kind: { type: string, enum: [voice, text, image] }
        textContent: { type: string }
        audioUrl: { type: string, nullable: true }
        durationMs: { type: integer }
        imageUrl: { type: string, nullable: true }
        createdAtMillis: { type: integer, format: int64 }
        mine: { type: boolean }
    DirectMessagePage:
      type: object
      required: [items, hasMore]
      properties:
        items:
          type: array
          items:
            $ref: '#/components/schemas/DirectMessage'
        hasMore: { type: boolean }
        nextBefore: { type: string, nullable: true }
```

---

## 附录 B：相关文件

| 文件 | 说明 |
|------|------|
| `docs/兴趣社群.md` | 总览 §11.4 |
| `docs/兴趣社群-老人端群聊-OpenAPI.md` | 群聊 + 媒体下载 + 头像 |
| `sql/table_v14.sql` | `direct_message_threads`、`direct_messages` |
| `sql/initial_v14.sql` | 私聊演示种子 |
| `mobile/.../community_direct_chat_page.dart` | 私聊 UI（已接 API） |
| `mobile/.../interest_community_direct_api.dart` | HTTP 封装 |
| `mobile/.../community_direct_chat_service.dart` | 业务入口 |
