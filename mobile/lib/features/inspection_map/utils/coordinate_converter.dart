import '../models/map_info.dart';

class MapPoint {
  const MapPoint({required this.x, required this.y});

  final double x;
  final double y;
}

class PixelPoint {
  const PixelPoint({required this.x, required this.y});

  final double x;
  final double y;
}

MapPoint pixelToMap(double pixelX, double pixelY, MapInfo mapInfo) {
  return MapPoint(
    x: mapInfo.originX + pixelX * mapInfo.resolution,
    y: mapInfo.originY + (mapInfo.imageHeight - pixelY) * mapInfo.resolution,
  );
}

PixelPoint mapToPixel(double mapX, double mapY, MapInfo mapInfo) {
  return PixelPoint(
    x: (mapX - mapInfo.originX) / mapInfo.resolution,
    y: mapInfo.imageHeight - (mapY - mapInfo.originY) / mapInfo.resolution,
  );
}
