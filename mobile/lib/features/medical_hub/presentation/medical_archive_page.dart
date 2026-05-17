import 'package:flutter/material.dart';

import '../../../core/auth/app_role.dart';
import '../../../core/auth/auth_session.dart';
import '../../child/models/child_local_models.dart';
import '../data/medical_hub_api.dart';
import 'medical_document_detail_page.dart';

/// 档案筛选：全部 / 未归档 / 指定文件夹。
enum _ArchiveScope { all, unfiled, folder }

/// 医疗档案：文件夹展示 + 单据列表 + 归档至文件夹。
class MedicalArchivePage extends StatefulWidget {
  const MedicalArchivePage({super.key, this.elders});

  final List<BoundElder>? elders;

  @override
  State<MedicalArchivePage> createState() => _MedicalArchivePageState();
}

class _MedicalArchivePageState extends State<MedicalArchivePage> {
  String? _elderKey;
  String? _category;
  _ArchiveScope _scope = _ArchiveScope.all;
  int? _folderId;
  List<MedicalArchiveFolder> _folders = [];
  List<MedicalDocumentSummary> _allDocuments = [];
  List<MedicalDocumentSummary> _items = [];
  Map<int, int> _folderDocCounts = {};
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

  void _recomputeVisibleItems() {
    var items = _allDocuments;
    if (_category != null && _category!.isNotEmpty) {
      items = items.where((d) => d.docCategory == _category).toList();
    }
    items = switch (_scope) {
      _ArchiveScope.unfiled => items.where((d) => d.folderId == null).toList(),
      _ArchiveScope.folder => items.where((d) => d.folderId == _folderId).toList(),
      _ArchiveScope.all => items,
    };
    _items = items;
    _folderDocCounts = {};
    for (final f in _folders) {
      _folderDocCounts[f.id] = _allDocuments.where((d) => d.folderId == f.id).length;
    }
  }

  Future<void> _reload() async {
    if (AuthSession.role == AppRole.child && _elderProfileId == null) return;
    setState(() => _busy = true);
    try {
      final folders = await MedicalHubApi.listFolders(elderProfileId: _elderProfileId);
      final allDocs = await MedicalHubApi.listDocuments(
        elderProfileId: _elderProfileId,
        docCategory: _category != null && _category!.isNotEmpty ? _category : null,
      );
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _allDocuments = allDocs;
      });
      _recomputeVisibleItems();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectScope(_ArchiveScope scope, {int? folderId}) {
    setState(() {
      _scope = scope;
      _folderId = folderId;
    });
    _recomputeVisibleItems();
    setState(() {});
  }

