import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _setConfirmation = 'TEMPORARY_NAV2_TEST_PARAMETER';
const _minimumDoubleValue = 0.01;
const _maximumDoubleValue = 1.0;
const _parameterDoubleType = 3;

Future<void> main(List<String> arguments) async {
  late final _Options options;
  try {
    options = _Options.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  WebSocket? socket;
  StreamSubscription<dynamic>? subscription;
  try {
    stdout.writeln(
      '${options.operation.name.toUpperCase()} Nav2 parameters via ${options.url}',
    );
    socket = await WebSocket.connect(options.url.toString())
        .timeout(const Duration(seconds: 6));
    final requestId =
        'nav2-parameter-probe-${DateTime.now().microsecondsSinceEpoch}';
    final response = Completer<Map<String, dynamic>>();
    subscription = socket.listen(
      (raw) => _handleSocketData(raw, requestId, response),
      onError: (Object error, StackTrace stackTrace) {
        if (!response.isCompleted) response.completeError(error, stackTrace);
      },
      onDone: () {
        if (!response.isCompleted) {
          response.completeError(
            StateError(
                'WebSocket closed before the parameter service response'),
          );
        }
      },
      cancelOnError: true,
    );

    socket.add(jsonEncode(options.serviceRequest(requestId)));
    final envelope = await response.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException(
        '${options.service} did not respond within 8 seconds',
      ),
    );
    stdout.writeln('service_response=${jsonEncode(envelope)}');
    if (envelope['result'] != true) {
      throw StateError(
        '${options.service} returned result=${envelope['result']}',
      );
    }

    final values = _map(envelope['values']);
    switch (options.operation) {
      case _Operation.get:
        _printGetResponse(options.names, values);
      case _Operation.set:
        final successful = _printSetResponse(values);
        if (!successful) exitCode = 1;
    }
  } catch (error) {
    stderr.writeln('NAV2_PARAMETER_PROBE_ERROR: $error');
    if (exitCode == 0) exitCode = 2;
  } finally {
    await subscription?.cancel();
    await socket?.close(WebSocketStatus.normalClosure);
  }
}

void _handleSocketData(
  dynamic raw,
  String requestId,
  Completer<Map<String, dynamic>> response,
) {
  try {
    final payload = raw is List<int> ? utf8.decode(raw) : '$raw';
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return;
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['op'] == 'service_response' &&
        envelope['id'] == requestId &&
        !response.isCompleted) {
      response.complete(envelope);
      return;
    }
    final level = '${envelope['level'] ?? ''}'.toLowerCase();
    if ((level == 'error' || level == 'fatal') && !response.isCompleted) {
      response.completeError(StateError('${envelope['msg'] ?? envelope}'));
    }
  } catch (error, stackTrace) {
    if (!response.isCompleted) response.completeError(error, stackTrace);
  }
}

void _printGetResponse(List<String> names, Map<String, dynamic> response) {
  final rawValues = response['values'];
  if (rawValues is! List || rawValues.length != names.length) {
    throw StateError(
      'GetParameters returned ${rawValues is List ? rawValues.length : 0} '
      'values for ${names.length} names',
    );
  }
  for (var index = 0; index < names.length; index += 1) {
    final parameterValue = _map(rawValues[index]);
    final type = _integer(parameterValue['type'], '${names[index]} type');
    if (type != _parameterDoubleType) {
      throw StateError(
        '${names[index]} has ParameterValue type=$type, expected double '
        'type=$_parameterDoubleType',
      );
    }
    final value = _finiteDouble(
      parameterValue['double_value'],
      '${names[index]} double_value',
    );
    stdout.writeln(
      '${names[index]} type=$type double_value=${value.toStringAsPrecision(12)}',
    );
  }
  stdout.writeln('NAV2_PARAMETER_GET_PASS');
}

bool _printSetResponse(Map<String, dynamic> response) {
  final rawResults = response['results'];
  if (rawResults is! List || rawResults.length != 1) {
    throw StateError(
      'SetParameters returned ${rawResults is List ? rawResults.length : 0} '
      'results, expected 1',
    );
  }
  final result = _map(rawResults.single);
  final successful = result['successful'];
  if (successful is! bool) {
    throw StateError(
        'SetParametersResult.successful is malformed: $successful');
  }
  final reason = '${result['reason'] ?? ''}';
  stdout.writeln(
    'SetParametersResult successful=$successful reason=${jsonEncode(reason)}',
  );
  stdout.writeln(
    successful ? 'NAV2_PARAMETER_SET_PASS' : 'NAV2_PARAMETER_SET_REJECTED',
  );
  return successful;
}

enum _Operation { get, set }

class _Options {
  const _Options({
    required this.operation,
    required this.url,
    required this.names,
    this.setValue,
  });

