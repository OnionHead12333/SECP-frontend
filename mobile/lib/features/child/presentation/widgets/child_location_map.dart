import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 使用 OpenStreetMap 瓦片（无需 Key）。国内商用或加载慢时可换高德等 [TileLayer.urlTemplate]。
class ChildLocationMap extends StatelessWidget {
  const ChildLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 220,
  });

  final double latitude;
  final double longitude;
  final double height;

  static const _osmTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: _osmTemplate,
                  userAgentPackageName: 'smart_elderly_care_mobile',
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
        ),
        const SizedBox(height: 6),
        Text(
          '© OpenStreetMap 贡献者 · 仅供演示',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
