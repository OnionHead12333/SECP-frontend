import 'dart:convert';

/// 检验结果等表格（表头 + 行）。
final class MedicalResultTable {
  const MedicalResultTable({
    required this.headers,
    required this.rows,
    this.caption,
  });

  final String? caption;
  final List<String> headers;
  final List<List<String>> rows;
}

/// 后端下发的展示块（与 docs/医疗单据结构化-后端优化Prompt.md 对齐）。
final class MedicalDisplayBlock {
  const MedicalDisplayBlock({
    required this.type,
    this.text,
    this.label,
    this.value,
    this.tableHeaders,
    this.tableRows,
    this.tableCaption,
  });

  final String type;
  final String? text;
  final String? label;
  final String? value;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;
  final String? tableCaption;

  static List<MedicalDisplayBlock> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    final out = <MedicalDisplayBlock>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final type = m['type'] as String? ?? '';
      if (type.isEmpty) continue;
      out.add(MedicalDisplayBlock(
        type: type,
        text: m['text'] as String?,
        label: m['label'] as String?,
        value: m['value'] as String?,
        tableHeaders: _stringList(m['headers']),
        tableRows: _rowsList(m['rows']),
        tableCaption: m['caption'] as String? ?? m['title'] as String?,
      ));
    }
    return out;
  }

  MedicalResultTable? get asTable {
    if (type != 'table') return null;
    final h = tableHeaders;
    final r = tableRows;
    if (h == null || h.isEmpty || r == null || r.isEmpty) return null;
    return MedicalResultTable(caption: tableCaption, headers: h, rows: r);
  }
}

List<String>? _stringList(Object? raw) {
  if (raw is! List) return null;
  return raw.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
}

List<List<String>>? _rowsList(Object? raw) {
  if (raw is! List) return null;
  final rows = <List<String>>[];
  for (final row in raw) {
    if (row is! List) continue;
    final cells = row.map((e) => e?.toString().trim() ?? '').toList();
    if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
  }
  return rows.isEmpty ? null : rows;
}

const _labTableHeaders = ['检验项目', '结果', '单位', '参考区间'];

/// 汇总检验结果表：table 块 → 百度 Item → tableRows → 通用 JSON。
List<MedicalResultTable> collectMedicalResultTables({
  List<MedicalDisplayBlock>? displayBlocks,
  Map<String, dynamic>? specializedRaw,
  Object? tableRowsRaw,
}) {
  final blocks = displayBlocks ?? const <MedicalDisplayBlock>[];
  for (final b in blocks) {
    final t = b.asTable;
    if (t != null) return [t];
  }

  final fromBaidu = extractTablesFromBaiduMedicalReport(specializedRaw);
  if (fromBaidu.isNotEmpty) return fromBaidu;

  final fromRows = parseTableRowsField(tableRowsRaw);
  if (fromRows.isNotEmpty) return fromRows;

  if (specializedRaw != null) {
    return extractTablesFromSpecializedRaw(specializedRaw);
  }
  return const [];
}

/// @deprecated 使用 [collectMedicalResultTables]
List<MedicalResultTable> collectResultTablesFromRaw(Map<String, dynamic>? specializedRaw) {
  return collectMedicalResultTables(specializedRaw: specializedRaw);
}

bool displayBlocksContainTable(List<MedicalDisplayBlock> blocks) =>
    blocks.any((b) => b.type == 'table' && b.asTable != null);

/// 解析后端根级 `tableRows`（需为「行→列」矩阵；列名勿混入数据行）。
List<MedicalResultTable> parseTableRowsField(Object? raw) {
  if (raw is! List || raw.isEmpty) return const [];
  final rows = <List<String>>[];
  for (final row in raw) {
    if (row is! List) continue;
    final cells = row.map((e) => e?.toString().trim() ?? '').toList();
    if (cells.length < 2) continue;
    if (_looksLikeHeaderRowMisplaced(cells)) continue;
    rows.add(cells);
  }
  if (rows.isEmpty) return const [];
  final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  final headers = colCount >= 4
      ? _labTableHeaders
      : ['列1', '列2', if (colCount > 2) '列3', if (colCount > 3) '列4'];
  return [MedicalResultTable(caption: '检验结果', headers: headers, rows: rows)];
}