  void _mergeFolder(MedicalArchiveFolder folder) {
    final idx = _folders.indexWhere((f) => f.id == folder.id);
    if (idx >= 0) {
      _folders[idx] = folder;
    } else {
      _folders = [..._folders, folder];
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('新建病情文件夹'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: '例如：幽门螺旋杆菌、2026年检查'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('创建')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || _elderProfileId == null) return;
    try {
      final folder = await MedicalHubApi.createFolder(elderProfileId: _elderProfileId!, name: name);
      if (!mounted) return;
      setState(() {
        _mergeFolder(folder);
        _scope = _ArchiveScope.folder;
        _folderId = folder.id;
      });
      _recomputeVisibleItems();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已创建「${folder.name}」')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _moveToFolder(MedicalDocumentSummary doc) async {
    if (_folders.isEmpty) {
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('暂无文件夹'),
          content: const Text('需要先新建病情文件夹，才能把档案归档进去。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去新建')),
          ],
        ),
      );
      if (create == true && mounted) await _createFolder();
      return;
    }
    final choice = await showModalBottomSheet<_MoveChoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  '归档：${doc.title ?? '未命名单据'}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '选择目标文件夹',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
              if (doc.folderId != null)
                ListTile(
                  leading: const Icon(Icons.folder_off_outlined),
                  title: const Text('移出文件夹（未归档）'),
                  onTap: () => Navigator.pop(ctx, const _MoveClear()),
                ),
              ..._folders.map(
                (f) => ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: doc.folderId == f.id ? Theme.of(ctx).colorScheme.primary : const Color(0xFF64748B),
                  ),
                  title: Text(f.name),
                  subtitle: Text('${_folderDocCounts[f.id] ?? 0} 份档案'),
                  trailing: doc.folderId == f.id ? const Icon(Icons.check, size: 20) : null,
                  onTap: () => Navigator.pop(ctx, _MoveFolder(f.id)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    try {
      await MedicalHubApi.moveDocumentToFolder(
        doc.id,
        elderProfileId: _elderProfileId,
        folderId: switch (choice) {
          _MoveClear() => null,
          _MoveFolder(:final id) => id,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新归档位置')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmDelete(MedicalDocumentSummary it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除档案'),
        content: Text('确定删除「${it.title ?? '未命名单据'}」？删除后不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await MedicalHubApi.deleteDocument(it.id, elderProfileId: _elderProfileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String get _listTitle {
    return switch (_scope) {
      _ArchiveScope.folder => _folders.where((f) => f.id == _folderId).map((f) => f.name).firstOrNull ?? '文件夹',
      _ArchiveScope.unfiled => '未归档档案',
      _ArchiveScope.all => '全部档案',
    };
  }

  String get _emptyHint {
    return switch (_scope) {
      _ArchiveScope.folder => '该文件夹还没有档案\n点击下方档案的「归档」按钮移入',
      _ArchiveScope.unfiled => '暂无未归档档案',
      _ArchiveScope.all => '暂无医疗档案，请先拍照识别单据',
    };
  }

  @override
  Widget build(BuildContext context) {
    final childNoElder =
        AuthSession.role == AppRole.child && (widget.elders == null || widget.elders!.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('医疗档案')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: childNoElder || _elderProfileId == null ? null : _createFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('新建文件夹'),
      ),
      body: childNoElder
          ? const Center(child: Text('请先绑定老人'))
          : RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),
                  SliverToBoxAdapter(child: _buildFolderSection()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text(_listTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text('共 ${_items.length} 条', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  if (_busy)
                    const SliverToBoxAdapter(child: LinearProgressIndicator())
                  else if (_items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _emptyHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _documentCard(_items[i]),
                          childCount: _items.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFolderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('病情文件夹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _elderProfileId == null ? null : _createFolder,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_folders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '还没有文件夹',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '可先新建文件夹（如「幽门螺旋杆菌」），再在下方档案上点「归档」移入。',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _elderProfileId == null ? null : _createFolder,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('新建第一个文件夹'),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _folderChip(
                  label: '全部',
                  count: _allDocuments.length,
                  selected: _scope == _ArchiveScope.all,
                  onTap: () => _selectScope(_ArchiveScope.all),
                ),
                _folderChip(
                  label: '未归档',
                  count: _allDocuments.where((d) => d.folderId == null).length,
                  selected: _scope == _ArchiveScope.unfiled,
                  onTap: () => _selectScope(_ArchiveScope.unfiled),
                ),
                ..._folders.map(
                  (f) => _folderChip(
                    label: f.name,
                    count: _folderDocCounts[f.id] ?? 0,
                    selected: _scope == _ArchiveScope.folder && _folderId == f.id,
                    onTap: () => _selectScope(_ArchiveScope.folder, folderId: f.id),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _folderChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder,
                size: 18,
                color: selected ? const Color(0xFF0369A1) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? const Color(0xFF0369A1) : const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 12, color: selected ? const Color(0xFF0369A1) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _documentCard(MedicalDocumentSummary it) {
    final inFolder = it.folderId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  inFolder ? Icons.folder_copy_outlined : Icons.description_outlined,
                  color: inFolder ? const Color(0xFF0369A1) : const Color(0xFF64748B),
                ),
                title: Text(it.title ?? '未命名单据'),
                subtitle: Text(
                  [
                    it.docCategory ?? '—',
                    it.createdAt.toString().substring(0, 16),
                    if (it.folderName != null && it.folderName!.isNotEmpty) '📁 ${it.folderName}',
                  ].join(' · '),
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MedicalDocumentDetailPage(
                        documentId: it.id,
                        elderProfileId: _elderProfileId,
                      ),
                    ),
                  );
                  if (mounted) _reload();
                },
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _moveToFolder(it),
                  icon: const Icon(Icons.drive_file_move_outline, size: 18),
                  label: const Text('归档'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0369A1),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                  onSelected: (v) {
                    if (v == 'move') _moveToFolder(it);
                    if (v == 'delete') _confirmDelete(it);
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'move', child: Text('移动到文件夹')),
                    PopupMenuItem(value: 'delete', child: Text('删除档案')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _MoveChoice {
  const _MoveChoice();
}

final class _MoveClear extends _MoveChoice {
  const _MoveClear();
}

final class _MoveFolder extends _MoveChoice {
  const _MoveFolder(this.id);
  final int id;
}
