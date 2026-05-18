import 'package:flutter/material.dart';

import '../../utils/medical_fulltext_structure.dart';

/// 横向可滚动的检验结果表。
class MedicalLabResultTableView extends StatelessWidget {
  const MedicalLabResultTableView({super.key, required this.table});

  final MedicalResultTable table;

  @override
  Widget build(BuildContext context) {
    if (table.rows.isEmpty) return const SizedBox.shrink();

    final headers = table.headers;
    final colCount = headers.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (table.caption != null && table.caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              color: const Color(0xFFF1F5F9),
              child: Text(
                table.caption!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFEFF6FF)),
              columnSpacing: 20,
              horizontalMargin: 14,
              columns: [
                for (final h in headers)
                  DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
              ],
              rows: [
                for (final row in table.rows)
                  DataRow(
                    cells: [
                      for (var i = 0; i < colCount; i++)
                        DataCell(
                          SelectableText(
                            i < row.length ? row[i] : '—',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == 0 ? FontWeight.w600 : FontWeight.normal,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
