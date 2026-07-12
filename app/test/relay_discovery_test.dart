import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'package:vidyut/src/pairing/relay_discovery.dart';

void main() {
  const service = RelayDiscovery.serviceName;
  const instance = 'Vidyut Relay.$service';

  test('discovers a relay from PTR -> SRV -> A records', () async {
    final client = FakeMDnsClient({
      _key(service, ResourceRecordType.serverPointer): [
        PtrResourceRecord(service, 0, domainName: instance),
      ],
      _key(instance, ResourceRecordType.service): [
        SrvResourceRecord(
          instance,
          0,
          target: 'laptop.local',
          port: 17321,
          priority: 0,
          weight: 0,
        ),
      ],
      _key('laptop.local', ResourceRecordType.addressIPv4): [
        IPAddressResourceRecord(
          'laptop.local',
          0,
          address: InternetAddress('192.168.1.5'),
        ),
      ],
    });
    final discovery = RelayDiscovery(createClient: () => client);

    final relays = await discovery.discover();

    expect(relays, const [
      DiscoveredRelay(name: 'Vidyut Relay', host: '192.168.1.5', port: 17321),
    ]);
    expect(client.started, isTrue);
    expect(client.stopped, isTrue);
  });

  test('dedupes repeated PTR answers for the same relay', () async {
    final client = FakeMDnsClient({
      _key(service, ResourceRecordType.serverPointer): [
        PtrResourceRecord(service, 0, domainName: instance),
        PtrResourceRecord(service, 0, domainName: instance),
      ],
      _key(instance, ResourceRecordType.service): [
        SrvResourceRecord(
          instance,
          0,
          target: 'laptop.local',
          port: 17321,
          priority: 0,
          weight: 0,
        ),
      ],
      _key('laptop.local', ResourceRecordType.addressIPv4): [
        IPAddressResourceRecord(
          'laptop.local',
          0,
          address: InternetAddress('192.168.1.5'),
        ),
      ],
    });
    final discovery = RelayDiscovery(createClient: () => client);

    final relays = await discovery.discover();

    expect(relays, hasLength(1));
  });

  test('returns an empty list when nothing answers', () async {
    final client = FakeMDnsClient({});
    final discovery = RelayDiscovery(createClient: () => client);

    expect(await discovery.discover(), isEmpty);
  });

  test('skips relays whose SRV or A record never resolves', () async {
    final client = FakeMDnsClient({
      _key(service, ResourceRecordType.serverPointer): [
        PtrResourceRecord(service, 0, domainName: instance),
        PtrResourceRecord(service, 0, domainName: 'Ghost.$service'),
      ],
      _key(instance, ResourceRecordType.service): [
        SrvResourceRecord(
          instance,
          0,
          target: 'laptop.local',
          port: 17321,
          priority: 0,
          weight: 0,
        ),
      ],
    });
    final discovery = RelayDiscovery(createClient: () => client);

    expect(await discovery.discover(), isEmpty);
  });

  test('acquires and releases the multicast lock around discovery', () async {
    final lock = RecordingMulticastLock();
    final discovery = RelayDiscovery(
      createClient: () => FakeMDnsClient({}),
      lock: lock,
    );

    await discovery.discover();

    expect(lock.events, ['acquire', 'release']);
  });

  test('lock failures do not abort discovery', () async {
    final lock = RecordingMulticastLock(throwOnAcquire: true);
    final client = FakeMDnsClient({});
    final discovery = RelayDiscovery(createClient: () => client, lock: lock);

    expect(await discovery.discover(), isEmpty);
    expect(client.stopped, isTrue);
  });

  test('stops the client and releases the lock when lookup throws', () async {
    final lock = RecordingMulticastLock();
    final client = FakeMDnsClient({}, throwOnLookup: true);
    final discovery = RelayDiscovery(createClient: () => client, lock: lock);

    await expectLater(discovery.discover(), throwsException);
    expect(client.stopped, isTrue);
    expect(lock.events, ['acquire', 'release']);
  });
}

String _key(String name, int type) => '$name:$type';

class FakeMDnsClient implements MDnsClient {
  FakeMDnsClient(this.answers, {this.throwOnLookup = false});

  final Map<String, List<ResourceRecord>> answers;
  final bool throwOnLookup;
  bool started = false;
  bool stopped = false;

  @override
  Future<Iterable<NetworkInterface>> allInterfacesFactory(
    InternetAddressType type,
  ) async => const [];

  @override
  Future<void> start({
    InternetAddress? listenAddress,
    NetworkInterfacesFactory? interfacesFactory,
    int mDnsPort = 5353,
    InternetAddress? mDnsAddress,
    Function? onError,
  }) async {
    started = true;
  }

  @override
  void stop() {
    stopped = true;
  }

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (throwOnLookup) {
      return Stream.error(Exception('lookup failed'));
    }
    final records =
        answers[_key(query.fullyQualifiedName, query.resourceRecordType)] ??
        const [];
    return Stream.fromIterable(records.whereType<T>());
  }
}

class RecordingMulticastLock implements MulticastLock {
  RecordingMulticastLock({this.throwOnAcquire = false});

  final bool throwOnAcquire;
  final List<String> events = [];

  @override
  Future<void> acquire() async {
    events.add('acquire');
    if (throwOnAcquire) throw Exception('no wifi manager');
  }

  @override
  Future<void> release() async {
    events.add('release');
  }
}
