import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../data/elder_user_profile_api.dart';

class ElderProfileEditPage extends StatefulWidget {
  const ElderProfileEditPage({super.key});

  @override
  State<ElderProfileEditPage> createState() => _ElderProfileEditPageState();
}

class _ElderProfileEditPageState extends State<ElderProfileEditPage> {
  final _nameCtrl = TextEditingController();
  String _gender = 'unknown';
  DateTime? _birthday;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ElderUserProfileApi.fetchProfile();
      if (!mounted) return;
      _nameCtrl.text = p.name;
      _gender = p.gender == 'male' || p.gender == 'female' || p.gender == 'unknown' ? p.gender! : 'unknown';
      if (p.birthday != null && p.birthday!.isNotEmpty) {
        _birthday = DateTime.tryParse(p.birthday!);
      } else {
        _birthday = null;
      }
    } catch (e) {
      if (!mounted) return;
      _nameCtrl.text = AuthSession.elderName ?? '';
      _gender = (AuthSession.elderGender == 'male' || AuthSession.elderGender == 'female') ? AuthSession.elderGender! : 'unknown';
      if (AuthSession.elderBirthday != null && AuthSession.elderBirthday!.isNotEmpty) {
        _birthday = DateTime.tryParse(AuthSession.elderBirthday!);
      }
      if (e is! DioException) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      } else {
        setState(() => _error = '无法从服务器加载资料，已显示本地信息');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _formatBirthForApi() {
    if (_birthday == null) return null;
    final d = _birthday!;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _birthDisplay() {
    if (_birthday == null) return '未设置';
    final d = _birthday!;
    return '${d.year} 年 ${d.month} 月 ${d.day} 日';
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = _birthday ?? DateTime(now.year - 70, now.month, now.day);
    final first = DateTime(1900);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
              ? last
              : initial,
      firstDate: first,
      lastDate: last,
      helpText: '选择出生日期',
      cancelText: '取消',
      confirmText: '确定',
      errorFormatText: '请输入有效日期',
      errorInvalidText: '超出可选范围',
      fieldHintText: '年/月/日',
      fieldLabelText: '输入日期',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  String? _validate() {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty) return '请输入称呼或姓名';
    if (n.length > 30) return '名称不超过 30 个字';
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await ElderUserProfileApi.update(
        name: _nameCtrl.text.trim(),
        gender: _gender,
        birthday: _formatBirthForApi(),
      );
      if (!mounted) return;
      AuthSession.saveElderState(
        name: p.name,
        phone: p.phone,
        claimed: p.claimed ?? AuthSession.elderClaimed,
        familyCount: p.familyCount ?? AuthSession.elderFamilyCount,
        gender: p.gender,
        birthday: p.birthday,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (e is DioException) {
        setState(() => _error = '网络异常，请稍后重试');
      } else {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        title: const Text('个人信息'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '称呼 / 昵称',
                    hintText: '在首页和家属端显示的名称',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 20),
                const Text('性别', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: 'male', label: Text('男'), icon: Icon(Icons.male_outlined, size: 18)),
                    ButtonSegment<String>(value: 'female', label: Text('女'), icon: Icon(Icons.female_outlined, size: 18)),
                    ButtonSegment<String>(value: 'unknown', label: Text('不愿透露')),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) setState(() => _gender = s.first);
                  },
                  multiSelectionEnabled: false,
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 20),
                const Text('出生日期', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    title: Text(_birthDisplay()),
                    trailing: const Icon(Icons.calendar_today_outlined, size: 20),
                    onTap: _saving ? null : _pickBirthday,
                    onLongPress: _birthday == null
                        ? null
                        : () {
                            setState(() => _birthday = null);
                          },
                  ),
                ),
                if (_birthday != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('长按日期可清除', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('保存修改'),
                ),
                const SizedBox(height: 12),
                const Text('说明：信息保存在账号（users）中；若已认领老人档案，会同步到档案表供家属端使用。', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.45)),
              ],
            ),
    );
  }
}
