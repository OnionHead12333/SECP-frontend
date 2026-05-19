import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/community_scope.dart';
import '../../data/elder_avatar_repository.dart';
import 'community_member_avatar.dart';

/// 老人端：点击从相册更换头像。
final class ElderAvatarPickerTile extends StatefulWidget {
  const ElderAvatarPickerTile({
    super.key,
    this.size = 88,
    this.caption,
    this.showCaption = true,
    this.onChanged,
  });

  final double size;
  final String? caption;
  final bool showCaption;
  final VoidCallback? onChanged;

  @override
  State<ElderAvatarPickerTile> createState() => _ElderAvatarPickerTileState();
}

class _ElderAvatarPickerTileState extends State<ElderAvatarPickerTile> {
  String? _avatarPath;
  bool _loading = true;

  String get _scope => CommunityScope.forCurrentElder();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final path = await ElderAvatarRepository.loadPath(_scope);
    if (!mounted) return;
    setState(() {
      _avatarPath = path;
      _loading = false;
    });
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final saved = await ElderAvatarRepository.saveFromFile(scopeKey: _scope, sourcePath: picked.path);
    if (!mounted) return;
    setState(() => _avatarPath = saved);
    widget.onChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.size + (widget.showCaption ? 36 : 0),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CommunityMemberAvatar(
              displayName: '我',
              imagePath: _avatarPath,
              size: widget.size,
              onTap: () => unawaited(_pickFromGallery()),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: const Color(0xFF1565C0),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => unawaited(_pickFromGallery()),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.showCaption) ...[
          const SizedBox(height: 10),
          Text(
            widget.caption ?? '点击头像从相册选择',
            style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
        ],
      ],
    );
  }
}
