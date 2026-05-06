import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/medical_hub_api.dart';

/// 单据详情：全文 + 归档图片。
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
  Map<String, dynamic>? _detail;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('单据 #${widget.documentId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_imageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _detail?['title'] as String? ?? '医疗单据',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text('类别：${_detail?['docCategory'] ?? '—'}'),
                    Text('结构化路由：${_detail?['routedSpecializedApi'] ?? '—'}'),
                    const SizedBox(height: 12),
                    const Text('识别全文', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SelectableText(
                      (_detail?['fullText'] as String?)?.isEmpty ?? true
                          ? '（无）'
                          : _detail!['fullText'] as String,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ),
    );
  }
}