bool _looksLikeHeaderRowMisplaced(List<String> cells) {
  const meta = {'仪器类型', '测试方法', '结果提示', '单位', '参考区间', '检验项目', '结果'};
  return cells.any((c) => meta.contains(c));
}

/// 百度 medical_report_detection：`words_result.Item` 为行数组，每行含 word_name/word/location。
List<MedicalResultTable> extractTablesFromBaiduMedicalReport(Map<String, dynamic>? specializedRaw) {
  if (specializedRaw == null) return const [];

  Object? itemRaw = specializedRaw['Item'];
  Map<String, dynamic>? wordsResult;
  if (specializedRaw['words_result'] is Map) {
    wordsResult = Map<String, dynamic>.from(specializedRaw['words_result'] as Map);
    itemRaw ??= wordsResult['Item'];
  }

  if (itemRaw is! List) return const [];

  final leftRows = <List<String>>[];
  final rightRows = <List<String>>[];
  const splitLeft = 1200;

  for (final rowAny in itemRaw) {
    if (rowAny is! List) continue;
    final fields = <String, String>{};
    var leftPx = 0;
    for (final cell in rowAny) {
      if (cell is! Map) continue;
      final m = Map<String, dynamic>.from(cell);
      final wn = m['word_name']?.toString() ?? '';
      final word = m['word']?.toString().trim() ?? '';
      if (wn.isNotEmpty && word.isNotEmpty) fields[wn] = word;
      final loc = m['location'];
      if (loc is Map) {
        leftPx = (loc['left'] as num?)?.toInt() ?? leftPx;
      }
    }
    final row = _rowFromBaiduItemFields(fields);
    if (row == null) continue;
    if (leftPx >= splitLeft) {
      rightRows.add(row);
    } else {
      leftRows.add(row);
    }
  }

  final out = <MedicalResultTable>[];
  if (leftRows.isNotEmpty) {
    out.add(MedicalResultTable(
      caption: rightRows.isNotEmpty ? '检验结果（左栏）' : '检验结果',
      headers: _labTableHeaders,
      rows: leftRows,
    ));
  }
  if (rightRows.isNotEmpty) {
    out.add(MedicalResultTable(
      caption: '检验结果（右栏）',
      headers: _labTableHeaders,
      rows: rightRows,
    ));
  }
  return out;
}

List<String>? _rowFromBaiduItemFields(Map<String, String> fields) {
  final name = (fields['项目名称'] ?? fields['项目代号'] ?? '').trim();
  final result = (fields['结果'] ?? '').trim();
  if (name.isEmpty && result.isEmpty) return null;
  return [
    name.isEmpty ? '—' : name,
    result.isEmpty ? '—' : result,
    (fields['单位'] ?? '').trim().isEmpty ? '—' : fields['单位']!.trim(),
    (fields['参考区间'] ?? '').trim().isEmpty ? '—' : fields['参考区间']!.trim(),
  ];
}

/// 解析单据展示用标题（避免「第1页/共1页」占位）。
String resolveMedicalDocumentTitle({
  String? apiTitle,
  List<MedicalDisplayBlock>? displayBlocks,
  Map<String, dynamic>? specializedRaw,
}) {
  if (apiTitle != null && apiTitle.trim().isNotEmpty && !_isPageNumberTitle(apiTitle)) {
    return apiTitle.trim();
  }

  final checkItem = _baiduCommonDataWord(specializedRaw, '检查项目');
  if (checkItem != null && checkItem.isNotEmpty) {
    return checkItem.length > 40 ? '${checkItem.substring(0, 40)}…' : checkItem;
  }

  final reportName = _baiduCommonDataWord(specializedRaw, '报告单名称');
  if (reportName != null && reportName.contains('检验')) {
    return reportName;
  }

  for (final b in displayBlocks ?? const <MedicalDisplayBlock>[]) {
    if (b.type == 'title' && b.text != null) {
      final t = b.text!.trim();
      if (t.contains('检验项目')) {
        final idx = t.indexOf(':');
        final idxCn = t.indexOf('：');
        final i = idxCn >= 0 ? idxCn : idx;
        if (i > 0 && i < t.length - 1) return t.substring(i + 1).trim();
      }
      if (!_isPageNumberTitle(t) && t.length > 6) return t;
    }
  }

  if (apiTitle != null && apiTitle.trim().isNotEmpty) return apiTitle.trim();
  return '医疗单据';
}

