# 医疗单据结构化展示 · 后端优化 Prompt

将下面整段复制给后端开发或 AI，在现有 Spring Boot 医疗模块上实现。前端仓库：`SECP-frontend`，接口约定见 `docs/医疗档案与单据接口文档.md`。

---

## 角色与目标

你是智慧养老平台后端工程师。当前移动端「医疗单据详情」展示 OCR 全文效果差：百度通用 OCR 返回的 `fullText` 多为「一行一个词」（如 `检验项目` / `碳13尿素呼气试验` 分两行），前端只能启发式解析，出现大量无意义的「标题卡片」。

**目标：** 在**不改变**现有 `POST /v1/medical/smart-recognize` 路径的前提下，让 `GET /v1/medical/documents/{id}` 返回**可直接渲染的结构化字段**，使检验申请单、处方等能稳定以「字段名 | 字段值」表格展示。

---

## 现状（请先阅读再改）

- 智能识别：`POST /v1/medical/smart-recognize` → 存单据 + `fullText` + 可选 `ocr`（含 `specializedRaw`、`routedSpecializedApi`）。
- 详情：`GET /v1/medical/documents/{id}` → 至少有 `title`、`docCategory`、`fullText`、`routedSpecializedApi`；前端已支持 PATCH `title`/`fullText`/`docCategory`、DELETE 删除。
- 问题：很多检验单 `specializedRaw` 为空或未返回；`fullText` 无冒号分隔；`extractedFields` 只有类别/日期/关键词，没有检验项目等表格字段。

---

## 必须实现（按优先级）

### P0 — 详情接口补齐 OCR 与结构化 JSON

`GET /v1/medical/documents/{id}` 的 `data` 中**必须**包含：

```json
{
  "id": 3,
  "title": "…",
  "docCategory": "LAB_REPORT",
  "fullText": "…",
  "routedSpecializedApi": "medical_report_detection",
  "extractedFields": {
    "docCategory": "LAB_REPORT",
    "normalizedDates": [],
    "detectedDateTexts": [],
    "matchedKeywords": []
  },
  "ocr": {
    "fullText": "…",
    "routedSpecializedApi": "medical_report_detection",
    "structuredRouteSource": "keyword_text",
    "specializedRaw": { }
  }
}
```

要求：

- `ocr` 与识别入库时一致，**不要**在详情里丢掉 `specializedRaw`。
- 若识别时调用了百度云结构化接口，`specializedRaw` 不得为 null（失败则写明原因字段，见 P2）。

### P0 — 新增 `displayBlocks`（推荐，前端已预留解析）

在详情 `data` 根级增加 **`displayBlocks`**：有序数组，供移动端直接渲染表格，**无需**再猜 `fullText` 行边界。

```json
"displayBlocks": [
  { "type": "title", "text": "北京大学人民医院" },
  { "type": "kv", "label": "检验项目", "value": "碳13尿素呼气试验" },
  { "type": "kv", "label": "样本类型", "value": "呼气" },
  { "type": "kv", "label": "数量", "value": "1" },
  { "type": "kv", "label": "执行科室", "value": "消化内科实验室（临检）" }
]
```

| type | 字段 | 说明 |
|------|------|------|
| title | text | 医院名、单据名等标题行（0～3 条即可） |
| kv | label, value | 字段对，**必填** |
| note | text | 备注、标本要求等长文本 |
| paragraph | text | 兜底段落 |

**生成规则（入库或读详情时组装）：**

1. **优先**从 `ocr.specializedRaw` 按单据类型做字段映射（见下方映射表）。
2. 若无结构化 JSON，对 `fullText` 做服务端「标签-值配对」：连续两行，上一行像字段名（≤20 字或以 项目/类型/科室/号/要求/说明 结尾）、下一行像内容 → 合成一条 `kv`。
3. 仍无法配对的内容放入 `note` 或 `paragraph`。
4. 同时可生成带冒号的 `fullText` 副本便于人工阅读（可选）：`检验项目：碳13尿素呼气试验\n…`。

