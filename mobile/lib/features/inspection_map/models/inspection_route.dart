class InspectionRoute {
  const InspectionRoute({
    required this.id,
    required this.name,
    required this.placeIds,
  });

  final String id;
  final String name;
  final List<String> placeIds;

  factory InspectionRoute.fromJson(Map<String, dynamic> json) {
    final rawPlaceIds = json['placeIds'];
    return InspectionRoute(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      placeIds: rawPlaceIds is List
          ? rawPlaceIds.map((value) => '$value').toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'placeIds': placeIds};
  }
}
