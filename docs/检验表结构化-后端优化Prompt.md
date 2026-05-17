# 检验报告「检验结果表」· 后端优化 Prompt

将下面整段复制给后端开发或 AI。Flutter 端已支持渲染，**缺的是后端在 `displayBlocks` 中输出 `type: "table"`**。接口基础约定见 `docs/医疗档案与单据接口文档.md`。

---

## 角色与目标

你是智慧养老平台后端工程师。移动端「医疗单据详情」对**血常规、生化、检验报告单**等单据，需要把中间大段 **「检验项目 | 结果 | 单位 | 参考区间」** 以**表格**展示（可横向滚动），而不是拆成大量 `kv` 或一行一行标题。

**目标：** 在识别入库与详情接口中，向 `displayBlocks` 写入标准 **`table` 块**，使前端直接渲染检验结果表。

**不要**把整张表拆成几十条 `kv`（如「白细胞计数」「6.72」「10^9/L」各占一行），那样前端无法还原表格。

---

## 前端已支持的契约（必须按此输出）

### `displayBlocks` 中的 `table` 类型

```json
{
  "type": "table",
  "caption": "检验结果",
  "headers": ["检验项目", "结果", "单位", "参考区间"],
  "rows": [
    ["白细胞计数", "6.72", "10^9/L", "3.5-9.5"],
    ["中性粒细胞百分比", "62.0", "%", "40-75"],
    ["淋巴细胞百分比", "28.0", "%", "20-50"],
    ["红细胞计数", "4.85", "10^12/L", "4.3-5.8"],
    ["C-反应蛋白(CRP)", "0.50", "mg/L", "0-5"]
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | string | 是 | 固定 `"table"` |
| headers | string[] | 是 | 列名，建议 3～5 列 |
| rows | string[][] | 是 | 每行单元格数应与 headers 列数一致，不足可填空字符串 |
| caption | string | 否 | 表标题，如「检验结果」「左栏」「右栏」 |

### 推荐 `displayBlocks` 顺序（检验报告单）

```json
"displayBlocks": [
  { "type": "title", "text": "北京大学人民医院检验报告单" },
  { "type": "kv", "label": "姓名", "value": "邱羽橙" },
  { "type": "kv", "label": "性别", "value": "女" },
  { "type": "kv", "label": "年龄", "value": "20岁" },
  { "type": "kv", "label": "标本种类", "value": "血" },
  { "type": "kv", "label": "执行科室", "value": "检验科门诊化验室" },
  {
    "type": "table",
    "caption": "检验结果（左栏）",
    "headers": ["检验项目", "结果", "单位", "参考区间"],
    "rows": [ ["白细胞计数", "6.72", "10^9/L", "3.5-9.5"], "..." ]
  },
  {
    "type": "table",
    "caption": "检验结果（右栏）",
    "headers": ["检验项目", "结果", "单位", "参考区间"],
    "rows": [ ["红细胞分布宽度", "39.0", "fL", "39-46"], "..." ]
  },
  { "type": "kv", "label": "报告时间", "value": "2026-03-13 13:35" },
  { "type": "note", "text": "采样地点：西直门门诊抽血室1" }
]
```

---

## 现状问题（请针对性解决）

### 问题 1：版式是「左右双栏表」

常见纸质/拍照检验单**同一张表横向排两列**（左半：WBC、NEUT%…，右半：RDW、PLT、CRP…）。  
若 OCR 按阅读顺序拉平成全文，会变成：

```
检验项目
结果
单位
参考区间
白细胞计数
6.72
…
红细胞分布宽度
39.0
…
```

前端无法知道左右栏边界。**后端应在结构化阶段按版面或列拆成 1～2 个 `table` 块**（左栏 table + 右栏 table），或合并为一个 table 但行顺序正确。

### 问题 2：只有 `kv`、没有 `table`

当前若只输出：

```json
{ "type": "kv", "label": "检验项目", "value": "碳13尿素呼气试验" }
```

或把「白细胞计数」「6.72」拆成两条 `kv`，移动端**不会出现检验表**，只有字段列表。

### 问题 3：`specializedRaw` 未映射

`routedSpecializedApi = medical_report_detection` 时，百度云往往返回嵌套 JSON（项目列表、表格单元格等）。  
需要 **Mapper 转为 `displayBlocks` 的 table**，不能只存原始 JSON 让前端猜。

---

## 必须实现（按优先级）

### P0 — 生成 `displayBlocks` 中的 `table`

在以下时机写入/刷新 `display_blocks_json`（或等价字段）：

1. `POST /v1/medical/smart-recognize` 识别完成入库时  
2. `GET /v1/medical/documents/{id}` 组装详情时（与库中一致）  
3. `PATCH` 修改 `fullText` 后重新生成（若会触发重解析）

**规则：**

- 凡识别为检验/化验类（`docCategory = LAB_REPORT` 或路由 `medical_report_detection`），**至少 1 个 `table` 块**，且 `rows.length >= 3`（否则视为失败，见 P2）。
- 表头列名统一中文：`检验项目`、`结果`、`单位`、`参考区间`（缺单位/参考区间时可 2 列，但 headers 与 rows 列数一致）。
- 异常值：若结果超出参考区间，可在结果字符串保留原样（如 `6.72`），可选增加字段 `flag: "H"|"L"`（前端暂未渲染，可预留）。

### P1 — 从百度云结构化 JSON 映射

针对 `medical_report_detection` / 检验报告类 `specializedRaw`，实现类似：

```java
List<DisplayBlock> toDisplayBlocks(MedicalOcrRaw raw, String fullText) {
  // 1. 患者信息、医院名 → title + kv
  // 2. 项目列表 → table（核心）
  // 3. 页脚时间、检验者 → kv / note
}
```

**映射思路（按实际百度返回字段名调整）：**

| 百度/内部字段（示例） | 映射到 table |
|----------------------|--------------|
| `Item[]` / `items[]` / `TestItem[]` | 每个元素一行 |
| 元素.`name` / `word` / `item_name` | `rows[i][0]` 检验项目 |
| 元素.`result` / `value` | `rows[i][1]` 结果 |
| 元素.`unit` | `rows[i][2]` 单位 |
| 元素.`reference` / `range` | `rows[i][3]` 参考区间 |

若百度返回的是 **表格二维数组**（`cells[row][col]`），按表头行识别列含义后整体转为一个 `table`。

若返回 **左右两个表格区域**，生成两个 `table` 块（caption 区分左栏/右栏）。

### P2 — 失败与降级

| 情况 | 后端行为 |
|------|----------|
| 结构化 API 成功且有项目列表 | 必须输出 `table` |
| 结构化 API 失败 | `structuredError` 写明原因；可降级：从 `fullText` 用规则解析表（见下） |
| 仅有通用 OCR、无表格结构 | `structuredError` + 仅 `kv`/paragraph，**不要**伪造 table |

**fullText 降级解析（可选）：**  
在全文定位表头行（含「检验项目」且含「结果」），其后连续行按 4 列或「标签行+值行」配对填入 `rows`；双栏版式尝试按空列或 x 坐标（若 OCR 带 location）分列。

### P3 — 同步 `title`

检验表单据的 `title` 建议用可读摘要，例如：

- `全血细胞计数+CRP检验报告`（来自检验项目摘要或 `structuredFields.检验项目`）  
不要用默认「第1页/共1页」或空标题。  
前端详情页 **AppBar 显示 `title`**，与 table 无关但需一并修复。

---

## 写入接口（与现有字段关系）

以下接口的 `data` 均需带 **`displayBlocks`**（含 table）：

| 接口 | 说明 |
|------|------|
| `POST /v1/medical/smart-recognize` | 响应 `data` 内建议含 `displayBlocks`、`title` |
| `GET /v1/medical/documents/{id}` | 详情根级 `displayBlocks` |
| `PATCH /v1/medical/documents/{id}` | 若重算结构，响应/再 GET 应含新 table |

`structuredFields` 可保留扁平键值（便于搜索），但**不能替代 table**：

```json
"structuredFields": {
  "检验项目摘要": "全血细胞计数+5分类+CRP",
  "姓名": "邱羽橙"
}
```

---

## 前端渲染逻辑（供联调理解）

1. 遍历 `displayBlocks`，遇到 `type === "table"` → 渲染 **横向滚动 DataTable**（「检验结果表」区域）。  
2. 若 `displayBlocks` 中**没有任何 table**，才尝试从 `ocr.specializedRaw` 启发式抽表（成功率低）。  
3. 若仍无表，仅显示 `kv` / 折叠「OCR 原文」——**这就是当前血常规单的体验**。

因此：**后端输出 table = 立刻有表；不输出 = 前端很难救。**

---

## 验收标准（必须全部通过）

用一张**血常规 + CRP** 检验报告照片（北大人民医院样式，双栏表）走完整流程：

1. `GET /v1/medical/documents/{id}` 的 `displayBlocks` 中 **至少 1 个 `type: "table"`**。  
2. 该 table 的 `rows` 含 **白细胞计数、红细胞计数、CRP** 等至少 10 行（双栏可拆 2 个 table 合计）。  
3. 每行第 1 列为项目名、第 2 列为结果，**不是**把「检验项目」「6.72」拆成两条 `kv`。  
4. 移动端详情页出现 **「检验结果表」** 区块，可左右滑动查看列。  
5. `title` 为可读检验名称，AppBar 不显示「单据 #1」这种占位（前端已支持显示 `title`）。  
6. `structuredError` 为空；若结构化失败则非空且**无假 table**。

---

## 不要做的事

- 不要把每个检验指标拆成独立 `kv` 冒充结构化。  
- 不要把双栏表按 OCR 阅读顺序混成单列长列表而不标 column。  
- 不要只存 `specializedRaw` 而不生成 `displayBlocks.table`。  
- 不要在 `rows` 里嵌套对象（前端只要字符串二维数组）。

---

## 参考实现伪代码

```text
function buildLabReportDisplayBlocks(specializedRaw, fullText, patientMeta):
  blocks = []
  blocks.add(title(hospitalName))
  blocks.add(kv("姓名", patientMeta.name))
  ...

  items = extractTestItems(specializedRaw)  // List<{name, result, unit, range}>
  if items.isEmpty:
    items = parseTableFromFullText(fullText)
  if items.isNotEmpty:
    left, right = splitDualColumnItems(items)  // 若能检测双栏
    if right.isEmpty:
      blocks.add(table("检验结果", headers, rowsFrom(items)))
    else:
      blocks.add(table("检验结果（左栏）", headers, rowsFrom(left)))
      blocks.add(table("检验结果（右栏）", headers, rowsFrom(right)))

  blocks.add(kv("报告时间", reportTime))
  return blocks
```

---

## 交付物

1. `LabReportDisplayBlockMapper`（或等价）+ 单测 fixture（真实百度 JSON 脱敏样本）。  
2. 详情/识别响应示例 JSON（含 `table` 的 `displayBlocks`）。  
3. 更新 `docs/医疗档案与单据接口文档.md` 中 `displayBlocks` 一节，补充 `table` 类型说明。

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-05-17 | 初版：检验表 table 契约、双栏版式、百度映射与验收标准 |
