# Child Remote Car Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a child-side remote car page with ROS2 gateway and TCP direct control modes.

**Architecture:** Add a focused child remote car feature with command/state models, direct ROS2 gateway HTTP client, direct TCP socket client, and one page that switches modes while sharing the control pad. Route the page from the child Safety tab and keep employee map code untouched.

**Tech Stack:** Flutter, Material 3, Dio, dart:io Socket, flutter_test.

---

## File Structure

- Create `mobile/lib/features/child/data/remote_car/remote_car_models.dart`: commands, mode enum, ROS2 state model, command labels, TCP mapping.
- Create `mobile/lib/features/child/data/remote_car/car_encoder.dart`: copied protocol encoder from the smart car Flutter project.
- Create `mobile/lib/features/child/data/remote_car/car_tcp_client.dart`: copied direct socket client from the smart car Flutter project.
- Create `mobile/lib/features/child/data/remote_car/child_remote_car_gateway_client.dart`: direct ROS2 gateway client with injectable Dio.
- Create `mobile/lib/features/child/presentation/pages/child_remote_car_page.dart`: full page UI and control flow.
- Modify `mobile/lib/app/smart_elderly_care_app.dart`: register `/child/remote-car`.
- Modify `mobile/lib/features/child/presentation/tabs/child_safety_tab.dart`: add remote car entry card.
- Create `mobile/test/child_remote_car_test.dart`: model, encoder, gateway, and widget tests.

## Task 1: Tests First

**Files:**
- Create: `mobile/test/child_remote_car_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('car encoder emits smart car button protocol', () {
  expect(CarEncoder.button(CarDirection.front), r'$011504011B#');
  expect(CarEncoder.button(CarDirection.brake), r'$0115040721#');
});

test('remote car commands map to TCP directions', () {
  expect(RemoteCarCommand.forward.tcpDirection, CarDirection.front);
  expect(RemoteCarCommand.backward.tcpDirection, CarDirection.back);
  expect(RemoteCarCommand.left.tcpDirection, CarDirection.leftRotate);
  expect(RemoteCarCommand.right.tcpDirection, CarDirection.rightRotate);
  expect(RemoteCarCommand.stop.tcpDirection, CarDirection.stop);
  expect(RemoteCarCommand.emergencyStop.tcpDirection, CarDirection.brake);
  expect(RemoteCarCommand.resetEmergency.tcpDirection, isNull);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `.\flutterw.cmd test test\child_remote_car_test.dart`
Expected: FAIL because remote car files do not exist yet.

## Task 2: Data Layer

**Files:**
- Create: `mobile/lib/features/child/data/remote_car/remote_car_models.dart`
- Create: `mobile/lib/features/child/data/remote_car/car_encoder.dart`
- Create: `mobile/lib/features/child/data/remote_car/car_tcp_client.dart`
- Create: `mobile/lib/features/child/data/remote_car/child_remote_car_gateway_client.dart`

- [ ] **Step 1: Implement command, state, encoder, TCP client, and ROS2 gateway client**

The implementation defines `RemoteCarCommand`, `RosCarState`, `CarEncoder`, `CarTcpClient`, and `ChildRemoteCarGatewayClient`.

- [ ] **Step 2: Run tests and verify GREEN**

Run: `.\flutterw.cmd test test\child_remote_car_test.dart`
Expected: PASS for encoder, mapping, and gateway path tests.

## Task 3: Page And Route

**Files:**
- Create: `mobile/lib/features/child/presentation/pages/child_remote_car_page.dart`
- Modify: `mobile/lib/app/smart_elderly_care_app.dart`
- Modify: `mobile/lib/features/child/presentation/tabs/child_safety_tab.dart`
- Test: `mobile/test/child_remote_car_test.dart`

- [ ] **Step 1: Add widget tests**

```dart
testWidgets('remote car page switches modes and disables TCP reset', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: ChildRemoteCarPage()));
  await tester.tap(find.text('TCP直连'));
  await tester.pumpAndSettle();
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '解除急停')).onPressed, isNull);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `.\flutterw.cmd test test\child_remote_car_test.dart`
Expected: FAIL because the page does not exist or the reset behavior is missing.

- [ ] **Step 3: Implement page, route, and Safety tab entry**

Build a `ChildRemoteCarPage` with a segmented mode switch, config fields, shared direction buttons, emergency buttons, status panels, direct ROS2 calls, and direct TCP socket calls.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `.\flutterw.cmd test test\child_remote_car_test.dart`
Expected: PASS.

## Task 4: Verification

**Files:**
- Existing test suite under `mobile/test`

- [ ] **Step 1: Run targeted tests**

Run: `.\flutterw.cmd test test\child_remote_car_test.dart`
Expected: PASS.

- [ ] **Step 2: Run broader Flutter tests if practical**

Run: `.\flutterw.cmd test`
Expected: PASS, or document unrelated failures.

## Self-Review

- Spec coverage: ROS2 direct gateway, TCP direct socket, command mapping, mode switch, shared buttons, connection/last command status, SnackBar failures, disabled TCP reset, route entry, and no employee map edits are covered.
- Placeholder scan: no TBD/TODO placeholders.
- Type consistency: command names and state fields match the design spec.
