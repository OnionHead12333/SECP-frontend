# E Integration Guide

This module is the reusable inspection map data layer and debug validation module. It is not the formal staff-side inspection map page.

E does not need to handle ROS coordinate conversion details directly. Formal pages can consume `InspectionMapRepository`, models, and mock data first, then switch to a real API repository later.

## What Formal Pages Can Reuse

- `InspectionMapRepository`
- `InspectionMapMockRepository`
- `InspectionMapApiRepository`
- `MapInfo`
- `InspectionMarker`
- `InspectionPlace`
- `InspectionRoute`
- `NavigationStatus`
- `ObstacleStatus`
- `coordinate_converter.dart`

## Data Needed By The Formal Page

The staff inspection map page should load and display:

- `mapInfo`
- `markers`
- `navigationStatus`
- `obstacleStatus`

When a marker is clicked, show the fields from `InspectionMarker`.

For `fall` markers, show these extra identity fields:

- `elderName`
- `identitySource`
- `identityConfidence`
- `notifiedChild`

When a fall or crack event is handled, call:

```dart
await repo.handleMarker(marker.id);
```

## Basic Usage

```dart
final repo = InspectionMapMockRepository();
final mapInfo = await repo.loadMapInfo();
final markers = await repo.loadMarkers();
final navStatus = await repo.loadNavigationStatus();
```

For the current SpringBoot mock backend:

```dart
final repo = InspectionMapApiRepository(
  baseUrl: 'http://localhost:8080/api',
);
final mapInfo = await repo.loadMapInfo();
final markers = await repo.loadMarkers();
final navStatus = await repo.loadNavigationStatus();
```

## Future API Switch

The formal page should depend on `InspectionMapRepository`, not directly on backend implementation details.

For the current mock phase:

```dart
final InspectionMapRepository repo = InspectionMapMockRepository();
```

For the later real API phase:

```dart
final InspectionMapRepository repo = InspectionMapApiRepository();
```

Only the repository implementation should change. The formal page can keep using the same models and method names.

The current Backend API source is still a SpringBoot mock layer. It is not ROS2, real car, or A gateway data. When those real integrations are ready, keep the `InspectionMapRepository` contract and replace the implementation behind it.
