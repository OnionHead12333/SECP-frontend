import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/medical_ocr_api.dart';

/// 老人端 / 子女端共用：拍照或相册上传医疗单据，展示 OCR 全文。
class MedicalDocumentOcrPage extends StatefulWidget {
  const MedicalDocumentOcrPage({super.key});

  @override
  State<MedicalDocumentOcrPage> createState() => _MedicalDocumentOcrPageState();
}

class _MedicalDocumentOcrPageState extends State<MedicalDocumentOcrPage> {
  final ImagePicker _picker = ImagePicker();

  File? _previewFile;
  MedicalOcrResult? _result;
  bool _busy = false;

  Future<void> _pickAndRecognize(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 2200,
      imageQuality: 88,
    );
    if (xfile == null || !mounted) return;
    final file = File(xfile.path);
    setState(() {
      _previewFile = file;
      _result = null;
      _busy = true;
    });
    try {
      final r = await MedicalOcrApi.recognizeMedicalDocument(file);
      if (!mounted) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('拍照识别单据'),
        backgroundColor: const Color(0xFFF7F8FC),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text(
            '拍摄或选择处方、检查申请单、复诊单等清晰照片。下方「自动分类」来自云端模型，误拍笔记、课本等可能被标成医疗类；请以识别全文为准，诊断与治疗请以医生说明为准。',
            style: TextStyle(color: Color(0xFF475569), height: 1.55),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _pickAndRecognize(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickAndRecognize(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('相册'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(
              child: Text('正在识别与分类…', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
          if (_previewFile != null && !_busy) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.file(_previewFile!, fit: BoxFit.cover),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _classSummaryBanner(),
            ..._structuredBannerTrailing(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '识别文字',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _result!.fullText.isEmpty ? '（未识别到文字，请换更清晰的照片重试）' : _result!.fullText,
                    style: const TextStyle(fontSize: 15, height: 1.55, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
            if (_result!.classifyRaw != null && _result!.classifyRaw!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  '分类原始响应（调试用）',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(_result!.classifyRaw!),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_result!.raw != null && _result!.raw!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  '原始响应（调试用）',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(_result!.raw!),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 自动分类后的结构化路由说明（无分类结果时不占位）。
  List<Widget> _structuredBannerTrailing() {
    final r = _result!;
    final id = r.routedSpecializedApi;
    final hasClass = r.documentClasses != null && r.documentClasses!.isNotEmpty;
    final warn = r.classificationWarning;

    final sections = <Widget>[];

    if (warn != null && warn.isNotEmpty && hasClass) {
      sections.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  warn,
                  style: const TextStyle(color: Color(0xFF9A3412), height: 1.45, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
      sections.add(const SizedBox(height: 12));
    }

    if (id != null && id.isNotEmpty) {
      sections.add(_structuredRoutedCard(id));
    } else if (hasClass && (warn == null || warn.isEmpty)) {
      sections.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Text(
            '已有单据分类，但未命中内置的结构化接口映射，已仅使用通用高精度文字识别。',
            style: TextStyle(color: Color(0xFF475569), height: 1.45, fontSize: 14),
          ),
        ),
      );
    }

    if (sections.isEmpty) return [];
    return [const SizedBox(height: 12), ...sections, const SizedBox(height: 12)];
  }

  Widget _structuredRoutedCard(String id) {
    final label = MedicalOcrResult.labelForSpecializedApi(id);
    final raw = _result!.specializedRaw;
    final routeHint = MedicalOcrResult.labelForRouteSource(_result!.structuredRouteSource);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '结构化识别（已自动选接口）',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF14532D)),
          ),
          if (routeHint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              routeHint,
              style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), height: 1.4),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
          ),
          Text(
            '接口标识：$id',
            style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
          ),
          if (raw == null || raw.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '未拿到结构化 JSON（可能未开通该医疗票据接口、欠费或单据版式不匹配）。下方「识别文字」仍为通用 OCR 结果。',
              style: TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.45),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              title: const Text(
                '查看结构化 JSON',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF14532D)),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(raw),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.35,
                      color: Color(0xFF14532D),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 百度云 doc_classify 摘要；无结果时提示可能未开通能力。
  Widget _classSummaryBanner() {
    final r = _result!;
    final list = r.documentClasses;
    if (list == null || list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.category_outlined, color: Color(0xFFC2410C)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '暂无自动分类结果。请在百度云控制台开通「文件检测分类」并确保账户可用；不影响下方文字识别。',
                style: TextStyle(color: Color(0xFF9A3412), height: 1.45, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    final primary = r.primaryClass!;
    final pct = primary.probability != null ? '${(primary.probability! * 100).toStringAsFixed(1)}%' : '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '自动分类',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            primary.type,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          Text(
            '置信度约 $pct',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '说明：此项来自百度云「版面/文档形态」检测。化验单、费用清单等常为表格排版，因此显示「表格」并不代表系统未识别到检验内容。',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ),
          if (list.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '本图检测到 ${list.length} 类文档主体，以上为置信度最高的一类。',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
          if (r.structuredRouteSource == 'keyword_text' &&
              r.routedSpecializedApi != null &&
              r.routedSpecializedApi!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.text_snippet_outlined, size: 20, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已根据「识别文字」中的单据用语，选用「${MedicalOcrResult.labelForSpecializedApi(r.routedSpecializedApi!)}」结构化接口，可与上方版面分类不一致。',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF), height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
