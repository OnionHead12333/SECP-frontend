import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/medical_hub_api.dart';
import '../utils/medical_fulltext_structure.dart';
import 'widgets/medical_fulltext_structure_view.dart';

/// 单据详情：原件、结构化展示与编辑。
class MedicalDocumentDetailPage extends StatefulWidget {
  const MedicalDocumentDetailPage({
    super.key,
    required this.documentId,
    this.elderProfileId,
  });

  final int documentId;
  final int? elderProfileId;

  @override
  State<MedicalDocumentDetailPage> createState() => _MedicalDocumentDetailPageState();
}

class _MedicalDocumentDetailPageState extends State<MedicalDocumentDetailPage> {
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  Map<String, dynamic>? _detail;
  Uint8List? _imageBytes;
  String? _error;

  late final TextEditingController _titleController;
  late final TextEditingController _fullTextController;
  String? _docCategory;

  static const _categoryOptions = [
    ('', '未分类'),
    ('LAB_REPORT', '检验检查'),
    ('PRESCRIPTION', '处方'),
    ('BILLING', '票据费用'),
    ('RECORD', '病历记录'),
    ('OTHER', '其他'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _fullTextController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _fullTextController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await MedicalHubApi.documentDetail(
        widget.documentId,
        elderProfileId: widget.elderProfileId,
      );
      final img = await MedicalHubApi.documentImageBytes(
        widget.documentId,
        elderProfileId: widget.elderProfileId,
      );
      if (!mounted) return;
      _applyDetail(d);
      setState(() {
        _detail = d;
        _imageBytes = img;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _applyDetail(Map<String, dynamic> d) {
    _titleController.text = d['title'] as String? ?? '';
    _fullTextController.text = d['fullText'] as String? ?? '';
    _docCategory = d['docCategory'] as String?;
  }

  Map<String, dynamic>? get _ocrMap {
    final ocr = _detail?['ocr'];
    if (ocr is Map<String, dynamic>) return ocr;
    if (ocr is Map) return Map<String, dynamic>.from(ocr);
    return null;
  }

  Map<String, dynamic>? get _specializedRaw {
    final candidates = [
      _detail?['specializedRaw'],
      _ocrMap?['specializedRaw'],
      (_detail?['variants'] is Map ? (_detail!['variants'] as Map)['specializedRaw'] : null),
    ];
    for (final raw in candidates) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Object? get _tableRows =>
      _detail?['tableRows'] ?? _ocrMap?['tableRows'];

  Map<String, dynamic>? get _extractedFields {
    final raw = _detail?['extractedFields'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Map<String, dynamic>? get _structuredFields {
    final raw = _detail?['structuredFields'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  List<MedicalDisplayBlock> get _displayBlocks =>
      MedicalDisplayBlock.listFromJson(_detail?['displayBlocks']);

  String? get _structuredRouteSource {
    final top = _detail?['structuredRouteSource'] as String?;
    if (top != null && top.isNotEmpty) return top;
    return _ocrMap?['structuredRouteSource'] as String?;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await MedicalHubApi.patchDocument(
        widget.documentId,
        elderProfileId: widget.elderProfileId,
        title: _titleController.text.trim().isEmpty ? '未命名单据' : _titleController.text.trim(),
        fullText: _fullTextController.text,
        docCategory: _docCategory != null && _docCategory!.isNotEmpty ? _docCategory : null,
      );
      if (!mounted) return;
      setState(() => _editing = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存，结构化字段已由服务端重新生成')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    if (_detail != null) _applyDetail(_detail!);
    setState(() => _editing = false);
  }

  String _routeSourceLabel(String? code) {
    return switch (code) {
      'keyword_text' => '全文关键词路由',
      'doc_classify' => '文档分类路由',
      _ => code ?? '—',
    };
  }

  String get _displayTitle {
    if (_editing) {
      final t = _titleController.text.trim();
      if (t.isNotEmpty) return t;
    }
    return resolveMedicalDocumentTitle(
      apiTitle: _detail?['title'] as String?,
      displayBlocks: _displayBlocks,
      specializedRaw: _specializedRaw,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _loading
            ? Text('单据 #${widget.documentId}')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayTitle,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '档案 #${widget.documentId}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
        actions: [
          if (!_loading && _error == null && _detail != null)
            _editing
                ? TextButton(
                    onPressed: _saving ? null : _cancelEdit,
                    child: const Text('取消'),
                  )
                : IconButton(
                    tooltip: '编辑',
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined),
                  ),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_imageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                        ),
                      const SizedBox(height: 16),
                      if (_editing) ..._editSection() else ..._readSection(),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _readSection() {
    final fullText = _detail?['fullText'] as String? ?? '';
    final routed = _detail?['routedSpecializedApi'] ?? _ocrMap?['routedSpecializedApi'];

    final folderName = _detail?['folderName'] as String?;
    return [
      if (folderName != null && folderName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 18, color: Color(0xFF0369A1)),
              const SizedBox(width: 6),
              Text('所在文件夹：$folderName', style: const TextStyle(color: Color(0xFF0369A1))),
            ],
          ),
        ),
      Text('类别：${_detail?['docCategory'] ?? '—'}'),
      Text('结构化路由：${routed ?? '—'}'),
      Text('路由依据：${_routeSourceLabel(_structuredRouteSource)}'),
      const SizedBox(height: 16),
      MedicalFullTextStructureView(
        fullText: fullText,
        displayBlocks: _displayBlocks,
        structuredFields: _structuredFields,
        specializedRaw: _specializedRaw,
        tableRowsRaw: _tableRows,
        extractedFields: _extractedFields,
        structuredError: structuredErrorFromDetail(_detail),
        showExtractedWhenStructured: _displayBlocks.isEmpty && _structuredFields == null,
      ),
    ];
  }

  List<Widget> _editSection() {
    return [
      TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: '标题',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _docCategory ?? '',
        decoration: const InputDecoration(
          labelText: '单据类别',
          border: OutlineInputBorder(),
        ),
        items: _categoryOptions
            .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
            .toList(),
        onChanged: (v) => setState(() => _docCategory = v),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _fullTextController,
        decoration: const InputDecoration(
          labelText: '识别全文（OCR 原文）',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
          hintText: '可修正 OCR 误识别内容',
        ),
        maxLines: null,
        minLines: 12,
        keyboardType: TextInputType.multiline,
      ),
      const SizedBox(height: 8),
      const Text(
        '保存后服务端将自动重新生成 displayBlocks、structuredFields 与 extractedFields，无需在前端手动解析。',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
      ),
    ];
  }
}
