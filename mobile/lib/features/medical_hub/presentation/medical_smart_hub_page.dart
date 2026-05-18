import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../../child/models/child_local_models.dart';
import '../data/medical_hub_api.dart';
import 'medical_document_detail_page.dart';
import 'medical_image_preview_page.dart';
import 'widgets/medical_folder_picker_field.dart';

/// 医疗单据智能识别：OCR + 归档 + 建议日历事件。
class MedicalSmartHubPage extends StatefulWidget {
  const MedicalSmartHubPage({super.key, this.elders});

  /// 子女端传入绑定老人列表；老人端不传。
  final List<BoundElder>? elders;

  @override
  State<MedicalSmartHubPage> createState() => _MedicalSmartHubPageState();
}

class _MedicalSmartHubPageState extends State<MedicalSmartHubPage> {
  final ImagePicker _picker = ImagePicker();
  File? _previewFile;
  bool _busy = false;
  MedicalSmartRecognitionResult? _result;
  String? _selectedElderKey;
  List<MedicalArchiveFolder> _folders = [];
  int? _targetFolderId;

  int? get _childElderProfileId {
    if (AuthSession.role != AppRole.child) return null;
    if (widget.elders == null || widget.elders!.isEmpty) return null;
    final key = _selectedElderKey ?? widget.elders!.first.id;
    return int.tryParse(key);
  }

  @override
  void initState() {
    super.initState();
    if (widget.elders != null && widget.elders!.isNotEmpty) {
      _selectedElderKey = widget.elders!.first.id;
    }
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    if (AuthSession.role == AppRole.child && _childElderProfileId == null) return;
    try {
      final list = await MedicalHubApi.listFolders(elderProfileId: _childElderProfileId);
      if (!mounted) return;
      setState(() => _folders = list);
    } catch (_) {
      // 文件夹列表失败不阻断识别
    }
  }

  Future<void> _createFolderFromPicker() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('新建病情文件夹'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: '文件夹名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('创建')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || _childElderProfileId == null) return;
    try {
      final folder = await MedicalHubApi.createFolder(elderProfileId: _childElderProfileId!, name: name);
      if (!mounted) return;
      setState(() {
        _folders = [..._folders, folder];
        _targetFolderId = folder.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已创建「${folder.name}」并选中')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _run(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 2200, imageQuality: 88);
    if (xfile == null || !mounted) return;

    final picked = File(xfile.path);
    final toUpload = await Navigator.of(context).push<File>(
      MaterialPageRoute<File>(
        builder: (_) => MedicalImagePreviewPage(sourceFile: picked),
      ),
    );
    if (toUpload == null || !mounted) return;
    await _recognize(toUpload);
  }

  Future<void> _recognize(File file) async {
    setState(() {
      _previewFile = file;
      _busy = true;
      _result = null;
    });
    try {
      if (AuthSession.role == AppRole.child && _childElderProfileId == null) {
        throw Exception('请选择要归档的老人');
      }
      var r = await MedicalHubApi.smartRecognize(
        file,
        elderProfileId: _childElderProfileId,
        folderId: _targetFolderId,
      );
      if (_targetFolderId != null && r.folderId != _targetFolderId) {
        await MedicalHubApi.moveDocumentToFolder(
          r.documentId,
          elderProfileId: _childElderProfileId,
          folderId: _targetFolderId,
        );
        r = MedicalSmartRecognitionResult(
          documentId: r.documentId,
          title: r.title,
          ocr: r.ocr,
          extractedFields: r.extractedFields,
          suggestedCalendarEvents: r.suggestedCalendarEvents,
          folderId: _targetFolderId,
          folderName: _folders.where((f) => f.id == _targetFolderId).map((f) => f.name).firstOrNull,
        );
      }
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

  Future<void> _addSuggested(SuggestedCalendarEvent s, int docId) async {
    try {
      if (AuthSession.role == AppRole.child && _childElderProfileId == null) {
        throw Exception('请选择老人');
      }
      await MedicalHubApi.createCalendarEvent(
        elderProfileId: _childElderProfileId,
        eventType: s.eventType,
        title: s.title,
        startAt: s.startAt,
        notes: s.notes,
        sourceDocumentId: docId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入医疗日历')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final childNeedsPick =
        AuthSession.role == AppRole.child && (widget.elders == null || widget.elders!.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('医疗单据智能识别')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            '拍照或上传后先预览裁剪，再识别归档；可选择放入病情文件夹。',
            style: TextStyle(color: Color(0xFF475569), height: 1.55),
          ),
          if (widget.elders != null && widget.elders!.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedElderKey,
              decoration: const InputDecoration(labelText: '为谁归档'),
              items: widget.elders!
                  .map((e) => DropdownMenuItem(value: e.id, child: Text(e.displayName)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedElderKey = v;
                  _targetFolderId = null;
                });
                _loadFolders();
              },
            ),
          ],
          if (!childNeedsPick && _childElderProfileId != null) ...[
            const SizedBox(height: 12),
            MedicalFolderPickerField(
              folders: _folders,
              selectedFolderId: _targetFolderId,
              onFolderChanged: (id) => setState(() => _targetFolderId = id),
              onCreateFolder: _createFolderFromPicker,
              enabled: !_busy,
            ),
          ],
          if (childNeedsPick)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('当前列表为空，请先在「家人」中绑定老人。', style: TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || childNeedsPick ? null : () => _run(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || childNeedsPick ? null : () => _run(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('相册'),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const Center(child: Text('识别并归档中…')),
          ],
          if (_previewFile != null && !_busy) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(_previewFile!, fit: BoxFit.cover),
              ),
            ),
          ],
          if (_result != null) ..._resultSection(),
        ],
      ),
    );
  }

  List<Widget> _resultSection() {
    final r = _result!;
    final ext = r.extractedFields;
    final title = r.title?.trim();
    return [
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title != null && title.isNotEmpty ? title : '医疗单据',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '档案编号 ${r.documentId}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              if (r.folderId != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF0369A1)),
                    const SizedBox(width: 4),
                    Text(
                      '已放入：${r.folderName ?? '文件夹 #${r.folderId}'}',
                      style: const TextStyle(color: Color(0xFF0369A1), fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '单据类别（推断）：${ext?.docCategory ?? '—'}',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              if (ext != null && ext.normalizedDates.isNotEmpty)
                Text('识别日期：${ext.normalizedDates.join('、')}'),
              if (ext != null && ext.matchedKeywords.isNotEmpty)
                Text('关键词：${ext.matchedKeywords.join('、')}'),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MedicalDocumentDetailPage(
                        documentId: r.documentId,
                        elderProfileId: _childElderProfileId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.article_outlined),
                label: const Text('查看全文与原件'),
              ),
            ],
          ),
        ),
      ),
      if (r.suggestedCalendarEvents.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('日历建议（可逐项添加）', style: TextStyle(fontWeight: FontWeight.w700)),
        ...r.suggestedCalendarEvents.map(
          (s) => Card(
            child: ListTile(
              title: Text(s.title),
              subtitle: Text('${s.eventType} · ${s.startAt.toString().substring(0, 16)}'),
              trailing: FilledButton(
                onPressed: () => _addSuggested(s, r.documentId),
                child: const Text('加入日历'),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}