String? _baiduCommonDataWord(Map<String, dynamic>? specializedRaw, String wordName) {
  if (specializedRaw == null) return null;
  Object? common = specializedRaw['CommonData'];
  if (common is! List && specializedRaw['words_result'] is Map) {
    common = (specializedRaw['words_result'] as Map)['CommonData'];
  }
  if (common is! List) return null;
  for (final e in common) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    if (m['word_name'] == wordName) return m['word']?.toString();
  }
  return null;
}

bool _isPageNumberTitle(String s) {
  final t = s.trim();
  return RegExp(r'^第\s*\d+\s*页').hasMatch(t) || t.length <= 12 && t.contains('页');
}

/// displayBlocks 是否几乎全是项目代号级 kv（应用百度 Item 表替代展示）。
bool displayBlocksAreCodeOnlyKv(List<MedicalDisplayBlock> blocks) {
  if (blocks.isEmpty) return false;
  final kvs = blocks.where((b) => b.type == 'kv').toList();
  if (kvs.length < 5) return false;
  final codeLike = kvs.where((b) => _looksLikeProjectCode(b.label ?? '')).length;
  return codeLike >= kvs.length * 0.7;
}

bool _looksLikeProjectCode(String label) {
  final s = label.trim();
  if (s.isEmpty || s.length > 10) return false;
  return RegExp(r'^[A-Za-z0-9#%°*-]+$').hasMatch(s);
}

List<MedicalResultTable> extractTablesFromSpecializedRaw(Map<String, dynamic> raw) {
  final out = <MedicalResultTable>[];

  void addFromRowMaps(List<Map<String, dynamic>> maps, {String? caption}) {
    if (maps.isEmpty) return;
    const headerCandidates = <String, List<String>>{
      'item': ['检验项目', '项目', '名称', 'item', 'name', 'word', '项目名称'],
      'result': ['结果', 'result', 'value', '检验结果'],
      'unit': ['单位', 'unit'],
      'range': ['参考区间', '参考范围', 'reference', 'range', 'ref'],
    };
    final keys = <String, String>{};
    for (final entry in headerCandidates.entries) {
      for (final m in maps) {
        for (final k in m.keys) {
          final lk = k.toString().toLowerCase();
          if (entry.value.any((a) => lk == a.toLowerCase() || lk.contains(a.toLowerCase()))) {
            keys[entry.key] = k.toString();
            break;
          }
        }
      }
    }
    if (!keys.containsKey('item') || !keys.containsKey('result')) return;

    final headers = ['检验项目', '结果', if (keys.containsKey('unit')) '单位', if (keys.containsKey('range')) '参考区间'];
    final rows = <List<String>>[];
    for (final m in maps) {
      final row = <String>[
        _cell(m[keys['item']]),
        _cell(m[keys['result']]),
        if (keys.containsKey('unit')) _cell(m[keys['unit']]),
        if (keys.containsKey('range')) _cell(m[keys['range']]),
      ];
      if (row[0].isNotEmpty || row[1].isNotEmpty) rows.add(row);
    }
    if (rows.isNotEmpty) out.add(MedicalResultTable(caption: caption, headers: headers, rows: rows));
  }

  void walk(Object? node, {String? caption}) {
    if (node is List) {
      final maps = <Map<String, dynamic>>[];
      for (final e in node) {
        if (e is Map) maps.add(Map<String, dynamic>.from(e));
      }
      if (maps.isNotEmpty) {
        addFromRowMaps(maps, caption: caption);
        return;
      }
    }
    if (node is Map) {
      final m = Map<String, dynamic>.from(node);
      if (m['headers'] is List && m['rows'] is List) {
        final h = _stringList(m['headers']);
        final r = _rowsList(m['rows']);
        if (h != null && r != null && h.isNotEmpty && r.isNotEmpty) {
          out.add(MedicalResultTable(
            caption: m['caption'] as String? ?? caption,
            headers: h,
            rows: r,
          ));
        }
      }
      for (final entry in m.entries) {
        final k = entry.key.toString().toLowerCase();
        if (entry.value is List &&
            (k.contains('item') || k.contains('row') || k.contains('result') || k == 'data' || k == 'list')) {
          walk(entry.value, caption: entry.key.toString());
        }
      }
    }
  }

  walk(raw);
  return out;
}

