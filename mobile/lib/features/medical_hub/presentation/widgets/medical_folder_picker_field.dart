import 'package:flutter/material.dart';

import '../../data/medical_hub_api.dart';

/// 识别前选择病情文件夹（可选新建）。
class MedicalFolderPickerField extends StatelessWidget {
  const MedicalFolderPickerField({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.onFolderChanged,
    required this.onCreateFolder,
    this.enabled = true,
  });

  final List<MedicalArchiveFolder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onFolderChanged;
  final Future<void> Function() onCreateFolder;
  final bool enabled;

  static const int unfiledValue = -1;
  static const int createValue = -2;

  @override
  Widget build(BuildContext context) {
    final value = selectedFolderId ?? unfiledValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          value: value,
          decoration: const InputDecoration(
            labelText: '归档到文件夹',
            helperText: '识别完成后将自动放入所选文件夹',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: unfiledValue, child: Text('暂不放入文件夹')),
            ...folders.map(
              (f) => DropdownMenuItem(value: f.id, child: Text(f.name)),
            ),
            const DropdownMenuItem(
              value: createValue,
              child: Row(
                children: [
                  Icon(Icons.add, size: 18, color: Color(0xFF0369A1)),
                  SizedBox(width: 8),
                  Text('新建文件夹…', style: TextStyle(color: Color(0xFF0369A1))),
                ],
              ),
            ),
          ],
          onChanged: !enabled
              ? null
              : (v) async {
                  if (v == null) return;
                  if (v == createValue) {
                    await onCreateFolder();
                    return;
                  }
                  onFolderChanged(v == unfiledValue ? null : v);
                },
        ),
      ],
    );
  }
}
