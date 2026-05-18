import 'package:flutter/material.dart';

import '../../utils/medical_fulltext_structure.dart';
import 'medical_lab_result_table.dart';

/// 医疗单据识别结果展示（与后端 displayBlocks / structuredFields 对齐）。
class MedicalFullTextStructureView extends StatelessWidget {
  const MedicalFullTextStructureView({
    super.key,
    required this.fullText,
    this.displayBlocks,
    this.structuredFields,
    this.specializedRaw,
    this.tableRowsRaw,
    this.extractedFields,
    this.structuredError,
    this.showExtractedWhenStructured = true,
  });

  final String fullText;
  final List<MedicalDisplayBlock>? displayBlocks;
  final Map<String, dynamic>? structuredFields;
  final Map<String, dynamic>? specializedRaw;
  /// 后端根级 `tableRows`（格式正确时作为检验表数据源）。
  final Object? tableRowsRaw;
  final Map<String, dynamic>? extractedFields;
  final String? structuredError;
  /// 已有 displayBlocks / structuredFields 时是否仍展示 extractedFields 摘要。
  final bool showExtractedWhenStructured;

  @override
  Widget build(BuildContext context) {
    final blocks = displayBlocks ?? const <MedicalDisplayBlock>[];
    final fieldRows = structuredFieldsFromJson(structuredFields);
    final resultTables = collectMedicalResultTables(
      displayBlocks: blocks,
      specializedRaw: specializedRaw,
      tableRowsRaw: tableRowsRaw,
    );
    final hideCodeKv =
        resultTables.isNotEmpty && displayBlocksAreCodeOnlyKv(blocks);
    final contentBlocks = hideCodeKv
        ? blocks.where((b) => b.type != 'kv').toList()
        : blocks;
    final hasDisplayBlocks = contentBlocks.isNotEmpty;
    final hasStructuredFields =
        fieldRows.isNotEmpty && !(hideCodeKv && hasDisplayBlocks);

    if (!hasDisplayBlocks &&
        !hasStructuredFields &&
        !_hasExtracted(extractedFields) &&
        fullText.trim().isEmpty &&
        (structuredError == null || structuredError!.isEmpty)) {
      return const Text('（无识别文字）', style: TextStyle(color: Color(0xFF64748B)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (structuredError != null && structuredError!.isNotEmpty) ...[
          _structuredErrorBanner(structuredError!),
          const SizedBox(height: 12),
        ],
        if (showExtractedWhenStructured || (!hasDisplayBlocks && !hasStructuredFields))
          if (_hasExtracted(extractedFields)) ...[
            _sectionTitle('抽取字段'),
            _kvTableCard(_extractedRows(extractedFields!)),
            const SizedBox(height: 16),
          ],
        if (resultTables.isNotEmpty) ...[
          _sectionTitle('检验结果表'),
          ...resultTables.map((t) => MedicalLabResultTableView(table: t)),
          const SizedBox(height: 8),
        ],
        if (hasDisplayBlocks) ...[
          _sectionTitle('单据内容'),
          ..._widgetsFromDisplayBlocks(contentBlocks),
          const SizedBox(height: 12),
        ] else if (hasStructuredFields) ...[
          _sectionTitle('单据字段'),
          _kvTableCard(fieldRows),
          const SizedBox(height: 12),
        ] else if (fullText.trim().isNotEmpty) ...[
          _sectionTitle('识别全文'),
          SelectableText(
            fullText,
            style: const TextStyle(fontSize: 15, height: 1.55, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 12),
        ],
        if (fullText.trim().isNotEmpty && (hasDisplayBlocks || hasStructuredFields))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              '查看 OCR 原始全文',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF64748B)),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  fullText,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<Widget> _widgetsFromDisplayBlocks(List<MedicalDisplayBlock> blocks) {
    final widgets = <Widget>[];
    var kvBuffer = <MapEntry<String, String>>[];

    void flushKv() {
      if (kvBuffer.isEmpty) return;
      widgets.add(_kvTableCard(List.unmodifiable(kvBuffer)));
      widgets.add(const SizedBox(height: 8));
      kvBuffer = [];
    }

    for (final b in blocks) {
      switch (b.type) {
        case 'title':
          flushKv();
          final t = b.text?.trim() ?? '';
          if (t.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.35),
                ),
              ),
            );
          }
        case 'kv':
          final label = b.label?.trim() ?? '';
          if (label.isEmpty) continue;
          final value = b.value?.trim() ?? '';
          kvBuffer.add(MapEntry(label, value.isEmpty ? '—' : value));
        case 'note':
          flushKv();
          final t = b.text?.trim() ?? '';
          if (t.isNotEmpty) widgets.add(_noteCard(t));
        case 'paragraph':
          flushKv();
          final t = b.text?.trim() ?? '';
          if (t.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  t,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF334155)),
                ),
              ),
            );
          }
        case 'table':
          flushKv();
          final table = b.asTable;
          if (table != null) {
            widgets.add(MedicalLabResultTableView(table: table));
          }
        default:
          flushKv();
          final t = b.text?.trim() ?? b.value?.trim() ?? '';
          if (t.isNotEmpty) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(t, style: const TextStyle(fontSize: 15, height: 1.45)),
              ),
            );
          }
      }
    }
    flushKv();
    return widgets;
  }

  Widget _structuredErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFC2410C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '结构化识别未完全成功：$message。下方仍为 OCR 原文或已解析字段，请以原件为准。',
              style: const TextStyle(fontSize: 13, color: Color(0xFF9A3412), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(String text) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
        ),
      ),
    );
  }

  bool _hasExtracted(Map<String, dynamic>? f) {
    if (f == null || f.isEmpty) return false;
    return true;
  }

  List<MapEntry<String, String>> _extractedRows(Map<String, dynamic> f) {
    final rows = <MapEntry<String, String>>[];
    void add(String label, Object? v) {
      if (v == null) return;
      if (v is List && v.isEmpty) return;
      final text = v is List ? v.map((e) => e?.toString() ?? '').join('、') : v.toString();
      if (text.isEmpty) return;
      rows.add(MapEntry(label, text));
    }

    add('单据类别', f['docCategory']);
    add('识别日期', f['normalizedDates']);
    add('日期原文', f['detectedDateTexts']);
    add('关键词', f['matchedKeywords']);
    return rows;
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }

  Widget _kvTableCard(List<MapEntry<String, String>> rows) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _kvRow(rows[i].key, rows[i].value),
          ],
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