String _cell(Object? v) {
  if (v == null) return '';
  if (v is Map) {
    return v['word']?.toString() ?? v['value']?.toString() ?? v.toString();
  }
  return v.toString().trim();
}

/// 将 OCR 纯文本拆成可读的「标题 / 键值对 / 段落」块，用于结构化展示。
final class FullTextBlock {
  const FullTextBlock({
    required this.kind,
    required this.lines,
    this.label,
    this.value,
  });

  final FullTextBlockKind kind;
  final List<String> lines;
  final String? label;
  final String? value;
}

enum FullTextBlockKind { header, keyValue, paragraph }

final _fieldLabelSuffix = RegExp(r'(项目|类型|科室|数量|要求|说明|描述|标本|号|时间|日期)$');
final _documentTitlePattern = RegExp(
  r'(医院|大学|HOSPITAL|申请单|处方|门诊|人民|卫生院|中心)',
  caseSensitive: false,
);

/// 从全文生成展示块（启发式；优先使用后端 [MedicalDisplayBlock]）。
List<FullTextBlock> structureMedicalFullText(String fullText) {
  if (fullText.trim().isEmpty) return const [];

  final rawLines = fullText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final blocks = <FullTextBlock>[];
  var headerCount = 0;
  var i = 0;

  while (i < rawLines.length) {
    final line = rawLines[i];

    final inlineKv = _tryParseKeyValue(line);
    if (inlineKv != null) {
      blocks.add(FullTextBlock(
        kind: FullTextBlockKind.keyValue,
        lines: [line],
        label: inlineKv.$1,
        value: inlineKv.$2,
      ));
      i++;
      continue;
    }

    if (_looksLikeDocumentTitle(line) && headerCount < 3) {
      blocks.add(FullTextBlock(kind: FullTextBlockKind.header, lines: [line]));
      headerCount++;
      i++;
      continue;
    }

    if (i + 1 < rawLines.length &&
        _looksLikeFieldLabel(line) &&
        _looksLikeFieldValue(rawLines[i + 1], line)) {
      blocks.add(FullTextBlock(
        kind: FullTextBlockKind.keyValue,
        lines: [line, rawLines[i + 1]],
        label: line,
        value: rawLines[i + 1],
      ));
      i += 2;
      continue;
    }

    // 孤立短标签行：仍作键值对展示，值留空便于用户编辑
    if (_looksLikeFieldLabel(line) && line.length <= 20) {
      blocks.add(FullTextBlock(
        kind: FullTextBlockKind.keyValue,
        lines: [line],
        label: line,
        value: '—',
      ));
      i++;
      continue;
    }

    final para = <String>[line];
    i++;
    while (i < rawLines.length) {
      final next = rawLines[i];
      if (_tryParseKeyValue(next) != null) break;
      if (_looksLikeDocumentTitle(next) && headerCount < 3) break;
      if (i + 1 < rawLines.length &&
          _looksLikeFieldLabel(next) &&
          _looksLikeFieldValue(rawLines[i + 1], next)) {
        break;
      }
      if (_looksLikeFieldLabel(next) && next.length <= 20) break;
      para.add(next);
      i++;
    }
    blocks.add(FullTextBlock(kind: FullTextBlockKind.paragraph, lines: List.unmodifiable(para)));
  }

  return blocks;
}

(String, String)? _tryParseKeyValue(String line) {
  final idxCn = line.indexOf('：');
  final idxEn = line.indexOf(':');
  int idx;
  if (idxCn >= 0 && (idxEn < 0 || idxCn < idxEn)) {
    idx = idxCn;
  } else if (idxEn >= 0) {
    idx = idxEn;
  } else {
    return null;
  }
  if (idx <= 0 || idx >= line.length - 1) return null;
  final label = line.substring(0, idx).trim();
  final value = line.substring(idx + 1).trim();
  if (label.isEmpty) return null;
  return (label, value);
}

bool _looksLikeDocumentTitle(String line) {
  if (line.length > 56) return false;
  if (_fieldLabelSuffix.hasMatch(line) && line.length <= 16) return false;
  if (_documentTitlePattern.hasMatch(line)) return true;
  if (RegExp(r"^[A-Za-z0-9\s.\-']+$").hasMatch(line) && line.length >= 8) return true;
  return false;
}

