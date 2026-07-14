# Inspection Map API Contract

This contract is for the staff inspection map data layer. It documents the fields expected by the Flutter map module and can be implemented later by the backend or A gateway. No real API is connected in the current debug module.

## 1. Map Info

`GET /api/v1/inspection/map`

Response fields:

| Field | Type | Description |
| --- | --- | --- |
| `mapId` | string/int | Map identifier. |
| `mapName` | string | Human-readable map name. |
| `mapImage` | string | Map image URL or asset path. |
| `width` | int | Map image width in pixels. |
| `height` | int | Map image height in pixels. |
| `resolution` | double | Meters per pixel. |
| `originX` | double | ROS map origin x. |
| `originY` | double | ROS map origin y. |
| `originYaw` | double | ROS map origin yaw. |
| `imageHeight` | int | Image height used by pixel-to-map conversion. |

## 2. Map Markers

Endpoints:

- `GET /api/v1/inspection/markers`
- `POST /api/v1/inspection/markers`
- `GET /api/v1/inspection/markers/{id}`
- `PUT /api/v1/inspection/markers/{id}/handle`

Marker fields:

| Field | Type | Description |
| --- | --- | --- |
| `id` | int/string | Marker identifier. |
| `type` | string | Marker type. |
| `x` | double | Web map pixel x. |
| `y` | double | Web map pixel y. |
| `level` | string | Severity level, such as `info`, `warning`, or `danger`. |
| `title` | string | Marker title. |
| `message` | string | Marker detail message. |
| `imageUrl` | string? | Optional event image URL. |
| `time` | string | Event or marker update time. |
| `status` | string | Marker status, such as `unhandled`, `handled`, or `active`. |
| `locationName` | string? | Human-readable location name. |
| `elderId` | int? | Matched elder id for fall marker. |
| `elderName` | string? | Matched elder name or unknown label for fall marker. |
| `identitySource` | string? | Identity source, such as `recent_identity` or `unknown`. |
| `identityConfidence` | double? | Identity confidence from 0 to 1. |
| `notifiedChild` | bool? | Whether the child-side alert was notified. |

## 3. Marker Types

Supported marker types:

- `fall`
- `crack`
- `robot`
- `target`
- `obstacle`

`face` is not a default map marker type. Identity data is merged into the `fall` marker detail fields.

## 4. Identity Fall Event

`POST /api/v1/fall/events`

Fields:

| Field | Type | Description |
| --- | --- | --- |
| `fallAlert` | bool | Whether a fall event is detected. |
| `riskLevel` | string | Fall risk level. |
| `elderId` | int? | Matched elder id. |
| `elderName` | string? | Matched elder name or unknown label. |
| `identitySource` | string | Identity source. |
| `identityConfidence` | double | Identity confidence from 0 to 1. |
| `locationName` | string | Human-readable location name. |
| `x` | double | Web map pixel x. |
| `y` | double | Web map pixel y. |
| `imageUrl` | string? | Fall snapshot URL. |
| `time` | string | Event time. |

Known fall events should set `notifiedChild=true` in the generated fall marker. Unknown fall events should set `notifiedChild=false`.

## 5. Navigation

Endpoints:

- `POST /api/v1/navigation/start`
- `POST /api/v1/navigation/cancel`
- `POST /api/v1/navigation/return-home`
- `GET /api/v1/navigation/status`
- `POST /api/v1/navigation/status`

`navigationStatus` enum:

- `idle`
- `running`
- `arrived`
- `failed`
- `paused`

## 6. Obstacle Status

Endpoints:

- `GET /api/v1/obstacle/status`
- `POST /api/v1/obstacle/status`

`obstacleStatus` enum:

- `safe`
- `obstacle`
- `unknown`

## 7. ROS2 / A Gateway Topics

Expected integration fields or topic sources:

- `/inspection_map/goal_pose`
- `/initialpose`
- `/amcl_pose`
- `/navigation_status`
- `/obstacle_status`
- `/ai/detection_result`
