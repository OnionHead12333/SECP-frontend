import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CarTcpClient {
  Socket? _socket;

  bool get isConnected => _socket != null;

  String get endpointDescription {
    final socket = _socket;
    if (socket == null) {
      return 'not connected';
    }
    return '${socket.address.address}:${socket.port} -> '
        '${socket.remoteAddress.address}:${socket.remotePort}';
  }

  Future<void> connect(String host, int port) async {
    await close();
    final stopwatch = Stopwatch()..start();
    _socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 8),
    );
    stopwatch.stop();
    // Keep a concise debug trace for field testing with the physical car.
    // ignore: avoid_print
    print('CAR_TCP connected $endpointDescription '
        'in ${stopwatch.elapsedMilliseconds}ms');
  }

  Future<void> send(String message) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Not connected to car TCP server');
    }
    // ignore: avoid_print
    print('CAR_TCP send $message');
    socket.add(utf8.encode(message));
    await socket.flush();
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }
}
