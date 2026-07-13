# Child Remote Car Control Design

## Goal

Add a child-side remote car control page without changing employee map features or existing child-side flows. The page supports two control modes:

- ROS2 gateway: calls a user-configured gateway base URL directly.
- TCP direct: opens a socket to the car and sends the car protocol directly.

The TCP path must not be routed through the SpringBoot backend.

## Entry And Navigation

Add a child-side route, `/child/remote-car`, and expose it from the existing child Safety tab. This keeps the bottom navigation unchanged and avoids touching the employee inspection map.

## Data Clients

### ROS2 Gateway

Create a child remote car gateway client that accepts `gatewayBaseUrl` from the page.

- Send commands with `POST {gatewayBaseUrl}/api/command`.
- Refresh state with `GET {gatewayBaseUrl}/api/state`.
- Supported command strings: `forward`, `backward`, `left`, `right`, `stop`, `emergency_stop`, `reset_emergency`.
- The client must use the configured gateway URL directly, not the app's SpringBoot `ApiClient` base URL.

The page displays:

- `current_cmd`
- `fall_alert`
- `risk_level`
- `obstacle_status`
- `navigation_status`
- `control_connected`
- `emergency_stop`
- `control_block_reason`

### TCP Direct

Bring the protocol logic from `D:\BJTU6\smartcar\smart_car_flutter\lib\car\car_tcp_client.dart` and `D:\BJTU6\smartcar\smart_car_flutter\lib\car\car_encoder.dart` into this Flutter app under the child remote car feature. Keep the same `dart:io Socket` direct connection behavior.

The page asks for car IP and port, with port defaulting to `6000`. Commands map to encoded car directions:

- `forward` -> `CarDirection.front`
- `backward` -> `CarDirection.back`
- `left` -> `CarDirection.leftRotate`
- `right` -> `CarDirection.rightRotate`
- `stop` -> `CarDirection.stop`
- `emergency_stop` -> `CarDirection.brake`
- `reset_emergency` -> disabled in TCP mode

## UI

The page uses one shared control pad for both modes:

- top segmented mode switch
- mode-specific configuration fields
- connection status and last command
- direction buttons: forward, backward, left, right, stop
- emergency controls
- ROS2 state panel when in ROS2 mode

Control failures are shown with `SnackBar`. TCP connect/disconnect failures and ROS2 HTTP failures also use `SnackBar`.

## Testing

Add unit tests for command mapping and protocol encoding. Add widget coverage for:

- mode switching
- shared direction buttons
- TCP reset emergency disabled
- ROS2 status fields rendered from state data

## Out Of Scope

- No SpringBoot proxy endpoint for TCP.
- No changes to employee inspection map behavior.
- No changes to existing child medical, reminder, overview, settings, or location map workflows beyond adding the Safety tab entry.