bool _looksLikeFieldLabel(String line) {
  if (line.isEmpty || line.length > 24) return false;
  if (RegExp(r'^\d+([./\-]\d+)*$').hasMatch(line)) return false;
  if (_looksLikeDocumentTitle(line)) return false;
  if (_fieldLabelSuffix.hasMatch(line)) return true;
  if (line.length <= 8 && RegExp(r'[\u4e00-\u9fff]').hasMatch(line)) return true;
  return false;
}

bool _looksLikeFieldValue(String line, String label) {
  if (line.isEmpty || line == label) return false;
  if (_tryParseKeyValue(line) != null) return false;
  if (_looksLikeFieldLabel(line) && line.length <= 16 && !_fieldLabelSuffix.hasMatch(label)) {
    return false;
  }
  return true;
}

/// 将 [specializedRaw] 展平为键值行；键名映射为中文展示名。
List<MapEntry<String, String>> flattenSpecializedJson(Object? raw, {String prefix = ''}) {
  if (raw == null) return const [];
  if (raw is! Map) return const [];

  final out = <MapEntry<String, String>>[];
  raw.forEach((key, value) {
    final rawKey = key.toString();
    final k = prefix.isEmpty ? rawKey : '$prefix.$rawKey';
    if (value == null) return;
    if (value is Map) {
      out.addAll(flattenSpecializedJson(value, prefix: k));
    } else if (value is List) {
      if (value.isEmpty) return;
      out.add(MapEntry(labelForStructuredKey(k), value.map((e) => e?.toString() ?? '').join('、')));
    } else {
      final s = value.toString().trim();
      if (s.isEmpty) return;
      out.add(MapEntry(labelForStructuredKey(k), s));
    }
  });
  return out;
}

/// 常见百度结构化字段 → 中文标签。
String labelForStructuredKey(String key) {
  final lower = key.toLowerCase();
  const exact = <String, String>{
    'test_item': '检验项目',
    'itemname': '检验项目',
    'sample_type': '样本类型',
    'sampletype': '样本类型',
    'count': '数量',
    'num': '数量',
    'department': '执行科室',
    'exec_dept': '执行科室',
    'sample_requirement': '标本要求',
    'prescription_id': '处方号',
    'recipenum': '处方号',
    'name': '姓名',
    'patient_name': '姓名',
    'sex': '性别',
    'age': '年龄',
    'hospital': '医院',
    'words': '内容',
  };
  for (final e in exact.entries) {
    if (lower == e.key || lower.endsWith('.${e.key}')) return e.value;
  }
  if (lower.contains('test') && lower.contains('item')) return '检验项目';
  if (lower.contains('sample')) return '样本类型';
  if (lower.contains('dept') || lower.contains('department')) return '科室';
  return key.split('.').last;
}

String prettyJson(Object? raw) {
  if (raw == null) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(raw);
  } catch (_) {
    return raw.toString();
  }
}

/// 解析后端 `structuredFields`（中文键 → 字符串值）。
List<MapEntry<String, String>> structuredFieldsFromJson(Object? raw) {
  if (raw is! Map) return const [];
  final out = <MapEntry<String, String>>[];
  raw.forEach((key, value) {
    if (value == null) return;
    final label = key.toString().trim();
    if (label.isEmpty) return;
    final text = value is List
        ? value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join('、')
        : value.toString().trim();
    if (text.isEmpty) return;
    out.add(MapEntry(label, text));
  });
  return out;
}

String? structuredErrorFromDetail(Map<String, dynamic>? detail) {
  if (detail == null) return null;
  final top = detail['structuredError'] as String?;
  if (top != null && top.trim().isNotEmpty) return top.trim();
  final ocr = detail['ocr'];
  if (ocr is Map) {
    final nested = ocr['structuredError'] as String?;
    if (nested != null && nested.trim().isNotEmpty) return nested.trim();
  }
  return null;
}

/// 从 displayBlocks 提取可表格展示的 kv 行。
List<MapEntry<String, String>> kvEntriesFromDisplayBlocks(List<MedicalDisplayBlock> blocks) {
  final out = <MapEntry<String, String>>[];
  for (final b in blocks) {
    if (b.type != 'kv') continue;
    final label = b.label?.trim() ?? '';
    final value = b.value?.trim() ?? '';
    if (label.isEmpty) continue;
    out.add(MapEntry(label, value.isEmpty ? '—' : value));
  }
  return out;
}
