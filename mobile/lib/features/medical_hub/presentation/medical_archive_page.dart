import 'package:flutter/material.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../../child/models/child_local_models.dart';
import '../data/medical_hub_api.dart';
import 'medical_document_detail_page.dart';

/// 医疗档案列表（按时间倒序，可按类别筛选）。
class MedicalArchivePage extends StatefulWidget {
  const MedicalArchivePage({super.key, this.elders});

  final List<BoundElder>? elders;

  @override
  State<MedicalArchivePage> createState() => _MedicalArchivePageState();
}

class _MedicalArchivePageState extends State<MedicalArchivePage> {
  String? _elderKey;
  String? _category;
  List<MedicalDocumentSummary> _items = [];
  bool _busy = false;

  int? get _elderProfileId {
    if (AuthSession.role == AppRole.child) {
      if (widget.elders == null || widget.elders!.isEmpty) return null;
      final key = _elderKey ?? widget.elders!.first.id;
      return int.tryParse(key);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.elders != null && widget.elders!.isNotEmpty) {
      _elderKey = widget.elders!.first.id;
    }
    _reload();
  }

  Future<void> _reload() async {
    if (AuthSession.role == AppRole.child && _elderProfileId == null) return;
    setState(() => _busy = true);
    try {
      final list = await MedicalHubApi.listDocuments(
        elderProfileId: _elderProfileId,
        docCategory: _category != null && _category!.isNotEmpty ? _category : null,
      );
      if (!mounted) return;
      setState(() => _items = list);
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
    final childNoElder =
        AuthSession.role == AppRole.child && (widget.elders == null || widget.elders!.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('医疗档案')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await showDialog<String>(
            context: context,
            builder: (ctx) {
              final c = TextEditingController();
              return AlertDialog(
                title: const Text('新建病情文件夹'),
                content: TextField(controller: c, decoration: const InputDecoration(hintText: '文件夹名称')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('创建')),
                ],
              );
            },
          );
          if (name == null || name.isEmpty || _elderProfileId == null) return;
          try {
            await MedicalHubApi.createFolder(elderProfileId: _elderProfileId!, name: name);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已创建文件夹')));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
            );
          }
        },
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('文件夹'),
      ),
      body: childNoElder
          ? const Center(child: Text('请先绑定老人'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      if (widget.elders != null && widget.elders!.isNotEmpty)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _elderKey,
                            decoration: const InputDecoration(labelText: '老人'),
                            items: widget.elders!
                                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.displayName)))
                                .toList(),
                            onChanged: (v) {
                              setState(() => _elderKey = v);
                              _reload();
                            },
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _category ?? '',
                          decoration: const InputDecoration(labelText: '单据类型'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('全部')),
                            DropdownMenuItem(value: 'LAB_REPORT', child: Text('检验检查')),
                            DropdownMenuItem(value: 'PRESCRIPTION', child: Text('处方')),
                            DropdownMenuItem(value: 'BILLING', child: Text('票据费用')),
                            DropdownMenuItem(value: 'RECORD', child: Text('病历记录')),
                            DropdownMenuItem(value: 'OTHER', child: Text('其他')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _category = v == null || v.isEmpty ? null : v;
                            });
                            _reload();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final it = _items[i];
                        return Card(
                          child: ListTile(
                            title: Text(it.title ?? '未命名单据'),
                            subtitle: Text(
                              '${it.docCategory ?? '—'} · ${it.createdAt.toString().substring(0, 16)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MedicalDocumentDetailPage(
                                    documentId: it.id,
                                    elderProfileId: _elderProfileId,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
