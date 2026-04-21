class ElderLocationPoint {
  const ElderLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.recordedAt,
    required this.isHome,
    this.source = 'gaode',
    this.locationType = 'outdoor',
    this.uploaded = false,
  });

  final double latitude;
  final double longitude;
  final String label;
  final DateTime recordedAt;
  final bool isHome;
  final String source;
  final String locationType;
  final bool uploaded;

  ElderLocationPoint copyWith({
    double? latitude,
    double? longitude,
    String? label,
    DateTime? recordedAt,
    bool? isHome,
    String? source,
    String? locationType,
    bool? uploaded,
  }) {
    return ElderLocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      recordedAt: recordedAt ?? this.recordedAt,
      isHome: isHome ?? this.isHome,
      source: source ?? this.source,
      locationType: locationType ?? this.locationType,
      uploaded: uploaded ?? this.uploaded,
    );
  }
}
