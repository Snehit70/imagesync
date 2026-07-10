import 'dart:async';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

class DiscoveredRelay {
  const DiscoveredRelay({
    required this.name,
    required this.host,
    required this.port,
  });

  final String name;
  final String host;
  final int port;

  @override
  bool operator ==(Object other) {
    return other is DiscoveredRelay &&
        other.name == name &&
        other.host == host &&
        other.port == port;
  }

  @override
  int get hashCode => Object.hash(name, host, port);

  @override
  String toString() => 'DiscoveredRelay($name, $host:$port)';
}

/// Android drops multicast packets unless a WifiManager multicast lock is
/// held, so discovery wraps its browse window in acquire/release.
abstract interface class MulticastLock {
  Future<void> acquire();

  Future<void> release();
}

class ChannelMulticastLock implements MulticastLock {
  const ChannelMulticastLock();

  static const _channel = MethodChannel('imagesync/multicast');

  @override
  Future<void> acquire() async {
    await _channel.invokeMethod<void>('acquire');
  }

  @override
  Future<void> release() async {
    await _channel.invokeMethod<void>('release');
  }
}

class RelayDiscovery {
  RelayDiscovery({MDnsClient Function()? createClient, MulticastLock? lock})
    : _createClient = createClient ?? MDnsClient.new,
      _lock = lock; // ignore: prefer_initializing_formals

  static const serviceName = '_imagesync._tcp.local';

  final MDnsClient Function() _createClient;
  final MulticastLock? _lock;

  Future<List<DiscoveredRelay>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await _withLockBestEffort((lock) => lock.acquire());
    final client = _createClient();
    try {
      await client.start();
      final relays = <DiscoveredRelay>[];
      final seen = <String>{};
      final resolutions = <Future<void>>[];
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceName),
        timeout: timeout,
      )) {
        resolutions.add(
          _resolve(client, ptr.domainName, timeout, relays, seen),
        );
      }
      await Future.wait(resolutions);
      return relays;
    } finally {
      client.stop();
      await _withLockBestEffort((lock) => lock.release());
    }
  }

  Future<void> _resolve(
    MDnsClient client,
    String domainName,
    Duration timeout,
    List<DiscoveredRelay> relays,
    Set<String> seen,
  ) async {
    final srv = await _firstOrNull(
      client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(domainName),
        timeout: timeout,
      ),
    );
    if (srv == null) return;
    final ip = await _firstOrNull(
      client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(srv.target),
        timeout: timeout,
      ),
    );
    if (ip == null) return;
    final host = ip.address.address;
    if (!seen.add('$host:${srv.port}')) return;
    relays.add(
      DiscoveredRelay(
        name: _instanceName(domainName),
        host: host,
        port: srv.port,
      ),
    );
  }

  Future<void> _withLockBestEffort(
    Future<void> Function(MulticastLock lock) action,
  ) async {
    final lock = _lock;
    if (lock == null) return;
    try {
      await action(lock);
    } on Exception {
      // Discovery can still succeed on devices that deliver multicast
      // without the lock, so lock failures are not fatal.
    }
  }

  static Future<T?> _firstOrNull<T>(Stream<T> stream) async {
    await for (final value in stream) {
      return value;
    }
    return null;
  }

  static String _instanceName(String domainName) {
    const suffix = '.$serviceName';
    if (!domainName.endsWith(suffix)) return domainName;
    return domainName.substring(0, domainName.length - suffix.length);
  }
}