  final _Operation operation;
  final Uri url;
  final List<String> names;
  final double? setValue;

  String get service => switch (operation) {
        _Operation.get => '/controller_server/get_parameters',
        _Operation.set => '/controller_server/set_parameters',
      };

  String get serviceType => switch (operation) {
        _Operation.get => 'rcl_interfaces/srv/GetParameters',
        _Operation.set => 'rcl_interfaces/srv/SetParameters',
      };

  Map<String, dynamic> serviceRequest(String requestId) {
    return {
      'op': 'call_service',
      'id': requestId,
      'service': service,
      'type': serviceType,
      'args': switch (operation) {
        _Operation.get => {'names': names},
        _Operation.set => {
            'parameters': [
              {
                'name': names.single,
                'value': _doubleParameterValue(setValue!),
              },
            ],
          },
      },
    };
  }

  factory _Options.parse(List<String> arguments) {
    if (arguments.isEmpty) {
      throw const FormatException('Missing get or set operation.');
    }
    return switch (arguments.first) {
      'get' => _parseGet(arguments),
      'set' => _parseSet(arguments),
      _ => throw FormatException('Unknown operation: ${arguments.first}'),
    };
  }

  static _Options _parseGet(List<String> arguments) {
    if (arguments.length < 3) {
      throw const FormatException(
        'get requires a WebSocket URL and at least one parameter name.',
      );
    }
    final url = _webSocketUrl(arguments[1]);
    final names = arguments.skip(2).toList(growable: false);
    for (final name in names) {
      _validateParameterName(name);
    }
    return _Options(operation: _Operation.get, url: url, names: names);
  }

  static _Options _parseSet(List<String> arguments) {
    if (arguments.length != 5) {
      throw const FormatException(
        'set requires URL, parameter name, value, and the confirmation token.',
      );
    }
    final url = _webSocketUrl(arguments[1]);
    final name = arguments[2];
    _validateParameterName(name);
    final value = double.tryParse(arguments[3]);
    if (value == null ||
        !value.isFinite ||
        value < _minimumDoubleValue ||
        value > _maximumDoubleValue) {
      throw FormatException(
        'Set value must be finite and within '
        '[$_minimumDoubleValue, $_maximumDoubleValue], got ${arguments[3]}.',
      );
    }
    if (arguments[4] != '--confirm=$_setConfirmation') {
      throw const FormatException(
        'set requires --confirm=$_setConfirmation.',
      );
    }
    return _Options(
      operation: _Operation.set,
      url: url,
      names: [name],
      setValue: value,
    );
  }
}

Map<String, dynamic> _doubleParameterValue(double value) {
  return {
    'type': _parameterDoubleType,
    'bool_value': false,
    'integer_value': 0,
    'double_value': value,
    'string_value': '',
    'byte_array_value': <int>[],
    'bool_array_value': <bool>[],
    'integer_array_value': <int>[],
    'double_array_value': <double>[],
    'string_array_value': <String>[],
  };
}

Uri _webSocketUrl(String value) {
  final url = Uri.tryParse(value.trim());
  if (url == null ||
      (url.scheme != 'ws' && url.scheme != 'wss') ||
      url.host.isEmpty) {
    throw FormatException('Invalid rosbridge WebSocket URL: $value');
  }
  return url;
}

void _validateParameterName(String value) {
  if (value.isEmpty ||
      value.length > 256 ||
      !RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.]*$').hasMatch(value)) {
    throw FormatException('Invalid ROS parameter name: $value');
  }
}

double _finiteDouble(Object? value, String label) {
  if (value is! num || !value.toDouble().isFinite) {
    throw StateError('$label is missing or non-finite: $value');
  }
  return value.toDouble();
}

int _integer(Object? value, String label) {
  if (value is! num || !value.toDouble().isFinite) {
    throw StateError('$label is missing or non-finite: $value');
  }
  final result = value.toInt();
  if (result.toDouble() != value.toDouble()) {
    throw StateError('$label must be an integer: $value');
  }
  return result;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

const _usage = '''
Usage:
  dart tool/rosbridge_nav2_parameter_probe.dart get <ws-url> <name> [name...]
  dart tool/rosbridge_nav2_parameter_probe.dart set <ws-url> <name> <value> \\
    --confirm=TEMPORARY_NAV2_TEST_PARAMETER

Examples:
  dart tool/rosbridge_nav2_parameter_probe.dart get ws://127.0.0.1:9090 \\
    goal_checker.xy_goal_tolerance goal_checker.yaw_goal_tolerance

  dart tool/rosbridge_nav2_parameter_probe.dart set ws://127.0.0.1:9090 \\
    goal_checker.xy_goal_tolerance 0.05 \\
    --confirm=TEMPORARY_NAV2_TEST_PARAMETER

set accepts only finite double values in [0.01, 1.0].
''';
