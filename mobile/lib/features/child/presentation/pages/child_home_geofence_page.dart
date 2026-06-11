import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/child_geofence_api.dart';
import '../../models/child_local_models.dart';

/// 子女端：设置「家」的判定范围（半径，默认 500 米）。
class ChildHomeGeofencePage extends StatefulWidget {
  const ChildHomeGeofencePage({
    super.key,
    required this.elder,
  });

  final BoundElder elder;

  @override
  State<ChildHomeGeofencePage> createState() => _ChildHomeGeofencePageState();
}

class _ChildHomeGeofencePageState extends State<ChildHomeGeofencePage> {
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  HomeGeofenceConfig? _home;
  final _radiusController = TextEditingController();

  int get _elderId => int.parse(widget.elder.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  void _setRadiusField(int radius) {
    _radiusController.text = '$radius';
  }

  int? _parseRadiusInput() {
    final text = _radiusController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  String? _validateRadius(int? radius) {
    if (radius == null) return '请输入离家距离（米）';
    if (radius <= 0) return '离家距离须大于 0 米';
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final home = await ChildGeofenceApi.fetchHome(_elderId);
      if (!mounted) return;
      setState(() {
        _home = home;
        _setRadiusField(home?.radius ?? ChildGeofenceApi.defaultRadiusMeters);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _readCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('请先开启系统定位服务');
    }
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        throw Exception('定位权限被拒绝，请在系统设置中开启');
      }
      throw Exception('需要定位权限才能获取当前位置');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  int _radiusForSave() {
    return _parseRadiusInput() ?? ChildGeofenceApi.defaultRadiusMeters;
  }

  Future<void> _setHomeFromCurrentLocation() async {
    if (_saving || _locating) return;
    final radius = _radiusForSave();
    final validationError = _validateRadius(radius);
    if (validationError != null) {
      _toast(validationError);
      return;
    }
    setState(() => _locating = true);
    try {
      final position = await _readCurrentPosition();
      if (!mounted) return;

      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('将当前位置设为家？'),
          content: Text(
            '系统将以您当前所在位置作为「家」的中心点，用于判断老人是否出门。\n\n'
            '当前定位：\n纬度 ${position.latitude.toStringAsFixed(5)}\n'
            '经度 ${position.longitude.toStringAsFixed(5)}\n\n'
            '离家距离：$radius 米',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('设为家'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;

      setState(() => _saving = true);
      await ChildGeofenceApi.saveHome(
        elderId: _elderId,
        latitude: position.latitude,
        longitude: position.longitude,
        radius: radius,
      );
      if (!mounted) return;
      _toast('已将当前位置设为家');
      await _load();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final home = _home;
    if (home == null) {
      _toast('请先设置家的位置。');
      return;
    }
    final radius = _parseRadiusInput();
    final validationError = _validateRadius(radius);
    if (validationError != null) {
      _toast(validationError);
      return;
    }
    setState(() => _saving = true);
    try {
      await ChildGeofenceApi.saveHome(
        elderId: _elderId,
        latitude: home.latitude,
        longitude: home.longitude,
        radius: radius!,
        name: home.name,
      );
      if (!mounted) return;
      _toast('已保存：离家 $radius 米判定为出门');
      await _load();
    } catch (e) {
      _toast('保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.elder.displayName} · 家的范围')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '出门判定说明',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '当老人离开「家」中心点超过下方距离时，系统会记录为出门；回到该范围内则记录为回家。消息会在安全页「老人位置消息」中展示，最多保留 10 条。',
                          style: TextStyle(height: 1.55, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '家的位置',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (home == null)
                          const Text(
                            '尚未设置。您可在下方将当前位置设为家，或由老人端开启定位守护时按提示设置。',
                            style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                          )
                        else ...[
                          Text('中心：${home.latitude.toStringAsFixed(5)}, ${home.longitude.toStringAsFixed(5)}'),
                          Text('当前半径：${home.radius} 米'),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving || _locating ? null : _setHomeFromCurrentLocation,
                            icon: _locating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(_locating ? '正在获取定位...' : '将当前位置设为家'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '离家多远算出门',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _radiusController,
                          enabled: !_saving && !_locating,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: '离家距离',
                            hintText: '例如 ${ChildGeofenceApi.defaultRadiusMeters}',
                            suffixText: '米',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '默认 500 米。范围越大越不易误报，但出门判定会更晚触发。',
                          style: TextStyle(color: Color(0xFF64748B), height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: home == null || _saving || _locating ? null : _save,
                            child: Text(_saving ? '保存中...' : '保存范围设置'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
