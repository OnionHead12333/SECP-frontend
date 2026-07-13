# Inspection Map Debug Module

This module is a local map/navigation/inspection data-layer validation module. It is not the formal staff-side inspection map page.

## Ownership

- E owns the formal Flutter App pages, staff-side inspection map page, marker detail dialog, event handling buttons, and child-side alert pages.
- This module owns map resources, coordinate conversion, marker models, mock JSON data, a mock repository, and an isolated debug verification page.

## What This Module Provides

- Map asset metadata for the verified `yahboomcar` SLAM map.
- Pixel to ROS map coordinate conversion.
- ROS map to pixel coordinate conversion.
- `InspectionMapRepository` as the reusable data-layer contract.
- `InspectionMapMockRepository` as the current mock implementation.
- `InspectionMapApiRepository` as the SpringBoot mock HTTP implementation.
- Marker models for `robot`, `target`, `fall`, `crack`, and `obstacle`.
- Mock JSON files for places, routes, markers, navigation status, and obstacle status.
- A standalone debug app entry point that does not connect to the main app navigation.

## Delivery Documents

- [HANDOFF_SUMMARY.md](HANDOFF_SUMMARY.md): module handoff summary for E, backend, and A integration.
- [REAL_CAR_INTEGRATION_CHECKLIST.md](REAL_CAR_INTEGRATION_CHECKLIST.md): real-car integration checklist and first-run safety scope.
- [E_INTEGRATION_GUIDE.md](E_INTEGRATION_GUIDE.md): formal page integration guidance for E.
- [inspection_map_api_contract.md](inspection_map_api_contract.md): mock and future API field contract.

## Verified Map Parameters

```text
width = 608
height = 384
resolution = 0.05
origin = [-10, -10, 0]
imageHeight = 384
pixel(100,100) -> map(-5,4.2) -> pixel(100,100)
```

## Phase 1 Validation Result

The isolated debug page has been verified locally:

- `yahboomcar.png` renders correctly.
- `robot`, `target`, `fall`, `crack`, and `obstacle` markers render correctly.
- Map clicks show pixel coordinates and ROS map coordinates.
- `initial_pose` and `nav_goal` JSON payloads are generated.
- Identity fall marker details display `elderName`, `identitySource`, `identityConfidence`, and `notifiedChild`.
- Fall and crack markers can be marked as handled in the mock repository.
- `flutter analyze lib/features/inspection_map` passes.

## Current Final Validation Result

- `Mock assets` visual validation passed.
- `Backend API` visual validation passed.
- `Mark handled` passed.
- `Start navigation` passed.
- `Cancel` passed.
- `Return home` passed.
- `Refresh` passed.
- Backend shutdown handling passed: the page shows an error, does not crash, and can switch back to `Mock assets`.
- `flutter analyze lib/features/inspection_map` passed.

## Debug Entry

Run the isolated debug page with:

```powershell
cd D:/Desktop/little_semaster/05/SECP-frontend/mobile
$env:PUB_CACHE="D:\Desktop\little_semaster\.pub-cache"
flutter run -d chrome -t lib/features/inspection_map/presentation/inspection_map_debug_app.dart --web-port 54321
```

This entry does not modify or enter the formal child / elder / staff pages.

## Flutter Toolchain Note

The local Flutter SDK writes a lock file under:

```text
D:\apps\flutter\bin\cache\lockfile
```

If the current sandbox or terminal cannot write this file, Flutter commands may appear to hang with no output:

```text
flutter --version
flutter analyze
flutter run
```

Before running Flutter commands, set a local pub cache:

```powershell
$env:PUB_CACHE="D:\Desktop\little_semaster\.pub-cache"
```

If Flutter still hangs, check whether the current terminal can write to `D:\apps\flutter\bin\cache\lockfile`, or run Flutter from a terminal with the required permission. This is a Flutter SDK toolchain permission issue, not an `inspection_map` code issue.

## Data Sources

The debug page supports two data sources:

- `Mock assets`: default mode. It reads local files from `assets/robot_maps/` and works without starting the backend.
- `Backend API`: reads the SpringBoot mock endpoints from `http://localhost:8080/api`.

Use the data-source switch at the top of the debug page, then click `Refresh` to reload map info, markers, places, routes, navigation status, and obstacle status.

The Backend API mode is still mock data. It does not connect to ROS2, the real car, or the A gateway.

## Future Integration

When the real robot and backend are ready, replace `InspectionMapMockRepository` with `InspectionMapApiRepository`.

```dart
final InspectionMapRepository repo = InspectionMapMockRepository();
```

can become:

```dart
final InspectionMapRepository repo = InspectionMapApiRepository();
```

The formal page should keep using the same repository methods, models, and coordinate converter. Only the repository implementation should change from mock JSON to A gateway or backend APIs, such as navigation status, obstacle status, goal pose publishing, and marker event feeds.