`smart-recognize` 响应里的 `documentId` 对应单据，**首次识别完成时即写入** `displayBlocks` 到 DB；PATCH 修改 `fullText` 后应重新生成或标记 `displayBlocksStale`（二选一，文档写清）。

### P1 — 强化结构化路由

在 `MedicalOcrService`（或等价类）中：

- 检验申请单、化验单 → 必须尝试 `medical_report_detection`（或项目已接入的检验结构化 API）。
- 处方 → `medical_prescription`。
- 记录 `structuredRouteSource`、`routedSpecializedApi`；结构化失败时 **不要静默**，在 `ocr` 中增加：

```json
"structuredError": "未开通检验报告接口 / 欠费 / 版式不匹配"
```

### P1 — PATCH 与 displayBlocks 一致

`PATCH /v1/medical/documents/{id}` 当 body 含 `fullText` 时：

- 重新跑 P0 第 2 步生成 `displayBlocks` 并返回在 `data` 中；或
- 返回 `displayBlocksStale: true`，前端仅展示纯文本。

### P2 — 可选 `structuredFields` 扁平 map

除 `displayBlocks` 外，可增加扁平对象便于搜索：

```json
"structuredFields": {
  "检验项目": "碳13尿素呼气试验",
  "样本类型": "呼气"
}
```

键为**中文展示名**，值为字符串。

---

## 百度云 specializedRaw → displayBlocks 映射参考

按 `routedSpecializedApi` 选解析器；字段名以百度实际返回为准，下面是目标 **label**（中文）：

| 目标 label | 处方/检验常见 JSON 路径（示例，需按真实响应调整） |
|------------|--------------------------------------------------|
| 检验项目 | test_item / ItemName / words 等 |
| 样本类型 | sample_type |
| 数量 | count / Num |
| 执行科室 | department / exec_dept |
| 标本要求 | sample_requirement |
| 处方号 | prescription_id / RecipeNum |
| 姓名 | Name / patient_name |
| 性别 | Sex |
| 年龄 | Age |

实现方式：每类 API 一个 `XxxStructuredMapper.toDisplayBlocks(Map raw)`，单元测试用真实百度 JSON fixture。

---

## 验收标准（必须全部通过）

1. 用一张**门诊检验申请单**走 smart-recognize 后，详情 `displayBlocks` 至少包含 **检验项目、样本类型** 两条 `kv`，且 value 非空。
2. 详情响应中 `ocr.specializedRaw` 在已成功调结构化接口时不为 null。
3. 前端不再出现「12 个相同灰色标题卡、标签与值分离」——由联调截图确认。
4. PATCH 修改 `fullText` 后，再次 GET 详情，`displayBlocks` 与全文一致或明确 stale。
5. DELETE 单据后 GET 列表无该 id（已有能力保持）。

---

## 不要做的事

- 不要把百度 AK/SK 下发给前端。
- 不要只存 `fullText` 而不存 `ocr` / `displayBlocks`。
- 不要 breaking change 已有 GET 列表字段；`displayBlocks` 为新增可选字段。

---

## 参考前端消费逻辑（联调用）

- 有 `displayBlocks` → 只渲染表格 + 折叠「原始 OCR 全文」。
- 无 `displayBlocks` 有 `specializedRaw` → 展平 JSON 为 kv 表。
- 仅有 `fullText` → 前端做标签-值配对兜底（效果弱于后端 displayBlocks）。

接口文档同步更新：`docs/医疗档案与单据接口文档.md` 增加 `displayBlocks` 章节。

---

## 交付物

1. 代码：详情组装 `displayBlocks`、识别入库写入、PATCH 刷新逻辑。
2. 单测：至少 2 个 fixture（检验申请单、处方）。
3. 更新接口文档 + 一条 `curl` 示例返回含 `displayBlocks` 的 JSON。
