import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 多图源可切换：默认高德栅格（国内易加载），可选 Esri / OSM-DE。
/// 高德为 Web 常用非官方瓦片地址，正式环境请改用合规 SDK 或自有瓦片服务。
class _RasterSpec {
  const _RasterSpec({
    required this.urlTemplate,
    this.subdomains = const [],
    required this.attribution,
    this.tileProvider,
    this.fallbackUrl,
  });

  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
  final TileProvider? tileProvider;
  final String? fallbackUrl;
}

class ChildLocationMap extends StatefulWidget {
  const ChildLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height,
    this.expandInParent = false,
  });

  final double latitude;
  final double longitude;
  final double? height;
  final bool expandInParent;

  static const _gaodeUa =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  /// 顺序：国内优先高德 → 全球 Esri → OSM 德国镜像（部分网络下比 osm.org 可用）
  static final List<_RasterSpec> _sources = [
    _RasterSpec(
      urlTemplate:
          'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
      subdomains: const ['1', '2', '3', '4'],
      attribution: '高德底图（演示）',
      tileProvider: NetworkTileProvider(
        headers: {
          'User-Agent': _gaodeUa,
          'Referer': 'https://www.amap.com/',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
      ),
      fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
    ),
    const _RasterSpec(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Esri, Maxar, GeoEye, Earthstar Geographics, GIS 用户社区',
      fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
    ),
    const _RasterSpec(
      urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap 贡献者, OpenStreetMap Germany',
    ),
  ];

  @override
  State<ChildLocationMap> createState() => _ChildLocationMapState();
}

class _ChildLocationMapState extends State<ChildLocationMap> {
  int _sourceIndex = 0;

  double _defaultHeight(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return (sh * 0.42).clamp(300.0, 560.0);
  }

  Widget _attributionLine(BuildContext context, String text) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 6,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
      ),
    );
  }

  Widget _sourceChip(BuildContext context) {
    final n = ChildLocationMap._sources.length;
    final idx = _sourceIndex % n;
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        elevation: 1,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => setState(() => _sourceIndex = (_sourceIndex + 1) % n),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '图源 ${idx + 1}/$n · 点按切换',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapStack(BuildContext context, LatLng point) {
    final spec = ChildLocationMap._sources[_sourceIndex % ChildLocationMap._sources.length];

    return Stack(
      fit: widget.expandInParent ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: ValueKey<int>(_sourceIndex),
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 18,
              backgroundColor: const Color(0xFFB8C5D8),
            ),
            children: [
              TileLayer(
                urlTemplate: spec.urlTemplate,
                subdomains: spec.subdomains,
                userAgentPackageName: 'smart_elderly_care_mobile',
                tileProvider: spec.tileProvider,
                fallbackUrl: spec.fallbackUrl,
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    alignment: Alignment.bottomCenter,
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: Theme.of(context).colorScheme.error,
                      shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _sourceChip(context),
        _attributionLine(context, '${spec.attribution} · 仅供演示'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);

    final mapBody = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.expandInParent
          ? _mapStack(context, point)
          : SizedBox(
              height: widget.height ?? _defaultHeight(context),
              width: double.infinity,
              child: _mapStack(context, point),
            ),
    );

    if (widget.expandInParent) {
      return mapBody;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        mapBody,
        const SizedBox(height: 6),
        Text(
          '若仍为灰底或错位，请点地图右上角「图源」依次切换；正式版请接入高德/天地图等合规服务。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
