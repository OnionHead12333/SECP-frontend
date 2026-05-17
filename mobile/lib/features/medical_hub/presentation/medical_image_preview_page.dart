import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../utils/medical_image_transform.dart';

/// 医疗单据选图后的预览与手动矩形裁剪；确认后返回待上传 [File]。
class MedicalImagePreviewPage extends StatefulWidget {
  const MedicalImagePreviewPage({super.key, required this.sourceFile});

  final File sourceFile;

  @override
  State<MedicalImagePreviewPage> createState() => _MedicalImagePreviewPageState();
}

enum _PreviewMode { preview, cropping, croppedPreview }

class _MedicalImagePreviewPageState extends State<MedicalImagePreviewPage> {
  final CropController _cropController = CropController();

  Uint8List? _imageBytes;
  File? _croppedFile;
  bool _loading = true;
  bool _cropping = false;
  bool _rotating = false;
  String? _loadError;
  _PreviewMode _mode = _PreviewMode.preview;
  File? _workingFile;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
  }

  Future<void> _loadSourceImage() async {
    try {
      final bytes = await widget.sourceFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _workingFile = widget.sourceFile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<File> _persistBytes(Uint8List bytes, String prefix) async {
    final path =
        '${Directory.systemTemp.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _rotate({required bool clockwise}) async {
    final bytes = _imageBytes;
    if (bytes == null || _rotating) return;
    setState(() {
      _rotating = true;
      _croppedFile = null;
    });
    try {
      final rotated = await rotateImageBytes(bytes, clockwise: clockwise);
      final file = await _persistBytes(rotated, 'medical_rot');
      if (!mounted) return;
      setState(() {
        _imageBytes = rotated;
        _workingFile = file;
        if (_mode == _PreviewMode.croppedPreview) {
          _mode = _PreviewMode.preview;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('旋转失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  File _fileForUpload() {
    if (_mode == _PreviewMode.croppedPreview && _croppedFile != null) {
      return _croppedFile!;
    }
    return _workingFile ?? widget.sourceFile;
  }

  void _onCropResult(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropFailure(:final cause):
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('裁剪失败：$cause')),
        );
      case CropSuccess(:final croppedImage):
        _persistBytes(croppedImage, 'medical_crop').then((file) {
          if (!mounted) return;
          setState(() {
            _croppedFile = file;
            _cropping = false;
            _mode = _PreviewMode.croppedPreview;
          });
        }).catchError((Object e) {
          if (!mounted) return;
          setState(() => _cropping = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存裁剪结果失败：$e')),
          );
        });
    }
  }

  void _confirmUpload(File file) {
    Navigator.of(context).pop(file);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_cropping && !_rotating,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || (!_cropping && !_rotating)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cropping ? '正在裁剪，请稍候…' : '正在旋转，请稍候…')),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: Text(_appBarTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cropping || _rotating ? null : () => Navigator.of(context).pop(),
          ),
          actions: [
            if (!_loading && _loadError == null && _imageBytes != null && _mode != _PreviewMode.cropping)
              IconButton(
                tooltip: '逆时针旋转 90°',
                onPressed: _rotating ? null : () => _rotate(clockwise: false),
                icon: const Icon(Icons.rotate_left),
              ),
            if (!_loading && _loadError == null && _imageBytes != null && _mode != _PreviewMode.cropping)
              IconButton(
                tooltip: '顺时针旋转 90°',
                onPressed: _rotating ? null : () => _rotate(clockwise: true),
                icon: const Icon(Icons.rotate_right),
              ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _loading || _loadError != null || _imageBytes == null
            ? null
            : _buildBottomBar(),
      ),
    );
  }

  String get _appBarTitle {
    return switch (_mode) {
      _PreviewMode.preview => '预览单据照片',
      _PreviewMode.cropping => '拖动框选单据区域',
      _PreviewMode.croppedPreview => '裁剪结果预览',
    };
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('正在加载图片…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '无法读取图片：$_loadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (_rotating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('正在旋转…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    final bytes = _imageBytes!;
    return switch (_mode) {
      _PreviewMode.preview => _buildPreview(bytes),
      _PreviewMode.cropping => _buildCropEditor(bytes),
      _PreviewMode.croppedPreview => _buildCroppedPreview(),
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildPreview(Uint8List bytes) {
    final sourceSize = widget.sourceFile.lengthSync();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            '请确认单据是否完整、文字清晰。可双指缩放查看细节，或进入裁剪去掉多余背景。\n原图约 ${_formatFileSize(sourceSize)}',
            style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 14),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropEditor(Uint8List bytes) {
    return Stack(
      children: [
        Crop(
          image: bytes,
          controller: _cropController,
          onCropped: _onCropResult,
          withCircleUi: false,
          interactive: true,
          initialRectBuilder: InitialRectBuilder.withSizeAndRatio(size: 0.85),
          maskColor: Colors.black.withValues(alpha: 0.55),
          baseColor: const Color(0xFF1E293B),
          radius: 4,
          cornerDotBuilder: (size, edge) => DotControl(color: Colors.white.withValues(alpha: 0.95)),
        ),
        if (_cropping)
          const ColoredBox(
            color: Color(0x88000000),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('正在生成裁剪图…', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCroppedPreview() {
    final file = _croppedFile;
    if (file == null) {
      return const Center(child: Text('暂无裁剪结果', style: TextStyle(color: Colors.white70)));
    }
    final croppedSize = file.lengthSync();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            '以下为裁剪后的效果（约 ${_formatFileSize(croppedSize)}）。若不满意可重新裁剪或恢复原图。',
            style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 14),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: switch (_mode) {
          _PreviewMode.preview => _previewActions(),
          _PreviewMode.cropping => _croppingActions(),
          _PreviewMode.croppedPreview => _croppedPreviewActions(),
        },
      ),
    );
  }

  Widget _previewActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _mode = _PreviewMode.cropping),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.crop_outlined),
            label: const Text('裁剪区域'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _confirmUpload(_fileForUpload()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('使用原图识别'),
          ),
        ),
      ],
    );
  }

  Widget _croppingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _cropping
                ? null
                : () => setState(() => _mode = _PreviewMode.preview),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('返回预览'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _cropController.crop();
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.check),
            label: const Text('完成裁剪'),
          ),
        ),
      ],
    );
  }

  Widget _croppedPreviewActions() {
    final cropped = _croppedFile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _mode = _PreviewMode.cropping;
                  _croppedFile = null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('重新裁剪'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _croppedFile = null;
                  _mode = _PreviewMode.preview;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('恢复原图'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: cropped == null ? null : () => _confirmUpload(cropped),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('使用裁剪图识别'),
          ),
        ),
      ],
    );
  }
}
